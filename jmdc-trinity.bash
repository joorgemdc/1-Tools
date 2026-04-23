#!/bin/bash
# ==============================================================================
# JMDC Trinity Engine - Core Provisioning Script
# Autor: JMDC Consulting and Technology
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

echo "[*] 1. CONFIGURANDO ARMAZENAMENTO E PONTO DE MONTAGEM (TRINITY DATA)..."
mkdir -p /mnt/trinity_data
# Adiciona ao fstab garantindo que não haja duplicação
if ! grep -q "/mnt/trinity_data" /etc/fstab; then
    echo '/dev/sdc1 /mnt/trinity_data ext4 defaults,noatime 0 2' | tee -a /etc/fstab
fi
mount -a
df -h | grep trinity_data

echo "[*] 2. ATUALIZANDO PACOTES E INSTALANDO BASE GRÁFICA (XFCE4)..."
apt-get update && apt-get upgrade -y
apt-get install -y xfce4 xfce4-goodies lightdm

echo "[*] 3. HARDENING DE SSH E FIREWALL (UFW)..."
# Ajuste idempotente do ClientAlive
sed -i '/^ClientAliveInterval/d' /etc/ssh/sshd_config
sed -i '/^ClientAliveCountMax/d' /etc/ssh/sshd_config
echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 10" >> /etc/ssh/sshd_config
systemctl restart ssh

apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
for port in 22 22022 80 81 443; do
    ufw allow $port/tcp
done
ufw --force enable

echo "[*] 4. INSTALAÇÃO DO MOTOR DOCKER E DEPENDÊNCIAS..."
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker $USER

echo "[*] 5. TOPOLOGIA DE REDE E GOVERNANÇA DE IDENTIDADE..."
docker network create trinity_net 2>/dev/null || true

# Criação de grupo e usuário restrito (Ignora erro se já existir)
groupadd -g 1500 pbgroup 2>/dev/null || true
useradd -u 1500 -g 1500 -s /usr/sbin/nologin -M pbuser 2>/dev/null || true

echo "[*] 6. PROVISIONANDO NGINX PROXY MANAGER..."
systemctl stop apache2 nginx 2>/dev/null || true
systemctl disable apache2 nginx 2>/dev/null || true

mkdir -p /mnt/trinity_data/proxy/{data,letsencrypt}
cd /mnt/trinity_data/proxy

cat << 'EOF' > docker-compose.yml
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: jmdc_trinity_npm
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    networks:
      - trinity_net
networks:
  trinity_net:
    external: true
EOF
docker compose up -d

echo "[*] 7. PROVISIONANDO POCKETBASE (BaaS)..."
mkdir -p /mnt/trinity_data/backend/{pb_data,pb_public/images}
chown -R 1500:1500 /mnt/trinity_data/backend
cd /mnt/trinity_data/backend

cat << 'EOF' > Dockerfile
FROM alpine:3.19
ARG PB_VERSION=0.22.9
RUN apk add --no-cache unzip ca-certificates
ADD https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip /tmp/pb.zip
RUN unzip /tmp/pb.zip -d /pb/ && rm /tmp/pb.zip
EXPOSE 8090
EOF

cat << 'EOF' > docker-compose.yml
services:
  pocketbase:
    build: .
    container_name: jmdc_trinity_pb
    restart: unless-stopped
    user: "1500:1500"
    cap_drop:
      - ALL
    command: ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090", "--dir=/pb_data", "--publicDir=/pb_public"]
    volumes:
      - ./pb_data:/pb_data
      - ./pb_public:/pb_public
    security_opt:
      - no-new-privileges:true
    networks:
      - trinity_net
networks:
  trinity_net:
    external: true
EOF
docker compose up --build -d

echo "[*] 8. PROVISIONANDO FILEBROWSER..."
mkdir -p /mnt/trinity_data/filemanager/config
cd /mnt/trinity_data/filemanager
touch config/database.db

cat << 'EOF' > docker-compose.yml
services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: jmdc_trinity_files
    restart: unless-stopped
    user: "0:0"
    volumes:
      - /mnt/trinity_data:/srv
      - ./config:/database
    environment:
      - FB_DATABASE=/database/filebrowser.db
      - FB_BASEURL=/
    networks:
      - trinity_net
