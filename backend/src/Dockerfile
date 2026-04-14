FROM node:20 AS base

RUN mkdir -p /app

WORKDIR /app

COPY . /app

WORKDIR /app/src

RUN npm install

ENV NODE_ENV=production \
    PORT=3000

EXPOSE 3000
CMD ["/bin/sh", "-c", "exec node server.js"]