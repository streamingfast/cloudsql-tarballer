#!/bin/bash -u

exiterror() {
        [ -z "$OUTFILE_ERROR" ] && OUTFILE_ERROR=/tmp/errorout
        echo $@ | tee $OUTFILE_ERROR
        exit 1
}

echo "creating clone of SQL instance ${GCP_INSTANCE_NAME} and storing clone ip in ${OUTFILE_CLONE_INSTANCE_IP}, clone name in ${OUTFILE_CLONE_INSTANCE_NAME} (or errors in ${OUTFILE_ERROR})"

CLONE_NAME=${GCP_INSTANCE_NAME}-$(date +%s)

gcloud sql instances clone ${GCP_INSTANCE_NAME} ${CLONE_NAME} || exiterror "gcloud clone failed with error code $?" 


# > ${ERROR_PATH}

IP=$(gcloud sql instances list --filter=name=${CLONE_NAME} --format=json | jq -r '[.[0].ipAddresses]|.[0]|.[]|select(.type == "PRIVATE").ipAddress')
echo $IP > ${OUTFILE_CLONE_INSTANCE_IP}
echo $CLONE_NAME > ${OUTFILE_CLONE_INSTANCE_NAME}

echo "clone $CLONE_NAME created at ip ${IP}"
