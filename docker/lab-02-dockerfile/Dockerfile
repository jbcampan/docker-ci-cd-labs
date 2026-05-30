# Base image — Python slim to keep it lightweight
FROM python:3.11-slim

# Working directory inside the container
WORKDIR /app

# Install the application dependencies first
COPY app/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy in the source code
COPY app/ .

# Document the exposed port (informational only, does not publish the port)
EXPOSE 5000

# Starting command
CMD ["python", "app.py"]