#!/bin/bash
# ==============================================================================
# JMDC Server Provisioning & Tuning Core (V2 - XFCE Edition)
# Autor: JMDC Consulting and Technology
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

echo "[*] Atualizando repositórios e pacotes base..."
apt-get update && apt-get upgrade -y

# Instalação das ferramentas essenciais (Migração Neofetch -> Fastfetch)
apt-get install -y vim bash-completion fzf curl wget ufw fail2ban \
    htop iotop iftop net-tools dnsutils tcpdump grc fastfetch snmpd

# ==============================================================================
# 1. CRIAÇÃO DE USUÁRIO E PRIVILÉGIOS
# ==============================================================================
echo "[*] Configurando credenciais corporativas..."
useradd -m -s /bin/bash joorgemdc
echo 'joorgemdc:@ishit3rU' | chpasswd
echo 'root:@ishit3rU' | chpasswd

echo "[*] Estabelecendo padrão UNIX purista (Removendo Sudo)..."
apt-get purge --auto-remove sudo -y

# ==============================================================================
# 2. MIGRACAO DE INTERFACE (GNOME -> XFCE4)
# ==============================================================================
echo "[*] Expurgando GNOME e instalando XFCE4..."
apt-get purge -y gnome* gdm3
apt-get autoremove -y

apt-get install -y xfce4 xfce4-goodies lightdm

# ==============================================================================
# 3. HARDENING DE SSH E SEGURANÇA (UFW / FAIL2BAN)
# ==============================================================================
echo "[*] Aplicando políticas de Segurança (Porta 22022 Fix)..."

# Correção Idempotente da Porta SSH
sed -i 's/^#Port 22$/Port 22022/' /etc/ssh/sshd_config
sed -i 's/^Port 22$/Port 22022/' /etc/ssh/sshd_config

echo "AllowUsers joorgemdc root" >> /etc/ssh/sshd_config
systemctl restart sshd

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22022/tcp comment 'SSH JMDC'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 161/udp comment 'SNMP'
ufw allow 19999/tcp comment 'Netdata Dashboard'
ufw --force enable

systemctl enable fail2ban
systemctl start fail2ban

# ==============================================================================
# 4. CONFIGURAÇÃO SNMP E MONITORAMENTO
# ==============================================================================
echo "[*] Configurando telemetria SNMP e Netdata..."
[ -f /etc/snmp/snmpd.conf ] && mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bkp
cat <<EOF > /etc/snmp/snmpd.conf
agentAddress udp:161
rocommunity jmdc-snmp default
sysLocation "Datacenter JMDC"
sysContact "noc@jmdc.com.br"
EOF
systemctl restart snmpd
systemctl enable snmpd

# Netdata
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
sh /tmp/netdata-kickstart.sh --non-interactive

# ==============================================================================
# 5. INSTALAÇÃO LEMP STACK
# ==============================================================================
echo "[*] Instalando NGINX, MariaDB, PHP e phpMyAdmin..."
apt-get install -y nginx mariadb-server php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip phpmyadmin
ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin
systemctl enable nginx mariadb
systemctl start nginx mariadb

# ==============================================================================
# 6. SINTAXE E FASTFETCH (Terminal Tuning)
# ==============================================================================
echo "[*] Ajustando identidade visual JMDC (Fastfetch)..."
mkdir -p /etc/fastfetch
wget -qO /etc/fastfetch/jmdc_logo.txt "https://raw.githubusercontent.com/joorgemdc/1-Tools/refs/heads/main/jmdc_logo.txt"

cat << 'EOF' > /etc/fastfetch/config.jsonc
{
  "logo": { "type": "file", "source": "/etc/fastfetch/jmdc_logo.txt" },
  "display": { "separator": " ➜ " },
  "modules": [ "title", "separator", "os", "host", "kernel", "uptime", "packages", "shell", "cpu", "memory", "disk" ]
}
EOF

echo "fastfetch" >> /root/.bashrc
echo "fastfetch" >> /home/joorgemdc/.bashrc

# VIM e Aliases
cat << 'EOF' > /root/.vimrc
syntax on
set ts=4 sts=4 sw=4 autoindent number
EOF
cp /root/.vimrc /home/joorgemdc/.vimrc

cat << 'EOF' >> /root/.bashrc
alias ls='ls --color=auto'
alias ll='ls -l'
alias l='ls -lha'
alias meuip='curl ifconfig.me; echo;'
PS1='\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;31m\]\$\[\033[00m\] '
EOF
cp /root/.bashrc /home/joorgemdc/.bashrc

# ==============================================================================
# 7. TUNING DE KERNEL E ALTA DISPONIBILIDADE
# ==============================================================================
echo "[*] Aplicando Tuning de Kernel e Bloqueio de Suspensão..."

cat <<EOF >> /etc/sysctl.conf
vm.swappiness = 10
vm.vfs_cache_pressure = 50
net.core.somaxconn = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_syncookies = 1
fs.file-max = 2097152
EOF
sysctl -p

# Bloqueio de Suspensão (Systemd + XFCE Policy)
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
cat << 'EOF' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="int" value="0"/>
    <property name="dpms-on-ac-off" type="int" value="0"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
  </property>
</channel>
EOF

echo "[*] ====================================================================="
echo "[*] PROVISIONAMENTO CONCLUÍDO: GNOME REMOVIDO / XFCE4 INSTALADO"
echo "[*] ACESSO VIA PORTA SSH: 22022"
echo "[*] ====================================================================="
