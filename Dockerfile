FROM nextcloud:27-apache

# Instalar dependências adicionais
RUN apt-get update && apt-get install -y \
    libmagickcore-6.q16-6-extra \
    ffmpeg \
    libsmbclient-dev \
    libsmbclient \
    smbclient \
    && rm -rf /var/lib/apt/lists/*

# Configurar permissões
RUN chown -R www-data:www-data /var/www/html

# Configurar PHP
RUN echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/nextcloud.ini \
    && echo "upload_max_filesize = 10G" >> /usr/local/etc/php/conf.d/nextcloud.ini \
    && echo "post_max_size = 10G" >> /usr/local/etc/php/conf.d/nextcloud.ini \
    && echo "max_execution_time = 3600" >> /usr/local/etc/php/conf.d/nextcloud.ini \
    && echo "max_input_time = 3600" >> /usr/local/etc/php/conf.d/nextcloud.ini

# Configurar Apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && a2enmod rewrite \
    && a2enmod headers \
    && a2enmod env \
    && a2enmod dir \
    && a2enmod mime

# Script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"] 