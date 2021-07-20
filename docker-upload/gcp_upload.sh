#!/bin/bash

exiterror() {
        echo $@
        exit 1
}

[ -z "$INPUT_FILE_PATH" ] && exiterror "Variable INPUT_FILE_PATH is not set"
[ -z "$DEST_URL" ] && exiterror "Variable DEST_URL is unset"
[ -z "$ERROR_PATH" ] && exiterror "Variable ERROR_PATH is unset"

echo "Waiting for previous step to write tarball file name in '$INPUT_FILE_PATH' or error in '$ERROR_PATH'"

while sleep 1; do
        test -e "$INPUT_FILE_PATH" && break
        test -e "$ERROR_PATH" && exiterror "An error happened in previous step: $(cat $ERROR_PATH)"
done

INPUT_FILE="$(cat $INPUT_FILE_PATH)"

echo "uploading ${INPUT_FILE} to ${DEST_URL}/$(basename $INPUT_FILE)"
gsutil cp ${INPUT_FILE} "${DEST_URL}/$(basename $INPUT_FILE)" || exiterror "could not upload to google storage..."

