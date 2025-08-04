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
    echo -e "${BLUE}  GERENCIADOR NEXTCLOUD DOCKER  ${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Função para mostrar menu
show_menu() {
    echo ""
    echo "Escolha uma opção:"
    echo "1) Status dos containers"
    echo "2) Iniciar Nextcloud"
    echo "3) Parar Nextcloud"
    echo "4) Reiniciar Nextcloud"
    echo "5) Ver logs"
    echo "6) Backup"
    echo "7) Restaurar backup"
    echo "8) Atualizar Nextcloud"
    echo "9) Configurar SSL"
    echo "10) Limpar cache"
    echo "11) Verificar integridade"
    echo "12) Configurar domínio"
    echo "13) Instalar apps"
    echo "14) Sair"
    echo ""
}

# Status dos containers
status_containers() {
    print_message "Status dos containers:"
    docker compose ps
}

# Iniciar Nextcloud
start_nextcloud() {
    print_message "Iniciando Nextcloud..."
    docker compose up -d
    print_message "Nextcloud iniciado!"
}

# Parar Nextcloud
stop_nextcloud() {
    print_message "Parando Nextcloud..."
    docker compose down
    print_message "Nextcloud parado!"
}

# Reiniciar Nextcloud
restart_nextcloud() {
    print_message "Reiniciando Nextcloud..."
    docker compose restart
    print_message "Nextcloud reiniciado!"
}

# Ver logs
show_logs() {
    echo "Escolha o container para ver logs:"
    echo "1) Nextcloud (app)"
    echo "2) Banco de dados (db)"
    echo "3) Redis"
    echo "4) Nginx"
    echo "5) Todos"
    read -p "Opção: " log_option
    
    case $log_option in
        1) docker compose logs -f app ;;
        2) docker compose logs -f db ;;
        3) docker compose logs -f redis ;;
        4) docker compose logs -f nginx ;;
        5) docker compose logs -f ;;
        *) print_error "Opção inválida!" ;;
    esac
}

# Backup
do_backup() {
    print_message "Iniciando backup..."
    ./backup.sh
}

# Restaurar backup
do_restore() {
    print_message "Backups disponíveis:"
    ls -1 ./backups/*.tar.gz 2>/dev/null | sed 's/.*\///' | sed 's/_complete.tar.gz//' || print_message "Nenhum backup encontrado."
    
    if [ -d "./backups" ] && [ "$(ls -A ./backups/*.tar.gz 2>/dev/null)" ]; then
        read -p "Digite o nome do backup para restaurar: " backup_name
        ./restore.sh "$backup_name"
    else
        print_warning "Nenhum backup encontrado!"
    fi
}

# Atualizar Nextcloud
update_nextcloud() {
    print_warning "ATENÇÃO: Faça backup antes de atualizar!"
    read -p "Continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    print_message "Atualizando Nextcloud..."
    
    # Parar containers
    docker compose down
    
    # Reconstruir imagem
    docker compose build --no-cache app
    
    # Iniciar containers
    docker compose up -d
    
    # Executar atualização
    docker compose exec app php /var/www/html/occ upgrade
    
    print_message "Atualização concluída!"
}

# Configurar SSL
setup_ssl() {
    echo "Opções de SSL:"
    echo "1) Gerar certificado auto-assinado"
    echo "2) Usar certificado Let's Encrypt"
    echo "3) Usar certificado personalizado"
    read -p "Opção: " ssl_option
    
    case $ssl_option in
        1)
            print_message "Gerando certificado auto-assinado..."
            mkdir -p ssl
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout ssl/key.pem \
                -out ssl/cert.pem \
                -subj "/C=BR/ST=SP/L=Sao Paulo/O=Nextcloud/CN=localhost"
            chmod 600 ssl/key.pem
            chmod 644 ssl/cert.pem
            print_message "Certificado gerado!"
            ;;
        2)
            print_warning "Para Let's Encrypt, você precisa de um domínio válido."
            read -p "Digite seu domínio: " domain
            print_message "Instalando certbot..."
            
            if command -v dnf &> /dev/null; then
                # Fedora/CentOS/RHEL
                sudo dnf install -y certbot
            elif command -v apt-get &> /dev/null; then
                # Ubuntu/Debian
                sudo apt-get update && sudo apt-get install -y certbot
            else
                print_error "Gerenciador de pacotes não suportado"
                return 1
            fi
            
            sudo certbot certonly --standalone -d "$domain"
            sudo cp /etc/letsencrypt/live/"$domain"/fullchain.pem ssl/cert.pem
            sudo cp /etc/letsencrypt/live/"$domain"/privkey.pem ssl/key.pem
            sudo chown $USER:$USER ssl/cert.pem ssl/key.pem
            chmod 600 ssl/key.pem
            chmod 644 ssl/cert.pem
            print_message "Certificado Let's Encrypt configurado!"
            ;;
        3)
            print_message "Coloque seus certificados em:"
            print_message "  ssl/cert.pem (certificado)"
            print_message "  ssl/key.pem (chave privada)"
            read -p "Pressione Enter após colocar os arquivos..."
            ;;
        *)
            print_error "Opção inválida!"
            ;;
    esac
    
    # Reconfigurar Nginx
    print_message "Reiniciando Nginx..."
    docker compose restart nginx
}

# Limpar cache
clear_cache() {
    print_message "Limpando cache..."
    docker compose exec app php /var/www/html/occ files:scan --all
    docker compose exec app php /var/www/html/occ files:cleanup
    docker compose exec app php /var/www/html/occ maintenance:repair
    print_message "Cache limpo!"
}

# Verificar integridade
check_integrity() {
    print_message "Verificando integridade..."
    
    # Verificar containers
    if docker compose ps | grep -q "Up"; then
        print_message "✓ Containers estão rodando"
    else
        print_error "✗ Containers não estão rodando"
    fi
    
    # Verificar Nextcloud
    if curl -s http://localhost > /dev/null 2>&1; then
        print_message "✓ Nextcloud está respondendo"
    else
        print_error "✗ Nextcloud não está respondendo"
    fi
    
    # Verificar banco de dados
    if docker compose exec app php -r "include '/var/www/html/config/config.php'; echo '✓ Banco conectado';" 2>/dev/null; then
        print_message "✓ Banco de dados conectado"
    else
        print_error "✗ Problema com banco de dados"
    fi
    
    # Verificar espaço em disco
    disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        print_message "✓ Espaço em disco OK ($disk_usage%)"
    else
        print_warning "⚠ Pouco espaço em disco ($disk_usage%)"
    fi
}

# Configurar domínio
configure_domain() {
    read -p "Digite o domínio (ex: cloud.exemplo.com): " domain
    
    if [ -n "$domain" ]; then
        # Atualizar .env
        sed -i "s/NEXTCLOUD_TRUSTED_DOMAINS=.*/NEXTCLOUD_TRUSTED_DOMAINS=localhost,127.0.0.1,$domain/" .env
        
        # Configurar Nextcloud
        docker compose exec app php /var/www/html/occ config:system:set trusted_domains 2 --value="$domain"
        docker compose exec app php /var/www/html/occ config:system:set overwrite.cli.url --value="https://$domain"
        
        print_message "Domínio configurado: $domain"
        print_message "Reinicie o Nextcloud para aplicar as mudanças."
    else
        print_error "Domínio inválido!"
    fi
}

