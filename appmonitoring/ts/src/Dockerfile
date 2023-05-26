#FROM node:16
FROM node:alpine

# RUN apt-get update && apt-get upgrade -y && apt-get autoremove && apt-get autoclean
# RUN apt-get install --only-upgrade libpython2.7-minimal -y
RUN apk -U upgrade

RUN npm outdated
RUN npm update --save
RUN npm outdated

RUN cd /mutating-webhook && del *.js.map
RUN cd /mutating-webhook && del *.js
RUN cd /mutating-webhook && tsc --build

WORKDIR  /mutating-webhook

COPY . /mutating-webhook

EXPOSE 1337
CMD [ "node", "server" ]