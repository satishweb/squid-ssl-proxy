# Squid SSL Proxy with SSLBump ![Logo](images/squid-logo.png) [Works on Raspberry Pi]
Container image for Squid SSL proxy server with SSL Bump enabled. SSLBump (Squid-in-the-middle) does the decryption and encryption of straight CONNECT and transparently redirected SSL traffic, using configurable CA certificates.

## :x: WARNING :x:
Use this Squid SSL Proxy with SSLBump only with the user's consent. [Legal Warning](#legal-warning)

## Requirements
1. Docker Compose

## Quick Start

1. Download the [latest release](https://github.com/satishweb/squid-ssl-proxy/releases/latest) and unzip.

```shell
curl -s https://api.github.com/repos/satishweb/container-devops-tools/releases/latest|grep "tarball_url" | head -1|awk -F '[:"]' '{print $5":"$6}'| xargs curl -L -o release.tar.gz && tar zxf release.tar.gz && rm release.tar.gz; mv satishweb-* squid-ssl-proxy
```

2. (Optional) Edit `docker-compose.yml` file

3. Copy `env.sample.conf` as `env.conf` and edit the values as needed

4. Run the Docker container

```shell
./launch.sh
```

4. Change your proxy configuration to http://localhost:3128/ (sslbump disabled) or http://localhost:4128/ (sslbump enabled)

## What is SSLBump (From the squid website)

Secure Sockets Layer (SSL) and its successor Transport Layer Security (TLS) have become essential components of the modern Internet. The confidentiality, integrity, and originality provided by these protocols are critical to allow for delicate communication to take place.

Threat actors have also recognized the benefits of transport security and are increasingly turning to SSL to hide their activities. Attackers, Botnets and even ad-hoc web attacks can use SSL encryption to avoid detection.

With the SSL Bump feature, the squid intercepts the encrypted SSL traffic and encrypts it again to the customer's direction. In other words, when a client browses a secure site, Squid takes the actual web server certificate and establishes an SSL connection to the web server. Then, It sends a new digital certificate to the client that looks like a web server's certificate to it and establishes a secure connection between the browser and the proxy.

The configuration of this image provides two different endpoints to the proxy. One of them is not sslbumped (3128), the other one is sslbump enabled (4128). It's not necessary to use sslbump feature to use squid as a regular web proxy.

## Legal Warning

SSLBump is an SSL/HTTPS interception. HTTPS interception has ethical and legal issues which you need to be aware of which are follows;

* Some countries do not limit what can be done within the home environment,
* Some countries permit employment or contract law to overrule privacy,
* Some countries require government registration for all decryption services,
* Some countries it is an outright capital offense with severe penalties
* DO SEEK legal advice before using SSLBump feature, even at home.

## Settings and Folders

There are a few settings in the `docker-compose.yml` file as follows:

* Ports: There are two TCP endpoint configurations. 3128 is the regular proxy port of squid and it is not sslbump feature enabled. 4128 is the sslbump enabled port. If you want to change local ports to connect, change the first part of the settings. (ex. "8080:3128")
* Environment values: Squid needs [a root certificate](#sslbump-root-certificate) for the sslbump feature. The following settings are used when the first time root certificate is created. If you need to recreate the root certificate, you need to delete all files in the `cert` folder.
  * `CERT_CN`: Common name of the certificate
  * `CERT_ORG` : Organization of the certificate owner
  * `CERT_OU`: Organization unit of the certificate owner
  * `CERT_COUNTRY` : Two letter code of the country
* Folders: There are three different folders that the image is using.
  * `log` folder is used for storing access logs.
  * `cache` folder is used for storing proxy cache.
  * `cert` folder is used to store the root certificate.

Squid configuration file is located in `conf/squid.conf`. You may refer [the official documentation](http://www.squid-cache.org/Versions/v3/3.5/cfgman/) of squid before change the file.

## SSLBump Root Certificate

If there isn't, a root certificate is created when the first time image is started. All the clients need to trust this certificate. Otherwise, Clients see an error text for all HTTPS sites. Your clients only need the `cert/CA.der` file for setup a trust. DON'T DISTRIBUTE the `cert/private.pem` file to the clients.

If you need to recreate the root certificate, you need to delete all files in the `cert` folder. Then, a new root certificate is created when the image is started.

## Credits
- https://github.com/alatas/squid-alpine-ssl
