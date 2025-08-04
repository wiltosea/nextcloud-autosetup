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
    echo -e "${BLUE}  CONFIGURAÇÃO DE FIREWALL      ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Detectar distribuição Linux
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "Não foi possível detectar a distribuição Linux"
        exit 1
    fi
}

# Configurar UFW (Ubuntu/Debian)
setup_ufw() {
    print_message "Configurando UFW..."
    
    # Verificar se UFW está instalado
    if ! command -v ufw &> /dev/null; then
        print_message "Instalando UFW..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y ufw
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y ufw
        else
            print_error "Gerenciador de pacotes não suportado"
            exit 1
        fi
    fi
    
    # Resetar configurações
    sudo ufw --force reset
    
    # Configurar regras padrão
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Permitir SSH (porta 22)
    sudo ufw allow 22/tcp
    
    # Permitir HTTP e HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Permitir WebDAV (porta 80/443 já estão abertas)
    
    # Habilitar firewall
    sudo ufw --force enable
    
    print_message "UFW configurado com sucesso!"
}

# Configurar firewalld (CentOS/RHEL/Fedora)
setup_firewalld() {
    print_message "Configurando firewalld..."
    
    # Verificar se firewalld está instalado
    if ! command -v firewall-cmd &> /dev/null; then
        print_message "Instalando firewalld..."
        sudo dnf install -y firewalld || sudo yum install -y firewalld
    fi
    
    # Iniciar e habilitar firewalld
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
    
    # Configurar zona padrão
    sudo firewall-cmd --set-default-zone=public
    
    # Permitir SSH
    sudo firewall-cmd --permanent --add-service=ssh
    
    # Permitir HTTP e HTTPS
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    
    # Recarregar configurações
    sudo firewall-cmd --reload
    
    print_message "firewalld configurado com sucesso!"
}

# Configurar iptables (genérico)
setup_iptables() {
    print_message "Configurando iptables..."
    
    # Limpar regras existentes
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    sudo iptables -t mangle -F
    sudo iptables -t mangle -X
    
    # Configurar políticas padrão
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT ACCEPT
    
    # Permitir loopback
    sudo iptables -A INPUT -i lo -j ACCEPT
    
    # Permitir conexões estabelecidas
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Permitir SSH
    sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Permitir HTTP
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    
    # Permitir HTTPS
    sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # Salvar regras (Ubuntu/Debian)
    if command -v iptables-save &> /dev/null; then
        sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
        sudo sh -c "iptables-save > /etc/iptables/rules.v4"
    fi
    
    print_message "iptables configurado com sucesso!"
}

# Verificar configuração
verify_firewall() {
    print_message "Verificando configuração do firewall..."
    
    if command -v ufw &> /dev/null; then
        print_message "UFW Status:"
        sudo ufw status verbose
    elif command -v firewall-cmd &> /dev/null; then
        print_message "firewalld Status:"
        sudo firewall-cmd --list-all
    else
        print_message "iptables Status:"
        sudo iptables -L -n -v
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
    
    # Detectar distribuição
    detect_distro
    print_message "Distribuição detectada: $OS $VER"
    
    # Escolher método de firewall
    echo "Escolha o método de firewall:"
    echo "1) UFW (Ubuntu/Debian - recomendado)"
    echo "2) firewalld (CentOS/RHEL/Fedora)"
    echo "3) iptables (genérico)"
    read -p "Opção: " firewall_option
    
    case $firewall_option in
        1) setup_ufw ;;
        2) setup_firewalld ;;
        3) setup_iptables ;;
        *)
            print_error "Opção inválida!"
            exit 1
            ;;
    esac
    
    # Verificar configuração
    verify_firewall
    
    print_message "=========================================="
    print_message "FIREWALL CONFIGURADO COM SUCESSO!"
    print_message "=========================================="
    print_message "Portas abertas:"
    print_message "  - 22 (SSH)"
    print_message "  - 80 (HTTP)"
    print_message "  - 443 (HTTPS)"
    print_message ""
    print_warning "IMPORTANTE: Certifique-se de que o SSH está funcionando antes de sair!"
    print_message "Teste: ssh usuario@seu-servidor"
}

# Executar função principal
main "$@" 