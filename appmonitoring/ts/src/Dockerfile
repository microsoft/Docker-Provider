FROM node:alpine
RUN apk -U upgrade

#FROM node:16
#FROM node:slim
# RUN apt-get update && apt-get upgrade -y && apt-get autoremove && apt-get autoclean

WORKDIR /mutating-webhook

COPY . /mutating-webhook

#RUN npm update --save
#RUN npm outdated
#RUN npm install typescript

#RUN pwd
#RUN ls -a

#RUN rm *.js.map -f && rm *.js -f
#RUN tsc --build

EXPOSE 1337
CMD [ "node", "server" ]