FROM dunglas/frankenphp:latest-php8.2-alpine

# Install dependencies yang diperlukan untuk Swoole
RUN apk add --no-cache \
    $PHPIZE_DEPS \
    postgresql-dev \
    oniguruma-dev \
    libxml2-dev \
    linux-headers \
    openssl-dev \
    curl-dev \
    c-ares-dev \
    brotli-dev \
    zstd-dev \
    unzip \
    git

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_pgsql \
    pcntl \
    mbstring \
    xml \
    sockets

# Install Swoole dengan metode download dan kompilasi manual
RUN cd /tmp && \
    curl -SL "https://github.com/swoole/swoole-src/archive/v5.1.1.tar.gz" -o swoole.tar.gz && \
    tar xzf swoole.tar.gz && \
    cd swoole-src-5.1.1 && \
    phpize && \
    ./configure \
        --enable-openssl \
        --enable-http2 \
        --enable-sockets && \
    make && \
    make install && \
    docker-php-ext-enable swoole && \
    rm -rf /tmp/swoole.tar.gz /tmp/swoole-src-5.1.1

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Copy the application
COPY . .

# Install dependencies
RUN composer install --optimize-autoloader --no-dev

# Copy FrankenPHP configuration
COPY ./docker/Caddyfile /etc/caddy/Caddyfile

# Set permissions
RUN chmod -R 775 /app/storage

# Set Laravel configuration
ENV APP_ENV=production
ENV APP_DEBUG=false
ENV APP_URL=http://localhost

# Generate application key
RUN php artisan key:generate

# Optimize Laravel
RUN php artisan optimize

# Expose ports
EXPOSE 80
EXPOSE 443

# Run FrankenPHP
CMD ["php", "artisan", "octane:start", "--server=swoole", "--host=0.0.0.0", "--port=8000"]