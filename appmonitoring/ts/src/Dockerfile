#FROM node:16
FROM node:alpine

# RUN apt-get update && apt-get upgrade -y && apt-get autoremove && apt-get autoclean
# RUN apt-get install --only-upgrade libpython2.7-minimal -y
RUN apk -U upgrade

WORKDIR  /mutating-webhook

COPY . /mutating-webhook

RUN npm outdated
RUN npm update --save
RUN npm outdated

RUN pwd && cd ./mutating-webhook && rm *.js.map -f
RUN pwd && cd ./mutating-webhook && rm *.js -f
RUN pwd && cd ./mutating-webhook && tsc --build

EXPOSE 1337
CMD [ "node", "server" ]