#!/bin/bash -eu

echo "uploading ${INPUT_FILE} to bucket ${DEST_BUCKET}"
gsutil cp ${INPUT_FILE} gs://${DEST_BUCKET}/