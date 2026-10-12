#!/bin/bash
# ==============================================================================
# JMDC CoreOS - Provisionamento Base (Padrão Ouro Full-Stack)
# Autor: JMDC Consulting and Technology
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

echo "[*] 1. Sincronizando Repositórios e Atualizando Kernel (Debian 13)..."
apt-get update && apt-get dist-upgrade -y

echo "[*] 2. Instalando Arsenal Tático, Python e Fastfetch..."
apt-get install -y vim bash-completion fzf curl wget ufw fail2ban htop net-tools \
    dnsutils tcpdump grc tmux ncdu jq bat python3 python3-pip python3-venv \
    ca-certificates gnupg lsb-release fastfetch

echo "[*] 3. Instalando Docker Engine..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[*] 4. Instalando PostgreSQL 16..."
install -d /usr/share/postgresql-common/pgdg
curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list > /dev/null
apt-get update && apt-get install -y postgresql-16 postgresql-contrib

echo "[*] 5. Expurgo do Sudo (Padrão UNIX Purista)..."
apt-get purge --auto-remove sudo -y

echo "[*] 6. Hardening de SSH e Firewall..."
systemctl stop ssh.socket 2>/dev/null
systemctl disable ssh.socket 2>/dev/null
systemctl mask ssh.socket 2>/dev/null
systemctl enable ssh.service

mkdir -p /etc/ssh/sshd_config.d/
cat << 'EOF' > /etc/ssh/sshd_config.d/99-jmdc-ssh.conf
Port 22022
ClientAliveInterval 0
ClientAliveCountMax 0
EOF
systemctl restart ssh

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22022/tcp comment 'SSH JMDC'
ufw --force enable

systemctl enable fail2ban && systemctl start fail2ban

echo "[*] 7. Identidade Visual e Saudação Temporal com Valores JMDC..."
mkdir -p /etc/fastfetch
cat << 'EOF' > /etc/fastfetch/jmdc_logo.txt
      ██╗███╗   ███╗██████╗  ██████╗ 
      ██║████╗ ████║██╔══██╗██╔════╝ 
      ██║██╔████╔██║██║  ██║██║      
 ██   ██║██║╚██╔╝██║██║  ██║██║      
 ╚█████╔╝██║ ╚═╝ ██║██████╔╝╚██████╗ 
  ╚════╝ ╚═╝     ╚═╝╚═════╝  ╚═════╝ 
     [ C O R E - O S   1 3 . 0 ]
EOF

cat << 'EOF' > /etc/fastfetch/config.jsonc
{
  "logo": { "type": "file", "source": "/etc/fastfetch/jmdc_logo.txt" },
  "display": { "separator": " ➜ " },
  "modules": [ "title", "separator", "os", "host", "kernel", "uptime", "packages", "shell", "cpu", "memory", "disk" ]
}
EOF

# Injeção da Saudação Temporal e 50 Passagens Bíblicas no Perfil Global
cat << 'EOF' > /etc/profile.d/jmdc_coreos.sh
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias l='ls -lha --color=auto'
alias meuip='curl ifconfig.me; echo;'
alias cat='batcat --paging=never'
export PS1='\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;31m\]\$\[\033[00m\] '

