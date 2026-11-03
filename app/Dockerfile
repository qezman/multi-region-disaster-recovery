FROM node:22-alpine
WORKDIR /usr/src/app
ENV NODE_ENV=production PORT=3000
COPY package*.json ./
RUN npm ci --omit=dev
COPY db.js migrate.js server.js ./
USER node
EXPOSE 3000
CMD ["node", "server.js"]