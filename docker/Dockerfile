FROM postgres:13.3

RUN apt-get update 
RUN apt-get -y install apt-transport-https ca-certificates gnupg curl
RUN apt-get -y install procps jq

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

RUN apt-get update  && apt-get -y install google-cloud-sdk

COPY tarballer.sh /
COPY restorer.sh /
ENTRYPOINT /tarballer.sh
