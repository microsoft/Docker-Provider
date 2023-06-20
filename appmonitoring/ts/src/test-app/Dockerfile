FROM alpine:latest
RUN apk -U upgrade
RUN apk add --update nodejs npm

#FROM node:alpine
# RUN apk -U upgrade

WORKDIR /app

COPY . /app

EXPOSE 80
CMD [ "node", "server" ]