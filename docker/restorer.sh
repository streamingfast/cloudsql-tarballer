#!/bin/bash

exiterror() {
	if [ -z "$SIGNALING_FOLDER" ]; then SIGNALING_FOLDER=/tmp; fi
        echo $@ | tee $SIGNALING_FOLDER/dberror
        exit 1
}

THREADS=${THREADS:-10}

[ -z "$PGDATA" ] && exiterror "Variable PGDATA is unset but mandatory here (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_PASSWORD" ] && exiterror "Variable POSTGRES_PASSWORD is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_USER" ] && exiterror "Variable POSTGRES_USER is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"
[ -z "$POSTGRES_DB" ] && exiterror "Variable POSTGRES_DB is unset (see https://github.com/docker-library/docs/blob/master/postgres/README.md#environment-variables)"


[ -z "$SIGNALING_FOLDER" ] && exiterror "Variable SIGNALING_FOLDER is unset (link to signaling file to touch when ready)"

[ -z "$SRC_TARBALL_URL" ] && exiterror "Variable SRC_TARBALL_URL is unset (where we download the file to, ex: gs://mybucket/tarballs/)"

if [ "$SRC_TARBALL_FILENAME" == "" ]; then
    SRC_TARBALL_URL_FULL=$(gsutil ls "${SRC_TARBALL_URL}" |tail -n 1)
else
    SRC_TARBALL_URL_FULL="${SRC_TARBALL_URL}/${SRC_TARBALL_FILENAME}"
fi
[ -z "$SRC_TARBALL_URL" ] && exiterror "cannot figure out SRC_TARBALL_URL_FULL from SRC_TARBALL_URL and SRC_TARBALL_FILENAME"

mkdir -p "$PGDATA"

if ! [ -z "$(find $PGDATA -mindepth 1 -not -name lost+found)" ]; then
        exiterror "DATA_FOLDER  ($PGDATA) is not empty but it should be"
fi

echo "downloading and extracting $SRC_TARBALL_URL_FULL to ${PGDATA}"
cd ${PGDATA}
gsutil cat $SRC_TARBALL_URL_FULL | tar xzf - || exiterror "could not download from google storage..."

echo "Starting local postgres server and waiting for ready"

docker-entrypoint.sh postgres &
while sleep 1; do
    # initialization phase by docker-entrypoint would wrongly show pg as ready
    pgrep -f listen_addresses= >/dev/null && continue
    pg_isready && break
done

echo "DB ready, writing to ${SIGNALING_FOLDER}/dbready and waiting for ${SIGNALING_FOLDER}/complete"
touch ${SIGNALING_FOLDER}/dbready
while sleep 1; do
    test -e "${SIGNALING_FOLDER}/complete" && break
done

if test -x "${SIGNALING_FOLDER}/complete" && test -s "${SIGNALING_FOLDER}/complete"; then
    echo "executing content of 'complete' script"
    "${SIGNALING_FOLDER}/complete"
fi


