# === Base PHP + Apache ===
FROM php:8.3-apache

# === Dépendances système et PHP ===
RUN apt-get update && apt-get install -y --no-install-recommends \
        libzip-dev zlib1g-dev libpng-dev libjpeg-dev libfreetype6-dev \
        libicu-dev libxml2-dev libonig-dev libldap2-dev libbz2-dev \
        unzip git nano \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        mysqli pdo_mysql intl mbstring zip bcmath gd exif ldap bz2 \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /var/lib/apt/lists/*

# === Copier le code GLPI ===
# Structure recommandée :
# /var/www/html/glpi/public -> fichiers publics (index.php, .htaccess)
# /var/www/html/glpi/config, vendor, front, etc. -> autres dossiers
COPY ./app /var/www/html/glpi

# === Dossiers de données GLPI en dehors du web root ===
RUN mkdir -p /var/lib/glpi/_sessions \
             /var/lib/glpi/_cache \
             /var/lib/glpi/_uploads \
             /var/lib/glpi/_plugins \
             /var/lib/glpi/_inventories \
             /var/lib/glpi/_locales \
             /var/lib/glpi/_lock \
             /var/lib/glpi/_pictures \
             /var/lib/glpi/_rss \
             /var/lib/glpi/_themes \
    && mkdir -p /var/log/glpi

# === Permissions ===
RUN chown -R www-data:www-data /var/www/html/glpi \
    && chown -R www-data:www-data /var/lib/glpi \
    && chown -R www-data:www-data /var/log/glpi \
    && chmod -R 755 /var/www/html/glpi \
    && chmod -R 700 /var/lib/glpi

# === Apache configuration ===
COPY ./confs/apache/glpi.10.conf /etc/apache2/sites-available/glpi.10.conf
RUN a2dissite 000-default.conf \
    && a2ensite glpi.10.conf \
    && a2enmod rewrite \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# === PHP configuration pour les sessions ===
RUN echo "session.save_path=/var/lib/glpi/_sessions" > /usr/local/etc/php/conf.d/99-glpi-sessions.ini \
    && echo "session.cookie_secure=0" >> /usr/local/etc/php/conf.d/99-glpi-sessions.ini \
    && echo "session.cookie_httponly=1" >> /usr/local/etc/php/conf.d/99-glpi-sessions.ini \
    && echo "session.cookie_samesite=Lax" >> /usr/local/etc/php/conf.d/99-glpi-sessions.ini

# === Expose Apache port ===
EXPOSE 80

# === Démarrage ===
CMD ["apache2-foreground"]
