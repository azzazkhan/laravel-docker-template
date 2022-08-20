FROM composer:latest as build
COPY composer.json composer.lock ./
COPY helpers/ helpers
RUN composer install --no-progress --optimize-autoloader --quiet \
  --no-interaction --no-scripts
COPY . .
RUN php artisan package:discover --ansi && php artisan vendor:publish --all


FROM ubuntu:20.04

ARG WWWGROUP
ENV DEBIAN_FRONTEND noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install required packages
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
  ca-certificates software-properties-common apache2 supervisor libcap2-bin \
  libpng-dev libonig-dev libxml2-dev openssl libbz2-dev zlib1g-dev \
  libzip-dev libcurl4-openssl-dev

# Add PPA respository for installing PHP 8.1
RUN add-apt-repository ppa:ondrej/php -y && apt-get update

# Install required PHP 8.1 packages and Apache compaitble modules
RUN apt-get --fix-missing install -y php8.1 php8.1-fpm php8.1-cli php8.1-cgi php8.1-common libapache2-mod-php8.1 libapache2-mod-fcgid php-phpseclib php8.1-bcmath php8.1-bz2 php8.1-curl php8.1-decimal php8.1-gd php8.1-gmp php8.1-grpc php8.1-igbinary php8.1-imagick php8.1-imap php8.1-intl php8.1-ldap php8.1-mbstring php8.1-mcrypt php8.1-msgpack php8.1-mysql php8.1-opcache php8.1-pcov php8.1-soap php8.1-ssh2 php8.1-vips php8.1-xml php8.1-xmlrpc php8.1-xsl php8.1-yaml php8.1-zip

# Configure Apache to use PHP and enable required modules
RUN a2enmod proxy_fcgi setenvif rewrite && a2enconf php8.1-fpm \
  && rm -rf /var/www/html

# Replace default Apache configuration with our custom one
COPY docker/000-default.conf /etc/apache2/sites-available/

# Copy our files to web server root
WORKDIR /var/www
COPY --from=build /app .

# Setup permissions file permissions
RUN chown -R $USER:www-data . \
  && find . -type f -exec chmod 664 {} \; \
  && find . -type d -exec chmod 775 {} \; \
  && chgrp -R www-data storage bootstrap/cache \
  && chmod -R ug+rwx storage bootstrap/cache \
  && chmod +x docker/service.sh

RUN cp .env.production .env && chmod 644 .env \
  # Make symbolic link for storage and cache files for optimization
  && php artisan key:generate --ansi \
  && php artisan storage:link \
  && php artisan optimize

RUN service php8.1-fpm start

EXPOSE 443 80

CMD ["/var/www/docker/service.sh"]
