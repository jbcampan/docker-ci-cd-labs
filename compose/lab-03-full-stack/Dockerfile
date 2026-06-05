FROM node:20-alpine

# Install wget for healthcheck
RUN apk add --no-cache wget

WORKDIR /app

COPY app/package*.json ./
RUN npm ci --omit=dev

COPY app/ .

EXPOSE 3000

CMD ["node", "index.js"]