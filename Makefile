IMAGE=satishweb/squid-ssl-proxy
PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6
WORKDIR=$(shell pwd)
BASE_IMAGE=alpine:latest

SQUID_VERSION?=$(shell docker run --rm --entrypoint=sh ${BASE_IMAGE} -c \
					"apk update >/dev/null 2>&1; apk info squid" \
					|grep -e '^squid-*.*description'\
					|awk '{print $$1}'\
					|sed -e 's/^[ \t]*//;s/[ \t]*$$//;s/ /-/g'\
					|sed $$'s/[^[:print:]\t]//g'\
					|sed 's/^squid-//')

# Set L to + for debug
L=@

test-env:
	echo "test-env: printing env values:"
	echo "Squid Version: ${SQUID_VERSION}"

ifdef PUSH
	EXTRA_BUILD_PARAMS = --push-images --push-git-tags
endif

ifdef LATEST
	EXTRA_BUILD_PARAMS += --mark-latest
endif

ifdef LOAD
	EXTRA_BUILD_PARAMS += --load
endif

all: build

build:
	/bin/bash ${BASH_FLAGS} ./build.sh \
	  --image-name "${IMAGE}" \
	  --platforms "${PLATFORMS}" \
	  --work-dir "${WORKDIR}" \
	  --git-tag "${SQUID_VERSION}" \
	  --extra-args "--build-arg SQUID_VERSION=${SQUID_VERSION}" \
	${EXTRA_BUILD_PARAMS}

test:
	docker build --build-arg SQUID_VERSION=${SQUID_VERSION} -t ${IMAGE}:${SQUID_VERSION} .

debug:
	docker rm -f squid
	docker run -d --name squid -e DEBUG=1 --entrypoint=/bin/sh -v $$(pwd)/conf/squid.sample.conf:/templates/squid.sample.conf -v $$(pwd)/scripts/docker-entrypoint:/docker-entrypoint satishweb/squid-ssl-proxy:${SQUID_VERSION} -c "sleep 9999999"
	echo "Run ./docker-entrypoint before this command: squid -NYCd 1 -f /etc/squid/squid.conf"
	docker exec -it squid sh
