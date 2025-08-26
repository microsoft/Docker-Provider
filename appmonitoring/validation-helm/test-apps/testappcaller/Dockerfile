# docker buildx build --platform linux/amd64,linux/arm64 -t appmonitoring.azurecr.io/nodejs-caller-app:latest --push .

FROM node:20

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install --production

COPY index.js ./

CMD ["node", "index.js"]