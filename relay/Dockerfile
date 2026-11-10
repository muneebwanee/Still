FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force
COPY server.mjs ./
COPY public ./public
USER node
ENV BIND_ADDRESS=0.0.0.0 PORT=8080
EXPOSE 8080
CMD ["node", "server.mjs"]
