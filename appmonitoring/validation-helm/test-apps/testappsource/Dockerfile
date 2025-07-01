# docker build -t appmonitoring.azurecr.io/aks-validation-source-app:latest .
# docker push appmonitoring.azurecr.io/aks-validation-source-app:latest 

# Use official Node.js LTS image
FROM node:20

WORKDIR /app

COPY package.json ./
COPY index.js ./

EXPOSE 3002

CMD ["npm", "start"]
