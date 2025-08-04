#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  BACKUP NEXTCLOUD DOCKER      ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Configurações
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="nextcloud_backup_$DATE"

# Criar diretório de backup
create_backup_dir() {
    print_message "Criando diretório de backup..."
    mkdir -p "$BACKUP_DIR"
}

# Parar containers
stop_containers() {
    print_message "Parando containers..."
    docker compose down
}

# Backup do banco de dados
backup_database() {
    print_message "Fazendo backup do banco de dados..."
    
    # Carregar variáveis de ambiente
    source .env
    
    # Backup do MariaDB
    docker run --rm \
        --network nextcloud_nextcloud_network \
        -v "$(pwd)/$BACKUP_DIR:/backup" \
        mariadb:10.6 \
        mysqldump \
        -h db \
        -u "$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        "$MYSQL_DATABASE" > "$BACKUP_DIR/${BACKUP_NAME}_database.sql"
    
    if [ $? -eq 0 ]; then
        print_message "Backup do banco de dados concluído!"
    else
        print_error "Erro no backup do banco de dados!"
        return 1
    fi
}

# Backup dos dados do Nextcloud
backup_data() {
    print_message "Fazendo backup dos dados..."
    
    # Backup dos diretórios importantes
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_data.tar.gz" \
        --exclude='./backups' \
        --exclude='./.git' \
        --exclude='./node_modules' \
        --exclude='./data/*/cache' \
        --exclude='./data/*/tmp' \
        --exclude='./data/*/thumbnails' \
        ./data ./config ./apps ./themes .env docker-compose.yml
    
    if [ $? -eq 0 ]; then
        print_message "Backup dos dados concluído!"
    else
        print_error "Erro no backup dos dados!"
        return 1
    fi
}

# Backup dos volumes Docker
backup_volumes() {
    print_message "Fazendo backup dos volumes Docker..."
    
    # Listar volumes
    VOLUMES=$(docker volume ls --format "{{.Name}}" | grep nextcloud)
    
    for volume in $VOLUMES; do
        print_message "Backup do volume: $volume"
        docker run --rm \
            -v "$volume:/data" \
            -v "$(pwd)/$BACKUP_DIR:/backup" \
            alpine tar czf "/backup/${BACKUP_NAME}_${volume}.tar.gz" -C /data .
    done
    
    print_message "Backup dos volumes concluído!"
}

# Criar arquivo de metadados
create_metadata() {
    print_message "Criando arquivo de metadados..."
    
    cat > "$BACKUP_DIR/${BACKUP_NAME}_metadata.txt" << EOF
Backup Nextcloud Docker
Data: $(date)
    Versão Nextcloud: $(docker compose exec app php -r "include '/var/www/html/config/config.php'; echo \$CONFIG['version'];")
    Docker Compose: $(docker compose version --short)
Sistema: $(uname -a)
Tamanho do backup: $(du -sh "$BACKUP_DIR/${BACKUP_NAME}_*" | awk '{sum+=$1} END {print sum " bytes"}')

Arquivos incluídos:
- ${BACKUP_NAME}_database.sql (Banco de dados)
- ${BACKUP_NAME}_data.tar.gz (Dados do Nextcloud)
- ${BACKUP_NAME}_nextcloud_db.tar.gz (Volume do banco)
- ${BACKUP_NAME}_nextcloud_redis.tar.gz (Volume do Redis)
- ${BACKUP_NAME}_nextcloud_nextcloud.tar.gz (Volume do Nextcloud)

Para restaurar:
1. ./restore.sh ${BACKUP_NAME}
EOF
    
    print_message "Arquivo de metadados criado!"
}

# Compactar backup completo
compress_backup() {
    print_message "Compactando backup completo..."
    
    cd "$BACKUP_DIR"
    tar -czf "${BACKUP_NAME}_complete.tar.gz" \
        "${BACKUP_NAME}_database.sql" \
        "${BACKUP_NAME}_data.tar.gz" \
        "${BACKUP_NAME}_nextcloud_db.tar.gz" \
        "${BACKUP_NAME}_nextcloud_redis.tar.gz" \
        "${BACKUP_NAME}_nextcloud_nextcloud.tar.gz" \
        "${BACKUP_NAME}_metadata.txt"
    
    # Remover arquivos individuais
    rm "${BACKUP_NAME}_database.sql" \
       "${BACKUP_NAME}_data.tar.gz" \
       "${BACKUP_NAME}_nextcloud_db.tar.gz" \
       "${BACKUP_NAME}_nextcloud_redis.tar.gz" \
       "${BACKUP_NAME}_nextcloud_nextcloud.tar.gz" \
       "${BACKUP_NAME}_metadata.txt"
    
    cd ..
    
    print_message "Backup compactado: $BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz"
}

    # Reiniciar containers
    restart_containers() {
        print_message "Reiniciando containers..."
        docker compose up -d
    }

# Limpar backups antigos
cleanup_old_backups() {
    print_message "Limpando backups antigos (mantendo os últimos 5)..."
    
    cd "$BACKUP_DIR"
    ls -t *.tar.gz | tail -n +6 | xargs -r rm
    cd ..
    
    print_message "Limpeza concluída!"
}

# Função principal
main() {
    print_header
    
    # Verificar se o Docker está rodando
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker não está rodando!"
        exit 1
    fi
    
    create_backup_dir
    stop_containers
    
    # Fazer backups
    if backup_database && backup_data && backup_volumes; then
        create_metadata
        compress_backup
        cleanup_old_backups
        
        print_message "=========================================="
        print_message "BACKUP CONCLUÍDO COM SUCESSO!"
        print_message "=========================================="
        print_message "Arquivo: $BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz"
        print_message "Tamanho: $(du -h "$BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz" | cut -f1)"
        print_message ""
    else
        print_error "Erro durante o backup!"
        restart_containers
        exit 1
    fi
    
    restart_containers
    print_message "Containers reiniciados!"
}

# Executar função principal
main "$@" 