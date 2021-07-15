#!/bin/bash -u

exiterror() {
        echo $@ | tee ${ERROR_PATH}
        exit 1
}

echo "creating clone of instance ${INSTANCE_NAME} and storing clone ip in ${OUTPUT_PATH} (or errors in ${ERROR_PATH})"

CLONE_NAME=${INSTANCE_NAME}-$(date +%s)

gcloud sql instances clone ${INSTANCE_NAME} ${CLONE_NAME} || exiterror "gcloud clone failed with error code $?" 


# > ${ERROR_PATH}

IP=$(gcloud sql instances list --filter=name=${CLONE_NAME} --format=json | jq -r '[.[0].ipAddresses]|.[0]|.[]|select(.type == "PRIVATE").ipAddress')
echo $IP > ${OUTPUT_PATH}
echo $CLONE_NAME > ${OUTPUT_PATH}.name

echo "clone $CLONE_NAME created at ip ${IP}"
