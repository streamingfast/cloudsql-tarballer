#!/bin/bash

exiterror() {
        [ -z "$OUTFILE_ERROR" ] && OUTFILE_ERROR=/tmp/errorout
        echo $@ | tee $OUTFILE_ERROR
        exit 1
}

[ -z "$INFILE_TARBALLPATH" ] && exiterror "Variable INFILE_TARBALLPATH is not set (file containing filename from previous step)"
[ -z "$INFILE_ERROR" ] && exiterror "Variable INFILE_ERROR is unset (file containing error from previous step)"
[ -z "$DEST_TARBALL_URL" ] && exiterror "Variable DEST_TARBALL_URL is unset (where we upload the file to, ex: gs://mybucket/tarballs/)"
[ -z "$OUTFILE_ERROR" ] && exiterror "Variable OUTFILE_ERROR is unset (where we write if an error happened)"

echo "Waiting for previous step to write tarball file name in '$INPUT_FILE_PATH' or error in '$ERROR_PATH'"

while sleep 1; do
        test -e "$INFILE_TARBALLPATH" && break
        test -e "$ERROR_PATH" && exiterror "An error happened in previous step: $(cat $ERROR_PATH)"
done

INPUT_FILE="$(cat $INPUT_FILE_PATH)"

echo "uploading ${INPUT_FILE} to ${DEST_TARBALL_URL}/$(basename $INPUT_FILE)"
gsutil cp ${INPUT_FILE} "${DEST_TARBALL_URL}/$(basename $INPUT_FILE)" || exiterror "could not upload to google storage..."