verses=(
    "Tudo o que fizerem, façam de todo o coração, como para o Senhor. - Colossenses 3:23"
    "Consagre ao Senhor tudo o que você faz, e os seus planos serão bem-sucedidos. - Provérbios 16:3"
    "Em todo trabalho há proveito, mas ficar só em palavras leva à pobreza. - Provérbios 14:23"
    "O Senhor enviará bênçãos aos seus celeiros e a tudo o que as suas mãos fizerem. - Deuteronômio 28:8"
    "O preguiçoso deseja e nada consegue, mas os desejos do diligente são amplamente satisfeitos. - Provérbios 13:4"
    "Seja forte e corajoso! Não se apavore nem desanime, pois o Senhor, o seu Deus, estará com você. - Josué 1:9"
    "Pois eu bem sei os planos que estou projetando para vós, diz o Senhor; planos de paz, e não de mal. - Jeremias 29:11"
    "O Senhor é o meu pastor; de nada terei falta. - Salmos 23:1"
    "Peçam, e será dado; busquem, e encontrarão; batam, e a porta será aberta. - Mateus 7:7"
    "Tudo posso naquele que me fortalece. - Filipenses 4:13"
    "Confie no Senhor de todo o seu coração e não se apoie em seu próprio entendimento. - Provérbios 3:5"
    "Buscai, pois, em primeiro lugar, o seu reino e a sua justiça, e todas estas coisas vos serão acrescentadas. - Mateus 6:33"
    "O Deus dos céus é quem nos dará o bom êxito; nós, seus servos, nos levantaremos e edificaremos. - Neemias 2:20"
    "Deleite-se no Senhor, e ele atenderá aos desejos do seu coração. - Salmos 37:4"
    "Entregue o seu caminho ao Senhor; confie nele, e ele agirá. - Salmos 37:5"
    "O que as suas mãos tiverem que fazer, que o façam com toda a sua força. - Eclesiastes 9:10"
    "O generoso prosperará; quem dá alívio aos outros, alívio receberá. - Provérbios 11:25"
    "As mãos diligentes governarão, mas os preguiçosos acabarão escravos. - Provérbios 12:24"
    "O trabalhador é digno do seu salário. - 1 Timóteo 5:18"
    "Riqueza de procedência vã diminuirá, mas quem a ajunta com o próprio trabalho a aumentará. - Provérbios 13:11"
    "Vês um homem perito na sua obra? Perante reis será posto. - Provérbios 22:29"
    "A bênção do Senhor traz riqueza e não inclui dor alguma. - Provérbios 10:22"
    "E o meu Deus, segundo a sua riqueza em glória, há de suprir cada uma de vossas necessidades. - Filipenses 4:19"
    "Não fui eu que ordenei a você? Seja forte e corajoso! - Josué 1:9"
    "O que atenta prudentemente para a palavra achará o bem. - Provérbios 16:20"
    "Lembrem-se do Senhor, o seu Deus, pois é ele que lhes dá a capacidade de produzir riqueza. - Deuteronômio 8:18"
    "O galardão da humildade e o temor do Senhor são riquezas, e honra, e vida. - Provérbios 22:4"
    "Eis que diante de ti pus uma porta aberta, e ninguém a pode fechar. - Apocalipse 3:8"
    "Os que buscam o Senhor de nada têm falta. - Salmos 34:10"
    "Alegrem-se na esperança, sejam pacientes na tribulação, perseverem na oração. - Romanos 12:12"
    "Tudo quanto o justo faz será bem sucedido. - Salmos 1:3"
    "Aqueles que semeiam com lágrimas, com cantos de alegria colherão. - Salmos 126:5"
    "Mas os que esperam no Senhor renovarão as forças, subirão com asas como águias. - Isaías 40:31"
    "Sabemos que todas as coisas contribuem juntamente para o bem daqueles que amam a Deus. - Romanos 8:28"
    "O Senhor te abrirá o seu bom tesouro, o céu, para dar chuva à tua terra no seu tempo. - Deuteronômio 28:12"
    "Toda ferramenta preparada contra ti não prosperará. - Isaías 54:17"
    "Por isso não tema, pois estou com você; não tenha medo, pois sou o seu Deus. - Isaías 41:10"
    "Eu é que sei que pensamentos tenho a vosso respeito, pensamentos de paz. - Jeremias 29:11"
    "Provai e vede que o Senhor é bom; bem-aventurado o homem que nele confia. - Salmos 34:8"
    "O justo passa por muitas adversidades, mas o Senhor o livra de todas. - Salmos 34:19"
    "Eu sou a videira, vós os ramos. Quem permanece em mim dá muito fruto. - João 15:5"
    "Não estejais inquietos por coisa alguma... sejam as vossas petições conhecidas diante de Deus. - Filipenses 4:6"
    "Esforçai-vos, e ele fortalecerá o vosso coração, vós todos que esperais no Senhor. - Salmos 31:24"
    "Se Deus é por nós, quem será contra nós? - Romanos 8:31"
    "Aquele que começou a boa obra em vocês, vai completá-la até o dia de Cristo Jesus. - Filipenses 1:6"
    "Porque para Deus nada é impossível. - Lucas 1:37"
    "Deem e lhes será dado: uma boa medida, calcada, sacudida e transbordante. - Lucas 6:38"
    "O amor seja sem hipocrisia. Detestai o mal, apegai-vos ao bem. - Romanos 12:9"
    "Estejam vigilantes, mantenham-se firmes na fé, sejam fortes. - 1 Coríntios 16:13"
    "Façam tudo com amor. - 1 Coríntios 16:14"
)

hour=$(date +%H)
if [ "$hour" -ge 4 ] && [ "$hour" -lt 12 ]; then
    greeting="Bom dia"
elif [ "$hour" -ge 12 ] && [ "$hour" -lt 18 ]; then
    greeting="Boa tarde"
else
    greeting="Boa noite"
fi

RANDOM_INDEX=$((RANDOM % 50))
selected_verse="${verses[$RANDOM_INDEX]}"

echo -e "\n\033[01;33m${greeting}, \033[01;34m${USER}\033[01;33m!\033[00m"
echo -e "\033[01;36m\"${selected_verse}\"\033[00m\n"

if [ -x "$(command -v fastfetch)" ]; then
    fastfetch
fi
EOF
chmod +x /etc/profile.d/jmdc_coreos.sh

echo "[*] 8. Tuning de Performance de Kernel (sysctl)..."
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
