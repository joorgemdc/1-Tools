#!/bin/bash
# ==============================================================================
# JMDC Server Provisioning & Tuning Core
# Autor: JMDC Consulting and Technology
# ==============================================================================

# Garante que o script rode sem solicitar interações (inputs) na tela
export DEBIAN_FRONTEND=noninteractive

echo "[*] Atualizando repositórios e pacotes base..."
apt-get update && apt-get upgrade -y

# Instalação das ferramentas essenciais e pacotes base
apt-get install -y vim bash-completion fzf curl wget sudo ufw fail2ban \
    htop iotop iftop net-tools dnsutils tcpdump grc neofetch snmpd

# ==============================================================================
# 1. CRIAÇÃO DE USUÁRIO E PRIVILÉGIOS
# ==============================================================================
echo "[*] Configurando credenciais corporativas e restrição de acesso..."

# Cria o usuário corporativo com diretório home e shell bash
useradd -m -s /bin/bash joorgemdc
echo 'joorgemdc:@ishit3rU' | chpasswd

# Define a senha absoluta solicitada para a conta root
echo 'root:@ishit3rU' | chpasswd

# Expurga o sudo e todas as suas dependências do ecossistema
echo "[*] Removendo o Sudo para estabelecer o padrão UNIX purista..."
apt-get purge --auto-remove sudo -y

# ==============================================================================
# 2. HARDENING DE SSH E SEGURANÇA (UFW / FAIL2BAN)
# ==============================================================================
echo "[*] Aplicando políticas de Segurança e Firewall..."

# Altera a porta padrão do SSH para 22022
sed -i 's/^#Port 22/Port 22022/' /etc/ssh/sshd_config
sed -i 's/^Port 22/Port 22022/' /etc/ssh/sshd_config
# Garante que o usuário joorgemdc possa logar
echo "AllowUsers joorgemdc root" >> /etc/ssh/sshd_config
systemctl restart sshd

# Configura o Firewall UFW
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22022/tcp comment 'SSH JMDC'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 161/udp comment 'SNMP'
ufw --force enable

# Inicia e habilita o Fail2ban (proteção contra brute-force)
systemctl enable fail2ban
systemctl start fail2ban

# ==============================================================================
# 3. CONFIGURAÇÃO SNMP
# ==============================================================================
echo "[*] Configurando telemetria SNMP..."
# Backup do arquivo original
mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bkp
# Cria a nova configuração: escuta em todas as interfaces (0.0.0.0) na porta UDP 161
# e define a community 'jmdc-snmp' liberada para leitura global (default)
cat <<EOF > /etc/snmp/snmpd.conf
agentAddress udp:161
rocommunity jmdc-snmp default
sysLocation "Datacenter JMDC"
sysContact "noc@jmdc.com.br"
EOF
systemctl restart snmpd
systemctl enable snmpd

# ==============================================================================
# 4. INSTALAÇÃO LEMP STACK E FERRAMENTAS WEB
# ==============================================================================
echo "[*] Instalando NGINX, MariaDB, PHP e phpMyAdmin..."

# Instala o Nginx e o banco de dados MariaDB
apt-get install -y nginx mariadb-server

# Instala o PHP e suas extensões principais
apt-get install -y php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip

# Instalação do phpMyAdmin de forma autônoma
apt-get install -y phpmyadmin
# Cria um link simbólico do phpMyAdmin para o diretório web padrão do Nginx
ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin

# Habilita os serviços para iniciarem com o boot
systemctl enable nginx mariadb php8.1-fpm # Ajuste a versão do PHP caso a distro mude
systemctl start nginx mariadb

# ==============================================================================
# 5. INSTALAÇÃO NETDATA (Monitoramento Real-time)
# ==============================================================================
echo "[*] Instalando motor de monitoramento Netdata..."
# Utiliza o script oficial kickstart do Netdata para instalação silenciosa
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
sh /tmp/netdata-kickstart.sh --non-interactive
# Libera a porta do Netdata no Firewall
ufw allow 19999/tcp comment 'Netdata Dashboard'

# ==============================================================================
# 6. SINTAXE, CORES E NEOFETCH (Terminal Tuning)
# ==============================================================================
echo "[*] Ajustando perfis e sintaxe do terminal..."

# Ativa a exibição do Neofetch sempre que o usuário abrir o terminal
echo "neofetch" >> /root/.bashrc
echo "neofetch" >> /home/joorgemdc/.bashrc

# Otimização do VIM (Identação e Cores)
cat <<EOF > /root/.vimrc
syntax on
set background=dark
set showmatch
set ts=4
set sts=4
set sw=4
set autoindent
set smartindent
set smarttab
set expandtab
set number
EOF
cp /root/.vimrc /home/joorgemdc/.vimrc

# Aliases funcionais e de coloração (Base JMDC)
cat <<EOF >> /root/.bashrc
export LS_OPTIONS='--color=auto'
eval "\$(dircolors)"
alias ls='ls \$LS_OPTIONS'
alias ll='ls \$LS_OPTIONS -l'
alias l='ls \$LS_OPTIONS -lha'
alias grep='grep --color'
alias egrep='egrep --color'
alias ip='ip -c'
alias diff='diff --color'
alias ping='grc ping'
alias netstat='grc netstat'
alias traceroute='grc traceroute'
alias meuip='curl ifconfig.me; echo;'
# Ajuste visual do prompt de comando
PS1='\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;31m\]\\$\[\033[00m\] '
EOF

# ==============================================================================
# 7. OTIMIZAÇÃO DE KERNEL (Swap, Memória e Processamento)
# ==============================================================================
echo "[*] Aplicando Tuning de Kernel (sysctl)..."

cat <<EOF >> /etc/sysctl.conf
# Reduz a tendência do Kernel de usar o disco como Swap (padrão é 60, baixamos para 10)
# Isso força o SO a usar a memória RAM física ao máximo antes de paginar no disco.
vm.swappiness = 10

# Reduz a pressão do cache do VFS (padrão é 100).
# Mantém o cache de diretórios (dentries e inodes) em memória por mais tempo.
vm.vfs_cache_pressure = 50

# Otimização para manipulação de alto tráfego / sockets no NGINX e DB
# Aumenta o número máximo de conexões em fila
net.core.somaxconn = 65535

# Aumenta o range de portas efêmeras para conexões TCP de saída
net.ipv4.ip_local_port_range = 1024 65535

# Proteção extra contra SYN Flood (TCP SYN Cookies)
net.ipv4.tcp_syncookies = 1

# Aumenta o limite de arquivos abertos (File Descriptors) para o processador
fs.file-max = 2097152
EOF

# Aplica as configurações do Kernel imediatamente sem precisar reiniciar
sysctl -p

echo "[*] ====================================================================="
echo "[*] PROVISIONAMENTO CONCLUÍDO COM SUCESSO!"
echo "[*] O sistema está blindado e tunado."
echo "[*] Lembre-se de acessar agora via porta SSH: 22022"
echo "[*] ====================================================================="
