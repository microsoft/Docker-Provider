FROM node:16

# RUN apt-get update && apt-get upgrade -y && apt-get autoremove && apt-get autoclean
RUN apt-get install --only-upgrade libpython2.7-minimal -y

WORKDIR  /mutating-webhook

COPY . /mutating-webhook

EXPOSE 1337
CMD [ "node", "server" ]