FROM postgres:13.3
RUN apt-get update && apt-get -y install procps

COPY tarballer.sh /
ENTRYPOINT ./tarballer.sh
