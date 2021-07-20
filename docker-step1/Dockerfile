FROM gcr.io/google.com/cloudsdktool/cloud-sdk:latest

RUN apt-get update && apt-get -y install jq
COPY gcp_sql_clone.sh /
ENTRYPOINT /gcp_sql_clone.sh
