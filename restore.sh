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
    echo -e "${BLUE}  RESTAURAÇÃO NEXTCLOUD DOCKER  ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Configurações
BACKUP_DIR="./backups"

# Verificar argumentos
if [ $# -eq 0 ]; then
    print_error "Uso: $0 <nome_do_backup>"
    print_message "Backups disponíveis:"
    ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | sed 's/.*\///' | sed 's/_complete.tar.gz//' || print_message "Nenhum backup encontrado."
    exit 1
fi

BACKUP_NAME="$1"
BACKUP_FILE="$BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz"

# Verificar se o backup existe
check_backup() {
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Backup não encontrado: $BACKUP_FILE"
        print_message "Backups disponíveis:"
        ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | sed 's/.*\///' | sed 's/_complete.tar.gz//' || print_message "Nenhum backup encontrado."
        exit 1
    fi
    
    print_message "Backup encontrado: $BACKUP_FILE"
    print_message "Tamanho: $(du -h "$BACKUP_FILE" | cut -f1)"
}

# Parar containers
stop_containers() {
    print_message "Parando containers..."
    docker-compose down
}

# Limpar dados existentes
cleanup_existing() {
    print_warning "Limpando dados existentes..."
    
    # Remover volumes
    docker volume rm nextcloud_db nextcloud_redis nextcloud_nextcloud 2>/dev/null || true
    
    # Limpar diretórios
    rm -rf data config apps themes
    mkdir -p data config apps themes
}

# Extrair backup
extract_backup() {
    print_message "Extraindo backup..."
    
    cd "$BACKUP_DIR"
    tar -xzf "${BACKUP_NAME}_complete.tar.gz"
    cd ..
    
    print_message "Backup extraído!"
}

# Restaurar banco de dados
restore_database() {
    print_message "Restaurando banco de dados..."
    
    # Carregar variáveis de ambiente
    source .env
    
    # Aguardar banco estar pronto
    docker compose up -d db
    sleep 10
    
    # Restaurar banco
    docker run --rm \
        --network nextcloud_nextcloud_network \
        -v "$(pwd)/$BACKUP_DIR:/backup" \
        mariadb:10.6 \
        mysql \
        -h db \
        -u "$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        "$MYSQL_DATABASE" < "$BACKUP_DIR/${BACKUP_NAME}_database.sql"
    
    if [ $? -eq 0 ]; then
        print_message "Banco de dados restaurado!"
    else
        print_error "Erro na restauração do banco de dados!"
        return 1
    fi
}

# Restaurar dados
restore_data() {
    print_message "Restaurando dados..."
    
    tar -xzf "$BACKUP_DIR/${BACKUP_NAME}_data.tar.gz"
    
    if [ $? -eq 0 ]; then
        print_message "Dados restaurados!"
    else
        print_error "Erro na restauração dos dados!"
        return 1
    fi
}

# Restaurar volumes
restore_volumes() {
    print_message "Restaurando volumes..."
    
    # Restaurar volume do banco
    if [ -f "$BACKUP_DIR/${BACKUP_NAME}_nextcloud_db.tar.gz" ]; then
        docker volume create nextcloud_db
        docker run --rm \
            -v nextcloud_db:/data \
            -v "$(pwd)/$BACKUP_DIR:/backup" \
            alpine sh -c "cd /data && tar xzf /backup/${BACKUP_NAME}_nextcloud_db.tar.gz"
    fi
    
    # Restaurar volume do Redis
    if [ -f "$BACKUP_DIR/${BACKUP_NAME}_nextcloud_redis.tar.gz" ]; then
        docker volume create nextcloud_redis
        docker run --rm \
            -v nextcloud_redis:/data \
            -v "$(pwd)/$BACKUP_DIR:/backup" \
            alpine sh -c "cd /data && tar xzf /backup/${BACKUP_NAME}_nextcloud_redis.tar.gz"
    fi
    
    # Restaurar volume do Nextcloud
    if [ -f "$BACKUP_DIR/${BACKUP_NAME}_nextcloud_nextcloud.tar.gz" ]; then
        docker volume create nextcloud_nextcloud
        docker run --rm \
            -v nextcloud_nextcloud:/data \
            -v "$(pwd)/$BACKUP_DIR:/backup" \
            alpine sh -c "cd /data && tar xzf /backup/${BACKUP_NAME}_nextcloud_nextcloud.tar.gz"
    fi
    
    print_message "Volumes restaurados!"
}

# Limpar arquivos temporários
cleanup_temp() {
    print_message "Limpando arquivos temporários..."
    
    cd "$BACKUP_DIR"
    rm -f "${BACKUP_NAME}_database.sql" \
          "${BACKUP_NAME}_data.tar.gz" \
          "${BACKUP_NAME}_nextcloud_db.tar.gz" \
          "${BACKUP_NAME}_nextcloud_redis.tar.gz" \
          "${BACKUP_NAME}_nextcloud_nextcloud.tar.gz" \
          "${BACKUP_NAME}_metadata.txt"
    cd ..
}

# Iniciar containers
start_containers() {
    print_message "Iniciando containers..."
    docker compose up -d
}

# Aguardar inicialização
wait_for_startup() {
    print_message "Aguardando inicialização..."
    
    # Aguardar até 5 minutos
    for i in {1..60}; do
        if curl -s http://localhost > /dev/null 2>&1; then
            print_message "Nextcloud está online!"
            break
        fi
        echo -n "."
        sleep 5
    done
    
    if [ $i -eq 60 ]; then
        print_warning "Timeout aguardando inicialização. Verifique os logs:"
        print_message "docker compose logs -f"
    fi
}

# Verificar integridade
verify_restore() {
    print_message "Verificando integridade da restauração..."
    
    # Verificar se o Nextcloud está respondendo
    if curl -s http://localhost > /dev/null 2>&1; then
        print_message "✓ Nextcloud está respondendo"
    else
        print_error "✗ Nextcloud não está respondendo"
        return 1
    fi
    
    # Verificar se o banco está conectado
    if docker compose exec app php -r "include '/var/www/html/config/config.php'; echo '✓ Banco conectado';" 2>/dev/null; then
        print_message "✓ Banco de dados conectado"
    else
        print_error "✗ Problema com banco de dados"
        return 1
    fi
    
    print_message "Verificação concluída!"
}

# Função principal
main() {
    print_header
    
    # Verificar se o Docker está rodando
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker não está rodando!"
        exit 1
    fi
    
    check_backup
    
    print_warning "ATENÇÃO: Esta operação irá sobrescrever todos os dados existentes!"
    read -p "Tem certeza que deseja continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "Restauração cancelada."
        exit 0
    fi
    
    stop_containers
    cleanup_existing
    extract_backup
    
    # Restaurar dados
    if restore_database && restore_data && restore_volumes; then
        cleanup_temp
        start_containers
        wait_for_startup
        verify_restore
        
        print_message "=========================================="
        print_message "RESTAURAÇÃO CONCLUÍDA COM SUCESSO!"
        print_message "=========================================="
        print_message "URL: http://localhost"
        print_message "Verifique se tudo está funcionando corretamente."
        print_message ""
    else
        print_error "Erro durante a restauração!"
        print_message "Tente iniciar manualmente: docker compose up -d"
        exit 1
    fi
}

# Executar função principal
main "$@" 