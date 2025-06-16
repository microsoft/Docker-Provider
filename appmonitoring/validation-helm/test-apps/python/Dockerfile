# Use the official Python image
FROM python:3.9

# Set the working directory
WORKDIR /app

# Copy the application files
COPY app.py /app/

# Install Flask
RUN pip install flask requests

# Expose port
EXPOSE 3001

# Command to run the application
CMD ["python", "app.py"]