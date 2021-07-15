#!/bin/bash

exiterror() {
	echo $@
	exit 1
}

THREADS=${THREADS:-10}

[ -z "$PGDATA" ] && exiterror "Variable PGDATA is unset but mandatory here (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_PASSWORD" ] && exiterror "Variable POSTGRES_PASSWORD is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_USER" ] && exiterror "Variable POSTGRES_USER is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_DB" ] && exiterror "Variable POSTGRES_DB is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"

[ -z "$REMOTE_SQL_IP_PATH" ] && exiterror "Variable REMOTE_SQL_IP_PATH is unset (path to file containing IP address of postgres server)"
[ -z "$ERROR_PATH" ] && exiterror "Variable ERROR_PATH is unset (path to file that may contain an error if previous step failed)"

[ -z "$REMOTE_SQL_DBNAME" ] && exiterror "Variable REMOTE_SQL_DBNAME is unset"
[ -z "$REMOTE_SQL_USERNAME" ] && exiterror "Variable REMOTE_SQL_USERNAME is unset"
[ -z "$REMOTE_SQL_PASSWORD" ] && exiterror "Variable REMOTE_SQL_PASSWORD is unset"

[ -z "$DATA_FOLDER" ] && exiterror "Variable DATA_FOLDER is unset (path to folder where pg_dump will write data: must be empty or non-existent)"
[ -z "$OUTPUT_FILEPATH" ] && exiterror "Variable OUTPUT_FILEPATH is unset (path to file that will be created containing the produced file name"


# find "${DATA_FOLDER}" -type d  -empty FIXME exit quickly if not empty

echo "Waiting for previous step to produce SQL instance IP in '$REMOTE_SQL_IP_PATH' or error in '$ERROR_PATH'"

while sleep 1; do
	test -e "$REMOTE_SQL_IP_PATH" && break
	test -e "$ERROR_PATH" && exiterror "An error happened in previous step: $(cat $ERROR_PATH)"
done

# ex SCHEMA: (info|subgraphs|public|chain1|sgd1)
if [ -z "$SCHEMAS" ]; then 
	SCHEMA_SPEC=""
else
	SCHEMA_SPEC="-n $SCHEMAS"
fi

set -e
REMOTE_SQL_IP=$(cat "$REMOTE_SQL_IP_PATH")

echo "Dumping database $REMOTE_SQL_DBNAME from remote server ${REMOTE_SQL_IP}:5432 using user $REMOTE_SQL_USERNAME to folder ${DATA_FOLDER}"

export PGPASSWORD="${REMOTE_SQL_PASSWORD}"

pg_dump --blobs --dbname="$REMOTE_SQL_DBNAME" --file="${DATA_FOLDER}" --format=directory --host="$REMOTE_SQL_IP" --jobs=$THREADS --port=5432 --username="$REMOTE_SQL_USERNAME" $SCHEMA_SPEC
unset PGPASSWORD

echo "Starting local postgres server and waiting for ready"

docker-entrypoint.sh postgres &
while sleep 1; do
    pg_isready && break
done

echo "Restoring database $REMOTE_SQL_DBNAME into local database"

## FIXME must add the --exit-on-error flag
pg_restore --no-owner --format=directory --jobs=$THREADS --username "${POSTGRES_USER} -d "${POSTGRES_DB}" "${DATA_FOLDER}" 

echo "Waiting until local database is stopped"
pkill postgres
while sleep 1; do
    pg_isready || break
done

cd $PGDATA && tar czf "${DATA_FOLDER}/pgdata.tar.gz" .

echo "${DATA_FOLDER}/pgdata.tar.gz" > "$OUTPUT_FILEPATH"

