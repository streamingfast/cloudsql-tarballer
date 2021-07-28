#/bin/bash

exiterror() {
        echo $@
        exit 1
}


THREADS=${THREADS:-10}

SKIP_CLONE=""
if [ "$DIRECT_DUMP_FROM_REMOTE_IP" != "" ]; then 
     SKIP_CLONE=true
fi

[ -z "$REMOTE_SQL_DBNAME" ] && exiterror "Variable REMOTE_SQL_DBNAME is unset"
[ -z "$REMOTE_SQL_USERNAME" ] && exiterror "Variable REMOTE_SQL_USERNAME is unset"
[ -z "$REMOTE_SQL_PASSWORD" ] && exiterror "Variable REMOTE_SQL_PASSWORD is unset"

# ex SCHEMA: (info|subgraphs|public|chain1|sgd1)
if [ -z "$SCHEMAS" ]; then
        SCHEMA_SPEC=""
else
        SCHEMA_SPEC="-n $SCHEMAS"
fi

[ -z "$PGDATA" ] && exiterror "Variable PGDATA is unset but mandatory here (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_PASSWORD" ] && exiterror "Variable POSTGRES_PASSWORD is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_USER" ] && exiterror "Variable POSTGRES_USER is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_DB" ] && exiterror "Variable POSTGRES_DB is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$DATA_FOLDER" ] && exiterror "Variable DATA_FOLDER is unset (path to folder where pg_dump will write data: must be empty or non-existent)"

[ -z "$DEST_TARBALL_URL" ] && exiterror "Variable DEST_TARBALL_URL is unset (where we upload the file to, ex: gs://mybucket/tarballs/)"

mkdir -p "$DATA_FOLDER"

if ! [ -z "$(find $DATA_FOLDER -mindepth 1 -not -name lost+found)" ]; then
        exiterror "DATA_FOLDER  ($DATA_FOLDER) is not empty but it should be"
fi

###################
## CLONE SQL SERVER
###################

if [ "$SKIP_CLONE" == "" ]; then
    CLONE_NAME=${GCP_INSTANCE_NAME}-$(date +%s)
    echo "Creating SQL clone of ${GCP_INSTANCE_NAME} through GCP SQL API into ${CLONE_NAME}" 
    
    gcloud sql instances clone ${GCP_INSTANCE_NAME} ${CLONE_NAME} || exiterror "gcloud clone failed with error code $?"
    
    CLONE_IP=$(gcloud sql instances list --filter=name=${CLONE_NAME} --format=json | jq -r '[.[0].ipAddresses]|.[0]|.[]|select(.type == "PRIVATE").ipAddress')
    
    echo "Clone $CLONE_NAME created at ip ${CLONE_IP}"
else
    CLONE_IP="$DIRECT_DUMP_FROM_REMOTE_IP"
fi


######################
## EXPORT VIA PG_DUMP
######################

echo "Dumping database $REMOTE_SQL_DBNAME from remote server ${CLONE_IP}:5432 using user $REMOTE_SQL_USERNAME to folder ${DATA_FOLDER}"

export PGPASSWORD="${REMOTE_SQL_PASSWORD}"
pg_dump --blobs --dbname="$REMOTE_SQL_DBNAME" --file="${DATA_FOLDER}" --format=directory --host="$CLONE_IP" --jobs=$THREADS --port=5432 --username="$REMOTE_SQL_USERNAME" $SCHEMA_SPEC
# FIXME find a way to only catch 'important' errors
unset PGPASSWORD

#####################################
## RESTORE IN LOCAL DB, THEN TARBALL
#####################################

echo "Starting local postgres server and waiting for ready"

docker-entrypoint.sh postgres &
while sleep 1; do
    # initialization phase by docker-entrypoint would wrongly show pg as ready
    pgrep -f listen_addresses= >/dev/null && continue
    pg_isready && break
done

echo "Restoring database $REMOTE_SQL_DBNAME into local database"

## FIXME must add the --exit-on-error flag, but permissions may cause false positives
pg_restore --no-owner --format=directory --jobs=$THREADS --username "${POSTGRES_USER}" -d "${POSTGRES_DB}" "${DATA_FOLDER}"

echo "Waiting until local database is stopped"
pkill postgres
while sleep 1; do
    pg_isready || break
done

FILENAME=pgdata-$(date +%s).tar.gz
TARBALL="${DATA_FOLDER}/${FILENAME}"
cd $PGDATA && tar czf ${TARBALL} .

#################
## Upload to GCP
#################

echo "uploading ${TARBALL} to ${DEST_TARBALL_URL}/${FILENAME}"
gsutil cp ${TARBALL} "${DEST_TARBALL_URL}/${FILENAME}" || exiterror "could not upload to google storage..."

