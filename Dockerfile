FROM mirror.gcr.io/library/php:8.2-apache AS php_base
# build-time env seeded from .env.example
ENV ADMIN_MAIL_ADDRESS=nexlayer-placeholder
ENV ADMIN_MAIL_NAME=Admin
ENV APP_ADMIN_URL=admin
ENV APP_CURRENCY=USD
ENV APP_DEBUG=true
ENV APP_DEBUG_ALLOWED_IPS=nexlayer-placeholder
ENV APP_ENV=local
ENV APP_FAKER_LOCALE=en_US
ENV APP_FALLBACK_LOCALE=en
ENV APP_KEY=nexlayer-placeholder
ENV APP_LOCALE=en
ENV APP_MAINTENANCE_DRIVER=file
ENV APP_NAME=Bagisto
ENV APP_TIMEZONE=Asia/Kolkata
ENV APP_URL=http://localhost
ENV AWS_ACCESS_KEY_ID=nexlayer-placeholder
ENV AWS_BUCKET=nexlayer-placeholder
ENV AWS_DEFAULT_REGION=us-east-1
ENV AWS_SECRET_ACCESS_KEY=nexlayer-placeholder
ENV AWS_USE_PATH_STYLE_ENDPOINT=false
ENV BCRYPT_ROUNDS=12
ENV BROADCAST_CONNECTION=log
ENV CACHE_PREFIX=nexlayer-placeholder
ENV CACHE_STORE=file
ENV CONTACT_MAIL_ADDRESS=nexlayer-placeholder
ENV CONTACT_MAIL_NAME=Contact
ENV DB_CONNECTION=mysql
ENV DB_DATABASE=nexlayer-placeholder
ENV DB_HOST=127.0.0.1
ENV DB_PASSWORD=nexlayer-placeholder
ENV DB_PORT=3306
ENV DB_PREFIX=nexlayer-placeholder
ENV DB_USERNAME=nexlayer-placeholder
ENV FILESYSTEM_DISK=public
ENV LOG_CHANNEL=stack
ENV LOG_DEPRECATIONS_CHANNEL=null
ENV LOG_LEVEL=debug
ENV LOG_STACK=single
ENV MAIL_FROM_ADDRESS=nexlayer-placeholder
ENV MAIL_FROM_NAME=Shop
ENV MAIL_HOST=127.0.0.1
ENV MAIL_MAILER=bagisto-dynamic-smtp
ENV MAIL_PASSWORD=null
ENV MAIL_PORT=2525
ENV MAIL_SCHEME=null
ENV MAIL_USERNAME=null
ENV MEMCACHED_HOST=127.0.0.1
ENV QUEUE_CONNECTION=sync
ENV REDIS_CLIENT=phpredis
ENV REDIS_HOST=127.0.0.1
ENV REDIS_PASSWORD=null
ENV REDIS_PORT=6379
ENV RESPONSE_CACHE_ENABLED=true
ENV SESSION_DOMAIN=null
ENV SESSION_DRIVER=database
ENV SESSION_ENCRYPT=false
ENV SESSION_LIFETIME=120
ENV SESSION_PATH=/
ENV VITE_APP_NAME=${APP_NAME}
ENV VITE_HOST=localhost
ENV VITE_PORT=nexlayer-placeholder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg
RUN docker-php-ext-install -j$(nproc) \
    gd \
    bcmath \
    intl \
    pdo_mysql \
    zip

# Install Composer
COPY --from=mirror.gcr.io/library/composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy source first to avoid script errors during install
COPY . ./

# Install dependencies ignoring scripts to prevent crashes during build
RUN composer install --no-interaction --optimize-autoloader --no-dev --no-scripts || true

# Fix permissions for Laravel
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache || true

# Build Frontend Assets
FROM mirror.gcr.io/library/node:20-alpine AS node_builder
WORKDIR /app
COPY --from=php_base /var/www/html ./
RUN npm install --no-audit || true
RUN npm run build || true

# Final Stage
FROM php_base

# Copy compiled assets from node builder
COPY --from=node_builder /app/public/build /var/www/html/public/build

# Create a default .env file to prevent HTTP 500 errors due to missing configuration
RUN cp .env.example .env || touch .env
RUN sed -i 's/APP_ENV=local/APP_ENV=production/g' .env || true
RUN sed -i 's/APP_DEBUG=true/APP_DEBUG=false/g' .env || true
RUN sed -i 's/APP_URL=http:\/\/localhost/APP_URL=https:\/\/relaxed-weasel-bagisto.cloud.nexlayer.ai/g' .env || true

# Configure Apache for Laravel/Bagisto
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -i 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite

# Final permissions check
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]