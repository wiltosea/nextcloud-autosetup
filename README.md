# Nextcloud Docker - Instalação Completa

Este projeto fornece uma instalação completa e automatizada do Nextcloud usando Docker, com scripts de gerenciamento, backup e restauração.

## 🚀 Características

- **Nextcloud 27** com Apache
- **MariaDB 10.6** como banco de dados
- **Redis 7** para cache
- **Nginx** como proxy reverso
- **SSL/TLS** configurável
- **Scripts automatizados** para instalação, backup e gerenciamento
- **Otimizações** de performance
- **Suporte a apps** populares

## 📋 Pré-requisitos

- Linux (Ubuntu, Debian, CentOS, Fedora, etc.)
- Docker e Docker Compose
- Pelo menos 2GB de RAM
- 10GB de espaço em disco
- Acesso root/sudo

### Requisitos Específicos por Distribuição

#### Fedora/CentOS/RHEL
- SELinux configurado (opcional, mas recomendado)
- firewalld ativo
- Docker e docker-compose-plugin instalados

#### Ubuntu/Debian
- UFW ou iptables configurado
- Docker e Docker Compose instalados

## 🛠️ Instalação Rápida

### Para Fedora/CentOS/RHEL
```bash
git clone <seu-repositorio>
cd netcloud
chmod +x *.sh
./setup-fedora.sh  # Configuração específica do Fedora
./install.sh
```

### Para Ubuntu/Debian
```bash
git clone <seu-repositorio>
cd netcloud
chmod +x *.sh
./install.sh
```

O script irá:

- Verificar e instalar Docker se necessário
- Criar arquivo `.env` com configurações
- Gerar certificados SSL auto-assinados
- Construir e iniciar todos os containers
- Configurar o Nextcloud automaticamente

### 3. Acesse o Nextcloud

- URL: `http://localhost` ou `https://localhost`
- Usuário admin: `admin`
- Senha: definida no arquivo `.env`

## 📁 Estrutura do Projeto

```
netcloud/
├── docker-compose.yml      # Configuração principal do Docker
├── Dockerfile              # Imagem personalizada do Nextcloud
├── docker-entrypoint.sh    # Script de inicialização
├── nginx.conf              # Configuração do Nginx
├── env.example             # Exemplo de variáveis de ambiente
├── install.sh              # Script de instalação
├── manage.sh               # Gerenciador interativo
├── backup.sh               # Script de backup
├── restore.sh              # Script de restauração
├── setup-firewall.sh       # Configuração de firewall
├── setup-fedora.sh         # Configuração específica do Fedora
├── uninstall.sh            # Desinstalador
├── README.md               # Esta documentação
├── apps/                   # Apps personalizados
├── config/                 # Configurações do Nextcloud
├── data/                   # Dados dos usuários
├── themes/                 # Temas personalizados
├── ssl/                    # Certificados SSL
└── backups/                # Backups automáticos
```

## 🔧 Configuração

### Variáveis de Ambiente

Edite o arquivo `.env` para personalizar:

```bash
# Configurações do Banco de Dados
MYSQL_ROOT_PASSWORD=sua_senha_root
MYSQL_PASSWORD=sua_senha_nextcloud
MYSQL_DATABASE=nextcloud
MYSQL_USER=nextcloud

# Configurações do Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=sua_senha_admin
NEXTCLOUD_TRUSTED_DOMAINS=localhost,127.0.0.1,seu-dominio.com

# Configurações de Timezone
TZ=America/Sao_Paulo
```

### Configurar Domínio

Para usar um domínio personalizado:

1. Execute o gerenciador: `./manage.sh`
2. Escolha opção 12: "Configurar domínio"
3. Digite seu domínio (ex: `cloud.exemplo.com`)
4. Configure DNS para apontar para seu servidor

### Configurar SSL

O projeto suporta três tipos de SSL:

1. **Auto-assinado** (padrão)
2. **Let's Encrypt** (gratuito)
3. **Certificado personalizado**

Execute: `./manage.sh` → Opção 9

### Configuração Específica do Fedora

Para usuários do Fedora, execute o script específico antes da instalação:

```bash
./setup-fedora.sh
```

