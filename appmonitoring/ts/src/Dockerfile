FROM node:16

RUN /usr/bin/apt-get update

WORKDIR  /mutating-webhook

COPY . /mutating-webhook

EXPOSE 1337
CMD [ "node", "server" ]