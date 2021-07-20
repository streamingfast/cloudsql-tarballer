#!/bin/bash

exiterror() {
        [ -z "$OUTFILE_ERROR" ] && OUTFILE_ERROR=/tmp/errorout
        echo $@ | tee $OUTFILE_ERROR
	exit 1
}

THREADS=${THREADS:-10}

[ -z "$INFILE_CLONE_INSTANCE_IP" ] && exiterror "Variable INFILE_CLONE_INSTANCE_IP is unset (path to file containing IP address of postgres server)"
[ -z "$INFILE_ERROR" ] && exiterror "Variable INFILE_ERROR is unset (path to file that may contain an error if previous step failed)"

[ -z "$PGDATA" ] && exiterror "Variable PGDATA is unset but mandatory here (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_PASSWORD" ] && exiterror "Variable POSTGRES_PASSWORD is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_USER" ] && exiterror "Variable POSTGRES_USER is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_DB" ] && exiterror "Variable POSTGRES_DB is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"

[ -z "$REMOTE_SQL_DBNAME" ] && exiterror "Variable REMOTE_SQL_DBNAME is unset"
[ -z "$REMOTE_SQL_USERNAME" ] && exiterror "Variable REMOTE_SQL_USERNAME is unset"
[ -z "$REMOTE_SQL_PASSWORD" ] && exiterror "Variable REMOTE_SQL_PASSWORD is unset"

[ -z "$DATA_FOLDER" ] && exiterror "Variable DATA_FOLDER is unset (path to folder where pg_dump will write data: must be empty or non-existent)"

[ -z "$OUTFILE_TARBALLPATH" ] && exiterror "Variable OUTFILE_TARBALLPATH is unset (path to file that will be created containing the produced file name"
[ -z "$OUTFILE_ERROR" ] && exiterror "Variable OUTFILE_ERROR is unset (path to file where we signal that an error happened in this step)"

# ex SCHEMA: (info|subgraphs|public|chain1|sgd1)
if [ -z "$SCHEMAS" ]; then 
	SCHEMA_SPEC=""
else
	SCHEMA_SPEC="-n $SCHEMAS"
fi

mkdir -p "$DATA_FOLDER"
if ! [ -z "$(find $DATA_FOLDER -maxdepth 0 -type d -not -empty)" ]; then 
	exiterror "DATA_FOLDER  ($DATA_FOLDER) is not empty but it should be"
fi

echo "Waiting for previous step to produce SQL instance IP in '$REMOTE_SQL_IP_PATH' or error in '$INFILE_ERROR'"

while sleep 1; do
	test -e "$INFILE_CLONE_INSTANCE_IP" && break
	test -e "$INFILE_ERROR" && exiterror "An error happened in previous step: $(cat $INFILE_ERROR)"
done

REMOTE_SQL_IP=$(cat "$INFILE_CLONE_INSTANCE_IP")

echo "Dumping database $REMOTE_SQL_DBNAME from remote server ${REMOTE_SQL_IP}:5432 using user $REMOTE_SQL_USERNAME to folder ${DATA_FOLDER}"

export PGPASSWORD="${REMOTE_SQL_PASSWORD}"

pg_dump --blobs --dbname="$REMOTE_SQL_DBNAME" --file="${DATA_FOLDER}" --format=directory --host="$REMOTE_SQL_IP" --jobs=$THREADS --port=5432 --username="$REMOTE_SQL_USERNAME" $SCHEMA_SPEC
# FIXME find a way to only catch 'important' errors
unset PGPASSWORD

echo "Starting local postgres server and waiting for ready"

docker-entrypoint.sh postgres &
while sleep 1; do
    # initialization phase by docker-entrypoint would wrongly show pg as ready
    pgrep -f listen_addresses= >/dev/null && continue
    pg_isready && break
done

echo "Restoring database $REMOTE_SQL_DBNAME into local database"

## FIXME must add the --exit-on-error flag
pg_restore --no-owner --format=directory --jobs=$THREADS --username "${POSTGRES_USER}" -d "${POSTGRES_DB}" "${DATA_FOLDER}" 

echo "Waiting until local database is stopped"
pkill postgres
while sleep 1; do
    pg_isready || break
done

FILENAME=pgdata-$(date +%s).tar.gz
cd $PGDATA && tar czf "${DATA_FOLDER}/${FILENAME}" .

echo "${DATA_FOLDER}/${FILENAME}" > "$OUTPUT_TARBALLPATH"
