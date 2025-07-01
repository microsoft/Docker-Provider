# docker build -t appmonitoring.azurecr.io/demoaks-nodejs-app:latest .
# docker push appmonitoring.azurecr.io/demoaks-nodejs-app:latest 

# Use official Node.js LTS image
FROM node:20

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --production

# Copy server code
COPY server.js ./

# Expose port
EXPOSE 3001

# Start the server
CMD ["node", "server.js"]
