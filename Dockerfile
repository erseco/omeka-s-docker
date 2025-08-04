FROM php:8.2-fpm-alpine

# Omeka-S web publishing platform for digital heritage collections (https://omeka.org/s/)
# Previous maintainers: Oldrich Vykydal (o1da) - Klokan Technologies GmbH  / Eric Dodemont <eric.dodemont@skynet.be>
# MAINTAINER Giorgio Comai <g@giorgiocomai.eu>

# Install apache2 and other dependencies
RUN apk update && apk add --no-cache \
    apache2 \
    curl \
    unzip \
    wget \
    jq \
    ghostscript \
    poppler-utils \
    netcat-openbsd \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    zlib-dev \
    icu-dev \
    libsodium-dev \
    imagemagick \
    imagemagick-dev

# Configure apache
RUN sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule proxy_module/LoadModule proxy_module/' /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule proxy_fcgi_module/LoadModule proxy_fcgi_module/' /etc/apache2/httpd.conf

RUN { \
        echo '<FilesMatch \.php$>'; \
        echo '\tSetHandler "proxy:fcgi://127.0.0.1:9000"'; \
        echo '</FilesMatch>'; \
        echo; \
        echo 'DirectoryIndex disabled'; \
        echo 'DirectoryIndex index.php index.html'; \
        echo; \
        echo '<Directory /var/www/>'; \
        echo '\tOptions -Indexes'; \
        echo '\tAllowOverride All'; \
        echo '</Directory>'; \
    } > "/etc/apache2/conf.d/docker-php.conf"

# Redirect Apache logs to stdout/stderr
RUN ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log

# Set default environment variables
ENV APPLICATION_ENV=production

# Use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Install PHP extension installer tool
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Install PHP extensions using the tool
RUN install-php-extensions \
    gd \
    iconv \
    pdo \
    pdo_mysql \
    mysqli \
    imagick \
    intl \
    xsl \
    opcache

# Add the Omeka-S PHP code
RUN wget --no-verbose "https://github.com/omeka/omeka-s/releases/download/v4.1.1/omeka-s-4.1.1.zip" -O /var/www/latest_omeka_s.zip
RUN unzip -q /var/www/latest_omeka_s.zip -d /var/www/ \
&&  rm /var/www/latest_omeka_s.zip \
&&  rm -rf /var/www/html/ \
&&  mv /var/www/omeka-s/ /var/www/html/

COPY ./imagemagick-policy.xml /etc/ImageMagick-7/policy.xml

# Create one volume for files, config, themes, modules and logs
RUN mkdir -p /var/www/html/volume/config/ && mkdir -p /var/www/html/volume/files/ && mkdir -p /var/www/html/volume/modules/ && mkdir -p /var/www/html/volume/themes/ && mkdir -p /var/www/html/volume/logs/


COPY ./database.ini /var/www/html/volume/config/
COPY ./local.config.php /var/www/html/volume/config/
RUN rm /var/www/html/config/database.ini \
&& ln -s /var/www/html/volume/config/database.ini /var/www/html/config/database.ini \
&& rm /var/www/html/config/local.config.php \
&& ln -s /var/www/html/volume/config/local.config.php /var/www/html/config/local.config.php \
&& rm -Rf /var/www/html/files/ \
&& ln -s /var/www/html/volume/files/ /var/www/html/files \
&& rm -Rf /var/www/html/modules/ \
&& ln -s /var/www/html/volume/modules/ /var/www/html/modules \
&& rm -Rf /var/www/html/themes/ \
&& ln -s /var/www/html/volume/themes/ /var/www/html/themes \
&& rm -Rf /var/www/html/logs/ \
&& ln -s /var/www/html/volume/logs/ /var/www/html/logs \
&& chown -R apache:apache /var/www/html/ \
&& chmod 600 /var/www/html/volume/config/database.ini \
&& chmod 600 /var/www/html/volume/config/local.config.php \
&& chmod 600 /var/www/html/.htaccess

VOLUME /var/www/html/volume/

# Copy the automatic installation script
COPY install_cli.php /var/www/html/

COPY apache2-foreground /usr/local/bin/
RUN chmod +x /usr/local/bin/apache2-foreground

COPY docker-php-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-entrypoint

COPY docker-php-entrypoint_custom /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-entrypoint_custom

ENTRYPOINT ["docker-php-entrypoint_custom"]

WORKDIR /var/www/html
EXPOSE 80
CMD ["apache2-foreground"]
