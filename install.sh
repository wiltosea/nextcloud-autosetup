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
    echo -e "${BLUE}  INSTALADOR NEXTCLOUD DOCKER  ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Verificar se o Docker está instalado
check_docker() {
    print_message "Verificando se o Docker está instalado..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker não está instalado. Instalando..."
        
        # Detectar distribuição
        if command -v dnf &> /dev/null; then
            # Fedora/CentOS/RHEL
            sudo dnf install -y docker docker-compose-plugin
            sudo systemctl enable docker
            sudo systemctl start docker
        elif command -v apt-get &> /dev/null; then
            # Ubuntu/Debian
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            rm get-docker.sh
        else
            print_error "Distribuição não suportada. Instale o Docker manualmente."
            exit 1
        fi
        
        sudo usermod -aG docker $USER
        print_warning "Docker instalado. Faça logout e login novamente para aplicar as permissões."
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null; then
        print_error "Docker Compose não está instalado. Instalando..."
        
        if command -v dnf &> /dev/null; then
            # Fedora/CentOS/RHEL
            sudo dnf install -y docker-compose-plugin
        else
            # Fallback para outras distribuições
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
    fi
    
    print_message "Docker e Docker Compose verificados com sucesso!"
}

# Criar arquivo .env se não existir
setup_env() {
    if [ ! -f .env ]; then
        print_message "Criando arquivo .env..."
        cp env.example .env
        print_warning "Arquivo .env criado. Edite as senhas antes de continuar!"
        print_message "Execute: nano .env"
        read -p "Pressione Enter após editar o arquivo .env..."
    else
        print_message "Arquivo .env já existe."
    fi
}

# Criar diretórios necessários
create_directories() {
    print_message "Criando diretórios necessários..."
    mkdir -p apps config data themes ssl
    chmod 755 apps config data themes ssl
    print_message "Diretórios criados com sucesso!"
}

# Configurar SSL (opcional)
setup_ssl() {
    print_message "Configurando SSL..."
    if [ ! -f ssl/cert.pem ] || [ ! -f ssl/key.pem ]; then
        print_warning "Certificados SSL não encontrados. Gerando certificados auto-assinados..."
        mkdir -p ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/key.pem \
            -out ssl/cert.pem \
            -subj "/C=BR/ST=SP/L=Sao Paulo/O=Nextcloud/CN=localhost"
        chmod 600 ssl/key.pem
        chmod 644 ssl/cert.pem
        print_message "Certificados SSL auto-assinados gerados!"
    else
        print_message "Certificados SSL já existem."
    fi
}

# Construir e iniciar containers
start_containers() {
    print_message "Construindo e iniciando containers..."
    docker compose up -d --build
    
    if [ $? -eq 0 ]; then
        print_message "Containers iniciados com sucesso!"
    else
        print_error "Erro ao iniciar containers!"
        exit 1
    fi
}

# Aguardar inicialização
wait_for_startup() {
    print_message "Aguardando inicialização do Nextcloud..."
    print_message "Isso pode levar alguns minutos..."
    
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

# Mostrar informações finais
show_info() {
    print_message "=========================================="
    print_message "INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    print_message "=========================================="
    print_message "URL: http://localhost"
    print_message "Admin User: $(grep NEXTCLOUD_ADMIN_USER .env | cut -d'=' -f2)"
    print_message "Admin Password: $(grep NEXTCLOUD_ADMIN_PASSWORD .env | cut -d'=' -f2)"
    print_message ""
    print_message "Comandos úteis:"
    print_message "  Status: docker compose ps"
    print_message "  Logs: docker compose logs -f"
    print_message "  Parar: docker compose down"
    print_message "  Reiniciar: docker compose restart"
    print_message "  Backup: ./backup.sh"
    print_message "  Restore: ./restore.sh"
    print_message ""
    print_warning "IMPORTANTE: Altere as senhas padrão no arquivo .env!"
}

# Função principal
main() {
    print_header
    
    check_docker
    setup_env
    create_directories
    setup_ssl
    start_containers
    wait_for_startup
    show_info
}

# Executar função principal
main "$@" 