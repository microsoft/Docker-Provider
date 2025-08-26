# docker buildx build --platform linux/amd64,linux/arm64 -t appmonitoring.azurecr.io/aks-validation-source-app:latest --push .

# Use official Node.js LTS image
FROM node:20

WORKDIR /app

COPY package.json ./
COPY index.js ./

EXPOSE 3002

CMD ["npm", "start"]
