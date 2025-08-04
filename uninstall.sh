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
    echo -e "${BLUE}  DESINSTALADOR NEXTCLOUD      ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Parar e remover containers
remove_containers() {
    print_message "Parando e removendo containers..."
    docker compose down -v
    docker compose rm -f
}

# Remover volumes
remove_volumes() {
    print_message "Removendo volumes Docker..."
    docker volume rm nextcloud_db nextcloud_redis nextcloud_nextcloud 2>/dev/null || true
}

# Remover imagens
remove_images() {
    print_message "Removendo imagens Docker..."
    docker rmi nextcloud_netcloud_app 2>/dev/null || true
    docker rmi nginx:alpine 2>/dev/null || true
    docker rmi mariadb:10.6 2>/dev/null || true
    docker rmi redis:7-alpine 2>/dev/null || true
}

# Remover diretórios
remove_directories() {
    print_message "Removendo diretórios..."
    
    # Perguntar se deve manter backups
    read -p "Deseja manter os backups? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm -rf backups/
        print_message "Backups removidos."
    else
        print_message "Backups mantidos."
    fi
    
    # Perguntar se deve manter dados
    read -p "Deseja manter os dados do Nextcloud? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm -rf data/ config/ apps/ themes/
        print_message "Dados do Nextcloud removidos."
    else
        print_message "Dados do Nextcloud mantidos."
    fi
    
    # Remover diretórios de configuração
    rm -rf ssl/
}

# Remover arquivos de configuração
remove_config_files() {
    print_message "Removendo arquivos de configuração..."
    
    # Perguntar se deve manter arquivos de configuração
    read -p "Deseja manter os arquivos de configuração? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm -f .env docker-compose.yml Dockerfile nginx.conf
        rm -f docker-entrypoint.sh install.sh backup.sh restore.sh manage.sh
        rm -f setup-firewall.sh setup-fedora.sh uninstall.sh env.example
        print_message "Arquivos de configuração removidos."
    else
        print_message "Arquivos de configuração mantidos."
    fi
}

# Limpar Docker (opcional)
cleanup_docker() {
    read -p "Deseja limpar imagens e containers não utilizados? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_message "Limpando Docker..."
        docker system prune -f
        docker volume prune -f
        print_message "Docker limpo!"
    fi
}

# Função principal
main() {
    print_header
    
    print_warning "ATENÇÃO: Esta operação irá remover completamente o Nextcloud!"
    print_warning "Todos os dados serão perdidos, a menos que você escolha mantê-los."
    echo ""
    
    read -p "Tem certeza que deseja continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message "Desinstalação cancelada."
        exit 0
    fi
    
    # Verificar se o Docker está rodando
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker não está rodando!"
        exit 1
    fi
    
    # Executar desinstalação
    remove_containers
    remove_volumes
    remove_images
    remove_directories
    remove_config_files
    cleanup_docker
    
    print_message "=========================================="
    print_message "DESINSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    print_message "=========================================="
    print_message "O Nextcloud foi completamente removido do sistema."
    print_message ""
    print_message "Para reinstalar, execute: ./install.sh"
}

# Executar função principal
main "$@" 