# Instalar apps
install_apps() {
    echo "Apps populares disponíveis:"
    echo "1) OnlyOffice (editor de documentos)"
    echo "2) Collabora (editor de documentos)"
    echo "3) Talk (chat/videoconferência)"
    echo "4) Calendar (calendário)"
    echo "5) Contacts (contatos)"
    echo "6) Notes (notas)"
    echo "7) Custom app"
    read -p "Opção: " app_option
    
    case $app_option in
        1)
            print_message "Instalando OnlyOffice..."
            docker compose exec app php /var/www/html/occ app:install onlyoffice
            ;;
        2)
            print_message "Instalando Collabora..."
            docker compose exec app php /var/www/html/occ app:install richdocuments
            ;;
        3)
            print_message "Instalando Talk..."
            docker compose exec app php /var/www/html/occ app:install spreed
            ;;
        4)
            print_message "Instalando Calendar..."
            docker compose exec app php /var/www/html/occ app:install calendar
            ;;
        5)
            print_message "Instalando Contacts..."
            docker compose exec app php /var/www/html/occ app:install contacts
            ;;
        6)
            print_message "Instalando Notes..."
            docker compose exec app php /var/www/html/occ app:install notes
            ;;
        7)
            read -p "Digite o nome do app: " app_name
            docker compose exec app php /var/www/html/occ app:install "$app_name"
            ;;
        *)
            print_error "Opção inválida!"
            ;;
    esac
}

# Função principal
main() {
    print_header
    
    # Verificar se o Docker está rodando
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker não está rodando!"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Digite sua opção: " option
        
        case $option in
            1) status_containers ;;
            2) start_nextcloud ;;
            3) stop_nextcloud ;;
            4) restart_nextcloud ;;
            5) show_logs ;;
            6) do_backup ;;
            7) do_restore ;;
            8) update_nextcloud ;;
            9) setup_ssl ;;
            10) clear_cache ;;
            11) check_integrity ;;
            12) configure_domain ;;
            13) install_apps ;;
            14) 
                print_message "Saindo..."
                exit 0
                ;;
            *)
                print_error "Opção inválida!"
                ;;
        esac
        
        echo ""
        read -p "Pressione Enter para continuar..."
    done
}

# Executar função principal
main "$@" 