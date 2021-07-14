#!/bin/bash -eu

echo "creating clone of instance ${INSTANCE_NAME} and storing clone ip in ${OUTPUT_PATH} (or errors in ${ERROR_PATH})"
INSTANCE_NAME="${INSTANCE_NAME}"


RAND=$(mktemp -u | awk '{print tolower($0)}' |grep -o '........$')
CLONE_NAME=${INSTANCE_NAME}-${RAND}

gcloud sql instances clone ${INSTANCE_NAME} ${CLONE_NAME}
errcode=$?
if [[ "$errcode" -ne 0]]; then
    echo "gcloud clone failed with error code ${errcode}" > ${ERROR_PATH}
fi

IP=$(gcloud sql instances list --filter=name=${CLONE_NAME} --format=json | jq -r '[.[0].ipAddresses]|.[0]|.[]|select(.type == "PRIVATE").ipAddress')
echo $IP > ${OUTPUT_PATH}

echo "clone created at ip ${IP}"