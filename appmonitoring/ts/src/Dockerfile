#FROM node:16
FROM node:alpine

# RUN apt-get update && apt-get upgrade -y && apt-get autoremove && apt-get autoclean
# RUN apt-get install --only-upgrade libpython2.7-minimal -y
RUN apk -U upgrade

WORKDIR  /mutating-webhook

COPY . /mutating-webhook

EXPOSE 1337
CMD [ "node", "server" ]