networks:
  trinity_net:
    external: true
EOF
docker compose up -d
sleep 3
# Configuração de administrador autônoma
docker stop jmdc_trinity_files
docker run --rm -u 0:0 -v /mnt/trinity_data/filemanager/config:/database filebrowser/filebrowser users add admin @ishit3rU_030220 --perm.admin --database /database/filebrowser.db 2>/dev/null || true
docker run --rm -u 0:0 -v /mnt/trinity_data/filemanager/config:/database filebrowser/filebrowser users update admin --password @ishit3rU_030220 --database /database/filebrowser.db
docker start jmdc_trinity_files

echo "[*] 9. INJETANDO PORTAL WEB (CRM)..."
cd /mnt/trinity_data/backend/pb_public

# Criação do arquivo HTML via Heredoc (já garante codificação limpa)
cat << 'EOF' > crm.html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Portal Arquidiocese | JMDC Trinity</title>
    <link rel="icon" type="image/png" href="favicon.png">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@300;400;600&family=Space+Grotesk:wght@300;700&display=swap');
        :root { 
            --bg-color: #f8fafc; --text-color: #0f172a; --primary: #003366; 
            --secondary: #eab308; --accent: #dc2626; --danger: #ef4444; 
            --warning: #f59e0b; --card-bg: #ffffff; --card-border: rgba(0, 51, 102, 0.15); 
        }
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Segoe UI', system-ui, sans-serif; }
        body { background-color: var(--bg-color); color: var(--text-color); line-height: 1.6; overflow-x: hidden; display: flex; flex-direction: column; min-height: 100vh; }
        header { display: flex; justify-content: space-between; align-items: center; padding: 1.2rem 5%; background: #ffffff; position: fixed; width: 100%; top: 0; z-index: 1000; border-bottom: 3px solid var(--secondary); box-shadow: 0 4px 15px rgba(0,0,0,0.05); }
        .logo-link { display: flex; align-items: center; text-decoration: none; }
        .logo-img { height: 50px; width: auto; transition: transform 0.3s ease; }
        .logo-img:hover { transform: scale(1.02); }
        nav { display: flex; align-items: center; gap: 2rem; }
        .nav-links { display: flex; list-style: none; gap: 2rem; }
        .nav-link { display: flex; align-items: center; gap: 8px; color: var(--primary); text-decoration: none; font-weight: 600; transition: 0.3s; font-size: 0.95rem;}
        .nav-link svg { width: 18px; height: 18px; transition: 0.3s ease-in-out; stroke: currentColor; fill: none; }
        .nav-link:hover { color: var(--accent); }
        main { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 120px 5% 40px 5%; width: 100%; }
        .jmdc-greeting-container { text-align: center; margin-bottom: 30px; font-family: 'Space Grotesk', sans-serif; }
        .greeting-main { font-size: 2rem; font-weight: 800; color: var(--primary); margin-bottom: 5px;}
        .greeting-sub { font-size: 1.1rem; color: #64748b; margin-bottom: 12px; }
        .greeting-time { font-family: 'Fira Code', monospace; font-size: 0.95rem; color: var(--primary); font-weight: bold;}
        .auth-container { background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 12px; padding: 40px; width: 100%; max-width: 450px; box-shadow: 0 20px 40px rgba(0, 51, 102, 0.08); }
        .auth-header { text-align: center; margin-bottom: 25px; }
        .auth-header h2 { font-size: 1.8rem; font-weight: 800; color: var(--primary); font-family: 'Space Grotesk', sans-serif;}
        .auth-header p { color: #64748b; font-size: 0.9rem; margin-top: 5px; }
        .input-group { margin-bottom: 15px; }
        .input-group label { display: block; font-size: 0.85rem; color: var(--primary); margin-bottom: 5px; font-weight: 600; }
        .input-group input { width: 100%; padding: 14px; background: #ffffff; border: 1px solid #cbd5e1; color: var(--text-color); border-radius: 8px; outline: none; font-size: 1rem; transition: 0.3s; }
        .input-group input:focus { border-color: var(--primary); box-shadow: 0 0 0 2px rgba(0, 51, 102, 0.2); }
        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
        .btn-submit { width: 100%; padding: 14px; margin-top: 10px; background: var(--primary); color: white; border: none; border-radius: 8px; font-weight: bold; font-size: 1.1rem; cursor: pointer; transition: 0.3s; }
        .btn-submit:hover { background: #002244; transform: translateY(-2px); }
        .btn-submit:disabled { background: #94a3b8; cursor: not-allowed; transform: none; }
        .auth-toggle { text-align: center; margin-top: 20px; font-size: 0.9rem; color: #64748b; display: flex; flex-direction: column; gap: 8px; }
        .auth-toggle a { color: var(--accent); text-decoration: none; font-weight: bold; cursor: pointer; transition: 0.3s; }
        .auth-toggle a:hover { text-decoration: underline; }
        .alert-box { display: none; padding: 12px; border-radius: 8px; margin-bottom: 20px; font-size: 0.9rem; font-weight: bold; text-align: center; }
        .alert-error { background: rgba(239, 68, 68, 0.1); border: 1px solid var(--danger); color: var(--danger); }
        .alert-success { background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; color: #059669; }
        .hidden { display: none !important; }
        footer { position: relative; background: #0a0f1d; padding: 20px; text-align: center; margin-top: auto; border-top: 3px solid var(--primary); overflow: hidden; }
        #footer-canvas { position: absolute; top: 0; left: 0; width: 100%; height: 100%; opacity: 0.4; pointer-events: none; z-index: 0;}
        .footer-content { position: relative; z-index: 1; color: #e2e8f0; font-size: 0.85rem; font-family: 'Space Grotesk', sans-serif;}
        .footer-content span { color: #3b82f6; font-weight: bold; }
        @media (max-width: 768px) { header { padding: 12px 15px !important; } .nav-links { display: none; } .auth-container { padding: 30px 20px; } .grid-2 { grid-template-columns: 1fr; gap: 0; } }
    </style>
</head>
<body>
    <header>
        <a href="index.html" class="logo-link">
            <img src="images/arquidiocese-salvador.png" alt="Arquidiocese de São Salvador" class="logo-img">
        </a>
        <nav>
            <ul class="nav-links">
                <li><a href="#" class="nav-link"><svg viewBox="0 0 24 24" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg> Início</a></li>
                <li><a href="#" class="nav-link"><svg viewBox="0 0 24 24" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><path d="M8 21h8"/><path d="M12 17v4"/></svg> Suporte TI</a></li>
            </ul>
        </nav>
    </header>
    <main>
        <div class="jmdc-greeting-container">
            <div class="greeting-main" id="jmdc-saudacao">Bem-vindo</div>
            <div class="greeting-sub">Portal Administrativo e Operacional</div>
            <div class="greeting-time" id="jmdc-data-hora">Carregando dados temporais...</div>
        </div>
        <div class="auth-container">
            <div id="alert-msg" class="alert-box"></div>
            <div id="form-login">
                <div class="auth-header">
                    <h2>Acesso Institucional</h2>
                    <p>Insira suas credenciais para continuar.</p>
                </div>
                <form id="loginForm">
                    <div class="input-group">
                        <label>E-mail Corporativo</label>
                        <input type="email" id="log-email" required placeholder="seu.nome@arquidiocese.org.br">
                    </div>
                    <div class="input-group">
                        <label>Senha de Acesso</label>
                        <input type="password" id="log-pass" required placeholder="••••••••">
                    </div>
                    <button type="submit" class="btn-submit" id="btn-do-login">Acessar Painel</button>
                </form>
                <div class="auth-toggle">
                    <a id="btn-forgot-pass" style="font-weight: normal; font-size: 0.85rem;">Esqueci minha senha</a>
                    <span>Não possui acesso? <a id="btn-show-register">Solicite um cadastro</a></span>
                </div>
            </div>
            <div id="form-register" class="hidden">
                <div class="auth-header">
                    <h2>Novo Colaborador</h2>
                    <p>Preencha os dados para provisionamento.</p>
                </div>
                <form id="registerForm">
                    <div class="grid-2">
                        <div class="input-group"><label>Nome</label><input type="text" id="reg-nome" required></div>
                        <div class="input-group"><label>Sobrenome</label><input type="text" id="reg-sobrenome" required></div>
                    </div>
                    <div class="input-group"><label>Setor / Paróquia</label><input type="text" id="reg-empresa" required></div>
                    <div class="input-group"><label>WhatsApp / Telefone</label><input type="tel" id="reg-telefone" required placeholder="(71) 90000-0000" maxlength="15"></div>
                    <div class="input-group"><label>E-mail Corporativo</label><input type="email" id="reg-email" required></div>
                    <div class="input-group">
                        <label>Defina uma Senha</label>
                        <input type="password" id="reg-pass" required placeholder="Mínimo 6 caracteres">
                    </div>
                    <button type="submit" class="btn-submit" id="btn-do-register">Solicitar Acesso</button>
                </form>
                <div class="auth-toggle">
                    <span>Já possui acesso? <a id="btn-show-login">Faça Login aqui</a></span>
                </div>
            </div>
        </div>
    </main>
    <footer>
        <canvas id="footer-canvas"></canvas>
        <div class="footer-content">
            Governança Digital desenvolvida por <span>JMDC Trinity Engine</span> &copy; 2026
        </div>
    </footer>
    <script>
        function updateJMDCGreeting() {
            const now = new Date();
            const hour = now.getHours();
            let saudacao = "Boa noite";
            if (hour >= 4 && hour < 12) saudacao = "Bom dia";
            else if (hour >= 12 && hour < 18) saudacao = "Boa tarde";
            const mesFormatado = now.toLocaleString('pt-BR', { month: 'long' });
            const dataHora = `${now.getDate().toString().padStart(2, '0')} de ${mesFormatado} de ${now.getFullYear()} às ${now.toLocaleTimeString('pt-BR')}`;
            document.getElementById('jmdc-saudacao').innerText = saudacao;
            document.getElementById('jmdc-data-hora').innerText = dataHora;
        }
        document.addEventListener('DOMContentLoaded', () => {
            updateJMDCGreeting(); setInterval(updateJMDCGreeting, 1000); 
            const canvas = document.getElementById('footer-canvas');
            if (canvas) {
                const ctx = canvas.getContext('2d'); let w, h, particles = [];
                const resize = () => { w = canvas.width = canvas.parentElement.clientWidth; h = canvas.height = canvas.parentElement.clientHeight; };
                window.addEventListener('resize', resize); resize();
                function initParticles() { particles=[]; for(let i=0;i<30;i++) particles.push({x:Math.random()*w, y:Math.random()*h, vx:(Math.random()-.5)*0.5, vy:(Math.random()-.5)*0.5});}
                function animateParticles() { 
                    ctx.clearRect(0,0,w,h); 
                    particles.forEach((p,i)=>{
                        p.x+=p.vx; p.y+=p.vy; 
                        if(p.x<0||p.x>w)p.vx*=-1; if(p.y<0||p.y>h)p.vy*=-1;
                        ctx.beginPath(); ctx.arc(p.x,p.y,1.5,0,Math.PI*2); ctx.fillStyle='#3b82f6'; ctx.fill();
                        for(let j=i;j<particles.length;j++){
                            let dx=p.x-particles[j].x, dy=p.y-particles[j].y, d=Math.hypot(dx,dy);
                            if(d<60){ctx.beginPath();ctx.strokeStyle=`rgba(59,130,246,${1-d/60})`;ctx.lineWidth=0.5;ctx.moveTo(p.x,p.y);ctx.lineTo(particles[j].x,particles[j].y);ctx.stroke();}
                        }
                    }); requestAnimationFrame(animateParticles);
                } initParticles(); animateParticles();
            }
        });
        const formLogin = document.getElementById('form-login');
        const formRegister = document.getElementById('form-register');
        const alertBox = document.getElementById('alert-msg');
        document.getElementById('btn-show-register').addEventListener('click', () => { formLogin.classList.add('hidden'); formRegister.classList.remove('hidden'); alertBox.style.display = 'none'; });
        document.getElementById('btn-show-login').addEventListener('click', () => { formRegister.classList.add('hidden'); formLogin.classList.remove('hidden'); alertBox.style.display = 'none'; });
        window.showAlert = function(msg, isSuccess = false) {
            alertBox.innerText = msg; alertBox.style.display = 'block';
            if(isSuccess) { alertBox.classList.remove('alert-error'); alertBox.classList.add('alert-success'); } 
            else { alertBox.classList.remove('alert-success'); alertBox.classList.add('alert-error'); }
        };
        document.getElementById('reg-telefone').addEventListener('input', function(e) {
            let v = e.target.value.replace(/\D/g, '');
            if (v.length > 11) v = v.slice(0, 11);
            if (v.length > 2 && v.length <= 6) v = `(${v.slice(0,2)}) ${v.slice(2)}`;
            else if (v.length > 6) v = `(${v.slice(0,2)}) ${v.slice(2,7)}-${v.slice(7)}`;
            e.target.value = v;
        });
        document.addEventListener('contextmenu', event => event.preventDefault());
    </script>
    <script type="module">
        import PocketBase from 'https://cdn.jsdelivr.net/npm/pocketbase@0.22.9/+esm';
        const pb = new PocketBase('http://erp.arquiprimaz.org.br');
        const exibirAlerta = window.showAlert;
        let isSubmitting = false;
        if (pb.authStore.isValid && !isSubmitting) window.location.replace("dashboard.html");
        document.getElementById('btn-forgot-pass').addEventListener('click', async () => {
            const email = document.getElementById('log-email').value.trim();
            if(!email) { exibirAlerta("Digite seu e-mail no campo acima antes de solicitar a redefinição."); return; }
            try { 
                await pb.collection('users').requestPasswordReset(email);
                exibirAlerta("Link de redefinição enviado para o seu e-mail!", true); 
            } catch (error) { exibirAlerta("Erro ao enviar e-mail. Verifique a conectividade."); }
        });
        document.getElementById('registerForm').addEventListener('submit', async (e) => {
            e.preventDefault(); isSubmitting = true;
            const btn = document.getElementById('btn-do-register'); btn.innerText = "Processando..."; btn.disabled = true;
            const data = {
                email: document.getElementById('reg-email').value.trim(),
                password: document.getElementById('reg-pass').value,
                passwordConfirm: document.getElementById('reg-pass').value,
                name: document.getElementById('reg-nome').value.trim() + ' ' + document.getElementById('reg-sobrenome').value.trim(),
                empresa: document.getElementById('reg-empresa').value.trim(),
                telefone: document.getElementById('reg-telefone').value.trim(),
                status: "ativo", nivelAcesso: "cliente", faturaPendente: 0
            };
            try {
                await pb.collection('users').create(data);
                await pb.collection('users').authWithPassword(data.email, data.password);
                exibirAlerta("Conta provisionada! Redirecionando...", true);
                setTimeout(() => { window.location.replace("dashboard.html"); }, 1500);
            } catch (error) {
                isSubmitting = false;
                exibirAlerta("Erro no provisionamento. E-mail já existe na base.");
                btn.innerText = "Solicitar Acesso"; btn.disabled = false;
            }
        });
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault(); isSubmitting = true;
            const btn = document.getElementById('btn-do-login'); btn.innerText = "Autenticando..."; btn.disabled = true;
            try {
                await pb.collection('users').authWithPassword(
                    document.getElementById('log-email').value.trim(), 
                    document.getElementById('log-pass').value
                );
                exibirAlerta("Acesso liberado! Redirecionando...", true);
                setTimeout(() => { window.location.replace("dashboard.html"); }, 1000);
            } catch (error) {
                isSubmitting = false; 
                exibirAlerta("Credenciais inválidas ou infraestrutura inacessível.");
                btn.innerText = "Acessar Painel"; btn.disabled = false;
            }
        });
    </script>
</body>
</html>
EOF

# Assegura o UTF-8 (redundante, porém garante a sanitização do charset)
iconv -f ISO-8859-1 -t UTF-8 crm.html -o crm.html.utf8
mv crm.html.utf8 crm.html
chown 1500:1500 crm.html
chmod 644 crm.html

echo "[*] ====================================================================="
echo "[*] DEPLOY DO TRINITY ENGINE CONCLUÍDO COM SUCESSO!"
echo "[*] Serviços Operacionais na rede isolada 'trinity_net'."
echo "[*] ====================================================================="
