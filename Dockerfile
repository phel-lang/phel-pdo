FROM php:8.2-cli

RUN apt-get update && apt-get install -y zip && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
ENTRYPOINT []
