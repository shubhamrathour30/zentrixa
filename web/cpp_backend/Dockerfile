FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends g++ libcurl4-openssl-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY server.cpp zx_util.h zx_games.h httplib.h ./
RUN g++ -std=c++17 -O2 server.cpp -o server -lcurl -lpthread
# Data (users, chats, posts, photos) yahan banta hai: hosting par is folder pe persistent disk lagao
VOLUME /app/data
ENV PORT=8080
EXPOSE 8080
CMD ["./server"]
