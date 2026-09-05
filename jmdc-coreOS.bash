#!/bin/bash
# ==============================================================================
# JMDC CoreOS - Provisionamento Base (Minimalista, Seguro & Tático)
# Autor: JMDC Consulting and Technology
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

echo "[*] 1. Sincronizando Repositórios e Atualizando Kernel..."
apt-get update && apt-get dist-upgrade -y

echo "[*] 2. Instalando Core-Packages, Arsenal Tático e Expurgando Sudo..."
# Instalação expandida: tmux, ncdu, jq e bat (batcat) para engenharia avançada
apt-get install -y vim bash-completion fzf curl wget ufw fail2ban htop net-tools \
    dnsutils tcpdump grc fastfetch tmux ncdu jq bat

# Remoção absoluta do Sudo para manter o padrão UNIX purista
apt-get purge --auto-remove sudo -y

echo "[*] 3. Hardening de SSH (Porta 22022) e Desativação do Systemd Socket..."
# Neutraliza o socket preemptivo do Debian 13 para assumir controle direto
systemctl stop ssh.socket 2>/dev/null
systemctl disable ssh.socket 2>/dev/null
systemctl mask ssh.socket 2>/dev/null
systemctl enable ssh.service

# Injeção modular declarativa (ignora o arquivo sshd_config nativo)
mkdir -p /etc/ssh/sshd_config.d/
cat << 'EOF' > /etc/ssh/sshd_config.d/99-jmdc-ssh.conf
Port 22022
ClientAliveInterval 0
ClientAliveCountMax 0
EOF

systemctl restart ssh

echo "[*] 4. Orquestrando Firewall (UFW) e Fail2ban..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22022/tcp comment 'SSH JMDC'
ufw --force enable

systemctl enable fail2ban
systemctl start fail2ban

echo "[*] 5. Injetando Identidade Visual (Fastfetch)..."
mkdir -p /etc/fastfetch

# Logo ASCII oficial da JMDC (Extraído de jmdc_logo.txt)
cat << 'EOF' > /etc/fastfetch/jmdc_logo.txt
      ██╗███╗   ███╗██████╗  ██████╗ 
      ██║████╗ ████║██╔══██╗██╔════╝ 
      ██║██╔████╔██║██║  ██║██║      
 ██   ██║██║╚██╔╝██║██║  ██║██║      
 ╚█████╔╝██║ ╚═╝ ██║██████╔╝╚██████╗ 
  ╚════╝ ╚═╝     ╚═╝╚═════╝  ╚═════╝ 
     [ C O R E - O S   1 3 . 0 ]
EOF

# Configuração declarativa do Fastfetch
cat << 'EOF' > /etc/fastfetch/config.jsonc
{
  "logo": { "type": "file", "source": "/etc/fastfetch/jmdc_logo.txt" },
  "display": { "separator": " ➜ " },
  "modules": [ "title", "separator", "os", "host", "kernel", "uptime", "packages", "shell", "cpu", "memory", "disk" ]
}
EOF

echo "[*] 6. Calibrando Shell Global, Cores e Aliases Táticos..."
# Injeção em profile.d para garantir governança em novos usuários
cat << 'EOF' > /etc/profile.d/jmdc_coreos.sh
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias l='ls -lha --color=auto'
alias meuip='curl ifconfig.me; echo;'
alias cat='batcat --paging=never' # Substitui o cat tradicional pelo leitor com syntax highlighting
export PS1='\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;31m\]\$\[\033[00m\] '
fastfetch
EOF
chmod +x /etc/profile.d/jmdc_coreos.sh

# Otimização de Identação e Cores no VIM
cat << 'EOF' > /etc/vim/vimrc.local
syntax on
set background=dark
set ts=4 sts=4 sw=4 autoindent number
EOF

echo "[*] 7. Tuning de Performance de Kernel (sysctl)..."
cat <<EOF > /etc/sysctl.d/99-jmdc-core.conf
vm.swappiness = 10
vm.vfs_cache_pressure = 50
net.core.somaxconn = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_syncookies = 1
fs.file-max = 2097152
EOF
sysctl --system

echo "[*] ====================================================================="
echo "[*] PROVISIONAMENTO JMDC CORE-OS CONCLUÍDO COM SUCESSO"
echo "[*] ACESSO VIA PORTA SSH: 22022"
echo "[*] ====================================================================="
