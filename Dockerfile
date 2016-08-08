FROM rashidw3/node
COPY . /app
WORKDIR /app
RUN npm install && \
    rm -rf /var/lib/apt/lists/*
EXPOSE 80
CMD ["pm2", "start", "server.js", "--no-daemon"]
