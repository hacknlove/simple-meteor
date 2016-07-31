FROM node:6.3.0-wheezy

MAINTAINER pykiss

LABEL version="1.0"
RUN apt-get update
RUN apt-get installvsudo
RUN apt-get autoclean

WORKDIR /meteor
COPY start.sh /

ENTRYPOINT ["bash", "/start.sh"]

CMD []
