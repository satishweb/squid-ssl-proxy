#!/bin/sh
# Author: Satish Gaikwad <satish@satishweb.com>
set -e

## Functions

create_cert() {
	if [ ! -f ${SQUID_CERT_DIR}/private.pem ]; then
		echo "Creating certificate..."
		openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 \
			-extensions v3_ca -keyout ${SQUID_CERT_DIR}/private.pem \
			-out ${SQUID_CERT_DIR}/private.pem \
			-subj "/CN=$CERT_CN/O=$CERT_ORG/OU=$CERT_OU/C=$CERT_COUNTRY" -utf8 -nameopt multiline,utf8

		openssl x509 -in ${SQUID_CERT_DIR}/private.pem \
			-outform DER -out ${SQUID_CERT_DIR}/CA.der

		openssl x509 -inform DER -in ${SQUID_CERT_DIR}/CA.der \
			-out ${SQUID_CERT_DIR}/CA.pem
	else
		echo "Certificate is already created, reusing existing certifcates..."
	fi
}

clear_certs_db() {
	echo "Clearing generated certificate db..."
	rm -rfv /var/lib/ssl_db/
	/usr/lib/squid/security_file_certgen -c -s /var/lib/ssl_db -M 4MB
	chown -R squid.squid /var/lib/ssl_db
}

if [ -f /run/secrets/DEBUG ]; then
    DEBUG=$(cat /run/secrets/DEBUG)
    export DEBUG
fi

if [ "$DEBUG" = "1" ]; then
    set -x
fi

SQUID_CONFIG_DIR=/etc/squid
SQUID_CERT_DIR=/etc/squid-cert
SQUID_CACHE_DIR=/var/cache/squid/
SQUID_LOG_DIR=/var/log/squid/
SQUID_CONFIG_FILE=${SQUID_CONFIG_DIR}/squid.conf
SQUID_CONFIG_SAMPLE_FILE=/templates/squid.sample.conf

printf "|---------------------------------------------------------------------------------------------\n";
printf "| Preparing squid proxy server configuration\n"

# Load env vars
printf "| ENTRYPOINT: \033[0;31mLoading docker secrets if found...\033[0m\n"
for i in $(env|grep '/run/secrets')
do
    varName=$(echo "$i"|awk -F '[=]' '{print $1}'|sed 's/_FILE//')
    varFile=$(echo "$i"|awk -F '[=]' '{print $2}')
    # shellcheck disable=SC2086
    exportCmd="export $varName=$(cat $varFile)"
    echo "${exportCmd}" >> /etc/profile
    eval "${exportCmd}"
    printf "| ENTRYPOINT: Exporting var: %s\n" "$varName"
done

# Lets copy default squid config file
if [ ! -f ${SQUID_CONFIG_FILE} ]; then
  cp -rf ${SQUID_CONFIG_SAMPLE_FILE} ${SQUID_CONFIG_FILE}
fi

# lets generate config file by replacing all variables inside of it.
TMP_FILE=/tmp/squid.conf
cp ${SQUID_CONFIG_FILE} ${TMP_FILE}
DOLLAR='$' envsubst < ${TMP_FILE} > ${SQUID_CONFIG_FILE}
rm ${TMP_FILE}

# Lets set correct permissions for files used by squid
mkdir -p ${SQUID_CONFIG_DIR} ${SQUID_CERT_DIR} ${SQUID_CACHE_DIR} ${SQUID_LOG_DIR}
chown -Rf squid:squid ${SQUID_CONFIG_DIR} ${SQUID_CERT_DIR} ${SQUID_CACHE_DIR} ${SQUID_LOG_DIR}
chmod 644 ${SQUID_CONFIG_DIR}/*.conf

# Lets initialize the squid
create_cert
clear_certs_db
squid -z >/dev/null 2>&1 || true # Ignore the errors
rm -f /var/run/squid.pid >/dev/null 2>&1 || true

printf "| ENTRYPOINT: \033[0;31mStarting squid proxy server \033[0m\n"
printf "|---------------------------------------------------------------------------------------------\n";

# Check if app-config is present
if [ -f /app-config ]; then
    # We expect that app-config handles the launch of app command
    echo "| ENTRYPOINT: Executing app-config..."
    # shellcheck disable=SC1091,SC2240
    . /app-config "$@"
else
    # Let default CMD run if app-config is missing
    echo "| ENTRYPOINT: app-config was not available, running given parameters or default CMD..."
    # shellcheck disable=SC2068
    exec $@
fi