Este script configura:
- SELinux para Docker
- firewalld adequadamente
- Limites do sistema
- Permissões de usuário
- Dependências específicas do Fedora

## 🎛️ Gerenciamento

### Script de Gerenciamento Interativo

```bash
./manage.sh
```

Opções disponíveis:
- Status dos containers
- Iniciar/Parar/Reiniciar
- Ver logs
- Backup e restauração
- Atualização
- Configuração SSL
- Limpeza de cache
- Verificação de integridade
- Configuração de domínio
- Instalação de apps

### Comandos Manuais

```bash
# Status
docker compose ps

# Logs
docker compose logs -f

# Parar
docker compose down

# Iniciar
docker compose up -d

# Reconstruir
docker compose up -d --build
```

## 💾 Backup e Restauração

### Backup Automático

```bash
./backup.sh
```

O backup inclui:
- Banco de dados MariaDB
- Dados do Nextcloud
- Volumes Docker
- Configurações
- Metadados

### Restauração

```bash
./restore.sh nome_do_backup
```

**⚠️ ATENÇÃO**: A restauração sobrescreve todos os dados existentes!

## 🔌 Apps Disponíveis

Apps populares que podem ser instalados via gerenciador:

- **OnlyOffice** - Editor de documentos
- **Collabora** - Editor de documentos
- **Talk** - Chat e videoconferência
- **Calendar** - Calendário
- **Contacts** - Contatos
- **Notes** - Notas

## 🔒 Segurança

### Recomendações

1. **Altere as senhas padrão** no arquivo `.env`
2. **Use HTTPS** em produção
3. **Configure firewall** para permitir apenas portas 80/443
4. **Faça backups regulares**
5. **Mantenha o sistema atualizado**

### Configurações de Segurança

O projeto inclui:
- Headers de segurança no Nginx
- Configurações PHP seguras
- Isolamento de containers
- Certificados SSL

## 📊 Monitoramento

### Verificar Status

```bash
# Status geral
./manage.sh → Opção 1

# Verificar integridade
./manage.sh → Opção 11

# Logs em tempo real
./manage.sh → Opção 5
```

### Métricas Importantes

- Uso de CPU e RAM dos containers
- Espaço em disco
- Status do banco de dados
- Logs de erro

## 🚨 Troubleshooting

### Problemas Comuns

1. **Nextcloud não inicia**
   ```bash
   docker compose logs app
   ```

2. **Erro de banco de dados**
   ```bash
   docker compose logs db
   ```

3. **Problemas de SSL**
   ```bash
   docker compose logs nginx
   ```

4. **Permissões de arquivo**
   ```bash
   sudo chown -R $USER:$USER data config apps themes
   ```

### Logs Úteis

```bash
# Todos os logs
docker compose logs

# Logs específicos
docker compose logs app
docker compose logs db
docker compose logs nginx

# Logs em tempo real
docker compose logs -f
```

## 🔄 Atualização

### Atualizar Nextcloud

```bash
./manage.sh → Opção 8
```

**⚠️ IMPORTANTE**: Sempre faça backup antes de atualizar!

### Atualizar Containers

```bash
docker compose pull
docker compose up -d
```

## 📞 Suporte

### Logs de Debug

```bash
# Ativar modo debug
docker compose exec app php /var/www/html/occ config:system:set loglevel --value=0

# Ver logs detalhados
docker compose logs -f app
```

### Comandos OCC Úteis

```bash
# Status do sistema
docker compose exec app php /var/www/html/occ status

# Listar apps
docker compose exec app php /var/www/html/occ app:list

# Verificar integridade
docker compose exec app php /var/www/html/occ maintenance:repair

# Limpar cache
docker compose exec app php /var/www/html/occ files:scan --all
```

## 📝 Licença

Este projeto é fornecido como está, sem garantias. Use por sua conta e risco.

## 🤝 Contribuição

Contribuições são bem-vindas! Por favor:

1. Faça um fork do projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📚 Recursos Adicionais

- [Documentação oficial do Nextcloud](https://docs.nextcloud.com/)
- [Documentação do Docker](https://docs.docker.com/)
- [Guia de segurança do Nextcloud](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/security_setup_warnings.html)

---

**Desenvolvido com ❤️ para a comunidade Nextcloud** # nextcloud-autosetup
