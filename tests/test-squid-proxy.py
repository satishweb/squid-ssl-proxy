#!/usr/bin/env python3

import argparse
import sys
import time
import unittest

HEALTH_TIMEOUT = 120  # seconds to wait for the container to become healthy
PROXY_PORT = 3128
TEST_URL = "http://example.com"


def wait_for_container_health(container, timeout=HEALTH_TIMEOUT):
    print("Waiting for the container to be healthy...")
    deadline = time.time() + timeout
    while True:
        container.reload()
        state = container.attrs.get("State", {})
        status = state.get("Health", {}).get("Status")
        if status == "healthy":
            print("The container is healthy.")
            return
        if state.get("Status") in ("exited", "dead"):
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"The container stopped before it became healthy (status={state.get(Status)}).\n{logs}"
            )
        if time.time() > deadline:
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"The container did not become healthy within {timeout}s (last status={status}).\n{logs}"
            )
        time.sleep(2)


def run_tests(image_name):
    import docker
    import requests

    class TestSquidProxy(unittest.TestCase):
        @classmethod
        def setUpClass(cls):
            cls.client = docker.from_env()
            cls.container = cls.client.containers.run(
                image_name,
                detach=True,
                ports={f"{PROXY_PORT}": f"{PROXY_PORT}"},
            )
            wait_for_container_health(cls.container)

        @classmethod
        def tearDownClass(cls):
            cls.container.stop()
            cls.container.remove()

        def test_healthcheck(self):
            print("Running the health check test...")
            exit_code = self.container.exec_run("/bin/sh -c exit 0").exit_code
            self.assertEqual(exit_code, 0)
            print("Health check test passed.")

        def test_proxy_forwards_a_request(self):
            print("Running the proxy test...")
            proxies = {"http": f"http://127.0.0.1:{PROXY_PORT}"}
            response = requests.get(TEST_URL, proxies=proxies, timeout=30)
            self.assertEqual(
                response.status_code, 200, f"The proxy did not answer with 200: {response.status_code}"
            )
            print("Proxy test passed.")

    print(f"Starting the container from the image {image_name}...")
    suite = unittest.TestLoader().loadTestsFromTestCase(TestSquidProxy)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the tests for the squid proxy image.")
    parser.add_argument("--image", type=str, default="satishweb/squid-ssl-proxy:ci", help="The image that is tested")
    args = parser.parse_args()

    run_tests(args.image)
