# docker image base
ARG BASE_NGINX=nginx:1.27-alpine3.21
ARG BASE_PHP=php:8.3-fpm-alpine3.21

################################################################################
## node-builder: compile Vite frontend assets (public/build/)                ##
## Output: public/build/manifest.json + compiled JS/CSS chunks               ##
################################################################################
FROM node:22-alpine3.21 AS node-builder
WORKDIR /var/www/html/realit_product

# Install deps first (cached layer unless package-lock.json changes)
COPY package.json ./

RUN npm install npm ci --silent

# Copy only files needed for Vite build
COPY vite.config.js postcss.config.js tailwind.config.js ./
COPY resources ./resources
COPY public ./public

# Build production assets → public/build/manifest.json
RUN npm run build

FROM $BASE_NGINX AS nginx-builder
COPY .docker/nginx/templates/* /etc/nginx/templates/
## php-fpm-alpine-builder image: install common php extension need for project
FROM $BASE_PHP AS php-fpm-alpine-builder
LABEL maintainer="huypq"
ENV TZ=Asia/Tokyo
RUN set -eux; \
    # ... (đoạn timezone) ...
    echo "INSTALL PHP EXTENSION NEEDED 'pdo_mysql' 'opcache' 'gd'"; \
    # 1. Install build dependencies
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS libpng-dev libjpeg-turbo-dev freetype-dev; \
    # 2. Cài runtime dependencies
    # Gói 'libpng', 'libjpeg-turbo', 'freetype' cần thiết cho GD
    apk add --no-cache libpng libjpeg-turbo freetype; \
    # 3. Configure GD with JPEG and FreeType support
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    apk add --no-cache libzip-dev zlib-dev zip; \
    docker-php-ext-configure zip; \
    docker-php-ext-install -j "$(nproc)" zip; \
    # 4. Cài extension
    docker-php-ext-install -j "$(nproc)" pdo_mysql opcache gd; \
    echo 'CLEAN UP TEMP TO REDUCE DOCKER IMAGE SIZES'; \
    rm -rf /tmp/* /var/cache/apk/*

#####################################################################################################################
## realit-public: bundle  public source code (js,css). use this image on read-only env (production, staging) ##
#####################################################################################################################
FROM nginx-builder AS realit-public

# tag help inspect docker image in the future
ARG GIT_COMMIT_HASH=unspecified
ARG GIT_BRANCH_NAME=unspecified

LABEL maintainer="huypq" \
    git.commit=$GIT_COMMIT_HASH \
    git.branch=$GIT_BRANCH_NAME

WORKDIR /var/www/html/realit_product/public
COPY .docker/nginx/conf.d/realit-app.conf /etc/nginx/conf.d/default.conf
COPY .docker/nginx/nginx.conf /etc/nginx/nginx.conf
# Copy public dir from host (favicon, robots.txt, etc.) then overlay Vite build from node-builder
COPY --chown=nginx:nginx public .
COPY --from=node-builder --chown=nginx:nginx /var/www/html/realit_product/public/build ./build
EXPOSE 80

##########################################################################################################
## realit-vendor ##
##########################################################################################################
FROM composer:2.8 AS vendor
WORKDIR /var/www/html/realit_product
COPY --chown=www-data:www-data composer.json artisan ./
RUN set -eux; \
composer install \
        --quiet \
        --ignore-platform-reqs \
        --no-interaction \
        --no-progress \
        --no-suggest \
        --no-scripts \
        --prefer-dist \
        --no-autoloader \
        --no-dev;

## php-fpm-dev image: install php extension support for developer
FROM php-fpm-alpine-builder AS php-fpm-dev
ARG USER_ID=1000
ARG GROUP_ID=1000
ENV COMPOSER_CACHE_DIR=/tmp
WORKDIR /var/www/html/realit_product

RUN set -eux; \
        echo "INSTALL NPM nodejs, Xdebug"; \
            apk add nodejs;\
            apk add --update npm;\
            apk add --no-cache linux-headers;\
            apk add --no-cache --virtual .build-deps $PHPIZE_DEPS; \
            pecl install xdebug; \
            docker-php-ext-enable xdebug; \
        \
        apk del .build-deps; \
        cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"; \
        \
        echo 'CLEAN UP TEMP TO REDUCE DOCKER IMAGE SIZES'; \
        rm -rf /tmp/* /var/cache/apk/*
COPY .docker/php/conf.d/z-xdebug.dev.ini .docker/php/conf.d/z-php.dev.ini $PHP_INI_DIR/conf.d/
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

##########################################################################################################
## realit-app: Production PHP-FPM image ##
##########################################################################################################
FROM php-fpm-alpine-builder AS realit-app
ARG GIT_COMMIT_HASH=unspecified
ARG GIT_BRANCH_NAME=unspecified
LABEL maintainer="huypq" \
    git.commit=$GIT_COMMIT_HASH \
    git.branch=$GIT_BRANCH_NAME
ENV TZ=Asia/Tokyo
WORKDIR /var/www/html/realit_product

# Copy vendor dependencies from vendor stage
COPY --from=vendor /var/www/html/realit_product/vendor ./vendor

# Copy application code
COPY --chown=www-data:www-data . .

# Overlay compiled Vite assets from node-builder
# (public/build is in .gitignore so the COPY above won't include it)
COPY --from=node-builder --chown=www-data:www-data /var/www/html/realit_product/public/build ./public/build

# Generate autoloader (needed because vendor stage used --no-autoloader)
# and optimize for production
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer dump-autoload --optimize --no-dev --no-scripts --ignore-platform-reqs && \
    rm -f vendor/composer/platform_check.php && \
    rm -rf /root/.composer

# Regenerate package discovery cache based on production vendor (no dev packages)
# This overwrites any stale bootstrap/cache/packages.php copied from host
RUN mkdir -p bootstrap/cache && chmod 755 bootstrap/cache && \
    APP_KEY="base64:tmpkeyfortmpkeyfortmpkeyfortmpkeyfortmpkey0=" \
    php artisan package:discover --ansi 2>&1 || true

# Use production PHP configuration
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
