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
    echo -e "${BLUE}  CONFIGURAÇÃO FEDORA ESPECÍFICA ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Verificar se é Fedora
check_fedora() {
    if [ ! -f /etc/fedora-release ]; then
        print_error "Este script é específico para Fedora!"
        exit 1
    fi
    
    print_message "Fedora detectado!"
}

# Instalar dependências do Fedora
install_dependencies() {
    print_message "Instalando dependências do Fedora..."
    
    # Atualizar sistema
    sudo dnf update -y
    
    # Instalar dependências essenciais
    sudo dnf install -y \
        docker \
        docker-compose-plugin \
        firewalld \
        policycoreutils-python-utils \
        setools-console \
        curl \
        wget \
        git \
        nano \
        vim
    
    # Habilitar e iniciar serviços
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo systemctl enable firewalld
    sudo systemctl start firewalld
    
    print_message "Dependências instaladas!"
}

# Configurar SELinux para Docker
configure_selinux() {
    print_message "Configurando SELinux para Docker..."
    
    # Verificar se SELinux está ativo
    if command -v sestatus &> /dev/null; then
        SELINUX_STATUS=$(sestatus | grep "SELinux status" | awk '{print $3}')
        if [ "$SELINUX_STATUS" = "enabled" ]; then
            print_message "SELinux está ativo. Configurando..."
            
            # Permitir que o Docker acesse portas não padrão
            sudo semanage port -a -t http_port_t -p tcp 8080 2>/dev/null || true
            sudo semanage port -a -t http_port_t -p tcp 8443 2>/dev/null || true
            
            # Configurar contextos para volumes Docker
            sudo setsebool -P container_manage_cgroup 1
            sudo setsebool -P container_use_cgroup 1
            
            print_message "SELinux configurado!"
        else
            print_warning "SELinux está desabilitado."
        fi
    else
        print_warning "SELinux não está instalado."
    fi
}

# Configurar firewall do Fedora
configure_firewall() {
    print_message "Configurando firewall do Fedora..."
    
    # Configurar zona padrão
    sudo firewall-cmd --set-default-zone=public
    
    # Permitir serviços essenciais
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    
    # Permitir portas específicas se necessário
    sudo firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
    sudo firewall-cmd --permanent --add-port=8443/tcp 2>/dev/null || true
    
    # Recarregar configurações
    sudo firewall-cmd --reload
    
    print_message "Firewall configurado!"
}

# Configurar usuário para Docker
configure_user() {
    print_message "Configurando usuário para Docker..."
    
    # Adicionar usuário ao grupo docker
    sudo usermod -aG docker $USER
    
    # Configurar permissões para diretórios do projeto
    sudo chown -R $USER:$USER .
    chmod 755 .
    
    print_message "Usuário configurado!"
}

# Configurar limites do sistema
configure_limits() {
    print_message "Configurando limites do sistema..."
    
    # Verificar se já existe configuração
    if ! grep -q "docker" /etc/security/limits.conf; then
        echo "# Docker limits" | sudo tee -a /etc/security/limits.conf
        echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
        echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
        echo "* soft nproc 32768" | sudo tee -a /etc/security/limits.conf
        echo "* hard nproc 32768" | sudo tee -a /etc/security/limits.conf
    fi
    
    print_message "Limites configurados!"
}

# Configurar swap (se necessário)
configure_swap() {
    print_message "Verificando configuração de swap..."
    
    # Verificar se há swap suficiente
    SWAP_SIZE=$(free -g | grep Swap | awk '{print $2}')
    if [ "$SWAP_SIZE" -lt 2 ]; then
        print_warning "Swap muito pequeno. Recomendado: pelo menos 2GB"
        print_message "Para adicionar swap:"
        print_message "  sudo fallocate -l 2G /swapfile"
        print_message "  sudo chmod 600 /swapfile"
        print_message "  sudo mkswap /swapfile"
        print_message "  sudo swapon /swapfile"
        print_message "  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
    else
        print_message "Swap adequado: ${SWAP_SIZE}GB"
    fi
}

# Verificar configuração
verify_configuration() {
    print_message "Verificando configuração..."
    
    # Verificar Docker
    if docker info > /dev/null 2>&1; then
        print_message "✓ Docker funcionando"
    else
        print_error "✗ Docker não está funcionando"
    fi
    
    # Verificar Docker Compose
    if docker compose version > /dev/null 2>&1; then
        print_message "✓ Docker Compose funcionando"
    else
        print_error "✗ Docker Compose não está funcionando"
    fi
    
    # Verificar firewall
    if sudo firewall-cmd --state > /dev/null 2>&1; then
        print_message "✓ Firewall ativo"
    else
        print_error "✗ Firewall não está ativo"
    fi
    
    # Verificar SELinux
    if command -v sestatus &> /dev/null; then
        SELINUX_STATUS=$(sestatus | grep "SELinux status" | awk '{print $3}')
        print_message "✓ SELinux: $SELINUX_STATUS"
    else
        print_warning "⚠ SELinux não instalado"
    fi
}

# Função principal
main() {
    print_header
    
    # Verificar se é root
    if [ "$EUID" -eq 0 ]; then
        print_error "Não execute este script como root!"
        print_message "Execute como usuário normal com sudo."
        exit 1
    fi
    
    check_fedora
    install_dependencies
    configure_selinux
    configure_firewall
    configure_user
    configure_limits
    configure_swap
    verify_configuration
    
    print_message "=========================================="
    print_message "CONFIGURAÇÃO FEDORA CONCLUÍDA!"
    print_message "=========================================="
    print_message ""
    print_warning "IMPORTANTE: Faça logout e login novamente para aplicar as permissões do Docker!"
    print_message ""
    print_message "Próximos passos:"
    print_message "1. Logout e login novamente"
    print_message "2. Execute: ./install.sh"
    print_message "3. Ou execute: ./manage.sh"
}

# Executar função principal
main "$@" 