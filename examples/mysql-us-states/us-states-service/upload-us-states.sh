#!/bin/bash

BIN="/usr/local/bin"
EXEC_MYSQL="${BIN}/mysql-exec.sh"
EXEC_WILDFLY="${BIN}/wildfly-exec.sh"

DSBUILDER_USER="user"
DSBUILDER_PASSWD="user1234!"

#
# -k will not verify the ssl certificate
# --user will use the basic authentication
#
AUTH_CURL="curl -k --user ${DSBUILDER_USER}:${DSBUILDER_PASSWD}"

DS_NAME="us-states-service.zip"
ABOUT_URL="https://localhost:8443/vdb-builder/v1/service/about"
IMPORT_URL="https://localhost:8443/vdb-builder/v1/importexport/import"

CONTENT_HEADER="Content-Type: application/json"
ACCEPT_HEADER="Accept: application/json"

JSON_STORAGE_TYPE="storageType: \"file\""
JSON_DOCUMENT_TYPE="documentType: \"zip\""

function wait-on-wildfly() {
	set +e

	echo "Waiting for wildfly..."
	while true; do
		ABOUT_STATUS=`${AUTH_CURL} -sL -w "%{http_code}\\n" -X GET --header "${ACCEPT_HEADER}" ${ABOUT_URL} -o /dev/null` 
		echo "Status: ${ABOUT_STATUS}"
		if [ "${ABOUT_STATUS}" = 200 ]; then
			echo "dsbuilder up and running"
			return;
		elif [ "${ABOUT_STATUS}" = 401 ]; then
			echo "Not authorised to connect to dsbuilder ... exiting"
			exit 1;
		else
			echo "Still waiting for wildfly..." && sleep 4
		fi
	done

	set -e
}


#
# Zip up the data service
#
zip -r ${DS_NAME} connections META-INF *.xml

DS_ZIP64=`base64 -w0 ${DS_NAME}`
echo "DS ZIP BASE64 = ${DS_ZIP64}"

#
# Start mysql if not already started
#
${EXEC_MYSQL} &

#
# Start wildfly in the background
#
${EXEC_WILDFLY} &

#
# Wait for wildfly to deploy and make available dsbuilder
#
wait-on-wildfly

#
# Use curl to upload the data service to the vdb-builder REST service
#
JSON_CONTENT="content: \"${DS_ZIP64}\""
${AUTH_CURL} -X POST --header "${CONTENT_HEADER}" --header "${ACCEPT_HEADER}" -d "{ ${JSON_STORAGE_TYPE}, ${JSON_DOCUMENT_TYPE}, ${JSON_CONTENT} }" "${IMPORT_URL}"

