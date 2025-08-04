#!/bin/bash
set -e

# Aguardar o banco de dados estar pronto
echo "Aguardando banco de dados..."
while ! nc -z db 3306; do
  sleep 1
done
echo "Banco de dados pronto!"

# Aguardar Redis estar pronto
echo "Aguardando Redis..."
while ! nc -z redis 6379; do
  sleep 1
done
echo "Redis pronto!"

# Configurar Nextcloud se não estiver configurado
if [ ! -f /var/www/html/config/config.php ]; then
    echo "Configurando Nextcloud..."
    
    # Instalar Nextcloud
    sudo -u www-data php /var/www/html/occ maintenance:install \
        --database="mysql" \
        --database-name="${MYSQL_DATABASE}" \
        --database-user="${MYSQL_USER}" \
        --database-pass="${MYSQL_PASSWORD}" \
        --database-host="db" \
        --admin-user="${NEXTCLOUD_ADMIN_USER}" \
        --admin-pass="${NEXTCLOUD_ADMIN_PASSWORD}" \
        --data-dir="/var/www/html/data"

    # Configurar Redis
    sudo -u www-data php /var/www/html/occ config:system:set redis host --value=redis
    sudo -u www-data php /var/www/html/occ config:system:set redis port --value=6379

    # Configurar domínios confiáveis
    IFS=',' read -ra DOMAINS <<< "$NEXTCLOUD_TRUSTED_DOMAINS"
    for domain in "${DOMAINS[@]}"; do
        sudo -u www-data php /var/www/html/occ config:system:set trusted_domains 0 --value="$domain"
    done

    # Configurar HTTPS
    sudo -u www-data php /var/www/html/occ config:system:set overwrite.cli.url --value="https://${NEXTCLOUD_TRUSTED_DOMAINS}"

    # Configurar cache
    sudo -u www-data php /var/www/html/occ config:system:set memcache.local --value="\OC\Memcache\Redis"
    sudo -u www-data php /var/www/html/occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"

    # Configurar previews
    sudo -u www-data php /var/www/html/occ config:system:set preview_max_memory --value=512

    echo "Nextcloud configurado com sucesso!"
else
    echo "Nextcloud já está configurado."
fi

# Executar comando original
exec "$@" 