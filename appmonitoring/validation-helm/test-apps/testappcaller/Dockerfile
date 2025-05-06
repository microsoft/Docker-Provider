FROM node:20

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install --production

COPY index.js ./

CMD ["node", "index.js"]