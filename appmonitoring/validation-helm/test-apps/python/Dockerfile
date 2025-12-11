# docker buildx build --platform linux/amd64,linux/arm64 -t appmonitoring.azurecr.io/demoaks-python-app:latest --push .

# Use the official Python image
FROM python:3.9

# Set the working directory
WORKDIR /app

# Copy the application files
COPY app.py /app/
COPY requirements.txt /app/

# Install dependencies
RUN pip install -r requirements.txt

# Expose port
EXPOSE 3001

# Command to run the application
CMD ["python", "app.py"]