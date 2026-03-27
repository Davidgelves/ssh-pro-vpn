#!/usr/bin/env bash
set -Eeuo pipefail

# Instalador seguro de badvpn-udpgw para Debian/Ubuntu.
# - No descarga binarios opacos de terceros.
# - Compila desde fuente oficial.
# - Configura servicio systemd (sin screen ni /etc/autostart).

detect_lang() {
  local raw="${LANG_CHOICE:-${LANG:-es}}"
  case "${raw,,}" in
    en|en_*|english) echo "en" ;;
    *) echo "es" ;;
  esac
}

LANG_SELECTED="$(detect_lang)"

tr() {
  local key="$1"
  if [[ "${LANG_SELECTED}" == "en" ]]; then
    case "${key}" in
      must_root) echo "This script must run as root." ;;
      only_apt) echo "Compatible only with Debian/Ubuntu (apt)." ;;
      s1) echo "[1/6] Installing dependencies..." ;;
      s2) echo "[2/6] Downloading official source code..." ;;
      s3) echo "[3/6] Building badvpn-udpgw..." ;;
      missing_bin) echo "Could not find ${BIN_PATH} after installation." ;;
      s4) echo "[4/6] Creating service user..." ;;
      s5) echo "[5/6] Creating systemd service..." ;;
      s6) echo "[6/6] Enabling and starting service..." ;;
      done) echo "Installation completed." ;;
      binary) echo "Binary: ${BIN_PATH}" ;;
      service) echo "Service: badvpn-udpgw.service" ;;
      port) echo "Port: ${LISTEN_ADDR}:${PORT}" ;;
      useful) echo "Useful commands:" ;;
      creating_menu) echo "Creating secure menu command..." ;;
      menu_ready) echo "Command ready: menu" ;;
    esac
  else
    case "${key}" in
      must_root) echo "Este script debe ejecutarse como root." ;;
      only_apt) echo "Solo compatible con Debian/Ubuntu (apt)." ;;
      s1) echo "[1/6] Instalando dependencias..." ;;
      s2) echo "[2/6] Descargando codigo fuente oficial..." ;;
      s3) echo "[3/6] Compilando badvpn-udpgw..." ;;
      missing_bin) echo "No se encontro ${BIN_PATH} despues de la instalacion." ;;
      s4) echo "[4/6] Creando usuario de servicio..." ;;
      s5) echo "[5/6] Creando servicio systemd..." ;;
      s6) echo "[6/6] Habilitando y arrancando servicio..." ;;
      done) echo "Instalacion completada." ;;
      binary) echo "Binario: ${BIN_PATH}" ;;
      service) echo "Servicio: badvpn-udpgw.service" ;;
      port) echo "Puerto: ${LISTEN_ADDR}:${PORT}" ;;
      useful) echo "Comandos utiles:" ;;
      creating_menu) echo "Creando comando de menu seguro..." ;;
      menu_ready) echo "Comando listo: menu" ;;
    esac
  fi
}

install_safe_menu() {
  echo "$(tr creating_menu)"
  cat > "${MENU_PATH}" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

aptq() { DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
is_on() { systemctl is-active "$1" >/dev/null 2>&1; }
mark() { is_on "$1" && printf "${GREEN}o${NC}" || printf "${RED}x${NC}"; }
pause() { read -r -p "Pressione ENTER para continuar..." _; }

setup_squid() {
  aptq squid
  cat > /etc/squid/squid.conf <<'SQUID'
http_port 3128
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localhost src 127.0.0.1/32
http_access allow localnet
http_access allow localhost
http_access deny all
cache deny all
SQUID
  systemctl enable --now squid
}

setup_dropbear() {
  aptq dropbear
  sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear || true
  sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=442/' /etc/default/dropbear || true
  systemctl enable --now dropbear
}

setup_socks() {
  aptq dante-server
  cat > /etc/danted.conf <<'DANTE'
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 1080
external: eth0
socksmethod: none
clientmethod: none
user.privileged: root
user.unprivileged: nobody
client pass { from: 0.0.0.0/0 to: 0.0.0.0/0 }
socks pass { from: 0.0.0.0/0 to: 0.0.0.0/0 protocol: tcp udp }
DANTE
  systemctl enable --now danted || true
}

setup_stunnel() {
  aptq stunnel4 openssl
  mkdir -p /etc/stunnel
  [[ -f /etc/stunnel/stunnel.pem ]] || {
    openssl req -new -x509 -days 3650 -nodes -subj "/CN=$(hostname)" -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem >/dev/null 2>&1
    chmod 600 /etc/stunnel/stunnel.pem
  }
  cat > /etc/stunnel/stunnel.conf <<'STUNNEL'
pid=/var/run/stunnel4.pid
setuid=stunnel4
setgid=stunnel4
[sslssh]
accept=443
connect=127.0.0.1:22
cert=/etc/stunnel/stunnel.pem
STUNNEL
  sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/stunnel4 || true
  systemctl enable --now stunnel4
}

draw_main() {
  local mem_total mem_pct cpu_pct cpu_cores
  mem_total="$(free -h | awk '/Mem:/ {print $2}')"
  mem_pct="$(free | awk '/Mem:/ {printf "%.2f%%", ($3/$2)*100}')"
  cpu_pct="$(top -bn1 | awk -F',' '/Cpu\(s\)/ {gsub("%id","",$4); gsub(" ","",$4); printf "%.1f%%", 100-$4; exit}')"
  cpu_cores="$(nproc)"
  clear
  echo -e "${WHITE}   ${BLUE}SSH-PLUS @ALFAINTERNET${NC}"
  echo -e "${RED}============================================================${NC}"
  echo -e "${GREEN} SISTEMA${NC}      OS: $(. /etc/os-release && echo "$NAME" "$VERSION_ID")"
  echo -e "${GREEN} MEMORIA RAM${NC}  Total: ${mem_total}   Em uso: ${mem_pct}"
  echo -e "${GREEN} PROCESSADOR${NC}  Nucleos: ${cpu_cores}   Em uso: ${cpu_pct}"
  echo -e "${RED}------------------------------------------------------------${NC}"
  echo -e "[01] - CRIAR USUARIO          [12] - SPEEDTEST"
  echo -e "[02] - CRIAR TESTE            [13] - BANNER"
  echo -e "[03] - REMOVER USUARIO        [14] - TRAFEGO"
  echo -e "[04] - MONITOR ONLINE         [15] - OTIMIZAR"
  echo -e "[05] - MUDAR DATA             [16] - BACKUP"
  echo -e "[06] - ALTERAR LIMITE         [17] - FERRAMENTAS"
  echo -e "[07] - MUDAR SENHA            [18] - LIMITER (OFF)"
  echo -e "[08] - REMOVER EXPIRADOS      [19] - Menu BadVpn ($(mark badvpn-udpgw))"
  echo -e "[09] - RELATORIO DE USUARIOS  [20] - FIREWALL"
  echo -e "[10] - MODO DE CONEXAO        [21] - INFO VPS"
  echo -e "[11] - CRIAR MEMORIA SWAP     [22] - CHECKUSER 4G"
  echo -e "[ G ] - CHECKUSER GLTUNNEL    [23] - MAIS >>>"
  echo -e "[ 0 ] - SAIR"
  echo -e "${RED}============================================================${NC}"
}

draw_conexao() {
  clear
  echo -e "${WHITE}Ubuntu $(. /etc/os-release && echo "$VERSION_ID")${NC}    ${WHITE}$(date '+%Y-%m-%d <> %T')${NC}"
  echo -e "${BLUE}                         CONEXAO${NC}"
  echo -e "${RED}============================================================${NC}"
  echo -e "SERVICO: OPENSSH PORTA: 22"
  echo -e "SERVICO: PROXY SOCKS PORTA: 1080"
  echo -e "SERVICO: SSL TUNNEL PORTA: 443"
  echo -e "${RED}------------------------------------------------------------${NC}"
  echo -e "[ 01 ] -> OPENSSH      $(mark ssh)"
  echo -e "[ 02 ] -> SQUID PROXY  $(mark squid)"
  echo -e "[ 03 ] -> DROPBEAR     $(mark dropbear)"
  echo -e "[ 04 ] -> OPENVPN      $(mark openvpn)"
  echo -e "[ 05 ] -> PROXY SOCKS  $(mark danted)"
  echo -e "[ 06 ] -> SSL TUNNEL   $(mark stunnel4)"
  echo -e "[ 07 ] -> SSLH MULTIPLEX (desativado seguro)"
  echo -e "[ 08 ] -> CHISEL (desativado seguro)"
  echo -e "[ 09 ] -> SLOWDNS (desativado seguro)"
  echo -e "[ 10 ] -> V2RAY (desativado seguro)"
  echo -e "[ 11 ] -> TROJAN-GO (desativado seguro)"
  echo -e "[ 12 ] -> WEBSOCKET (desativado seguro)"
  echo -e "[ 00 ] -> VOLTAR <<<"
  echo -e "${RED}============================================================${NC}"
}

conexao_menu() {
  while true; do
    draw_conexao
    read -r -p "ESCOLHA OPCAO: " c
    case "$c" in
      1|01) aptq openssh-server && systemctl enable --now ssh ;;
      2|02) setup_squid ;;
      3|03) setup_dropbear ;;
      4|04) aptq openvpn && systemctl enable --now openvpn || true ;;
      5|05) setup_socks ;;
      6|06) setup_stunnel ;;
      7|8|9|10|11|12) echo "Opcao bloqueada no modo seguro."; sleep 1 ;;
      0|00) return ;;
      *) echo "Opcao invalida."; sleep 1 ;;
    esac
  done
}

while true; do
  draw_main
  read -r -p "INFORME UMA OPCAO : " opt
  case "$opt" in
    10) conexao_menu ;;
    12) aptq speedtest-cli || true; speedtest || true; pause ;;
    19) systemctl --no-pager --full status badvpn-udpgw.service | sed -n '1,10p'; pause ;;
    20) aptq ufw; ufw status verbose; pause ;;
    21) uname -a; free -h; df -h; pause ;;
    0) exit 0 ;;
    *) echo "Opcao em desenvolvimento (modo seguro)."; sleep 1 ;;
  esac
done
EOF
  chmod 750 "${MENU_PATH}"
  ln -sf "${MENU_PATH}" "${MENU_PATH_SBIN}"
  echo "$(tr menu_ready)"
}

BADVPN_VERSION="${BADVPN_VERSION:-1.999.130}"
LISTEN_ADDR="${LISTEN_ADDR:-127.0.0.1}"
PORT="${PORT:-7300}"
MAX_CLIENTS="${MAX_CLIENTS:-1000}"
MAX_CONN_PER_CLIENT="${MAX_CONN_PER_CLIENT:-8}"
SND_BUF="${SND_BUF:-10000}"
INSTALL_PREFIX="/usr/local"
WORKDIR="/usr/local/src"
ARCHIVE="badvpn-${BADVPN_VERSION}.tar.gz"
SRC_DIR="badvpn-${BADVPN_VERSION}"
REPO_ARCHIVE_URL="https://github.com/ambrop72/badvpn/archive/refs/tags/${BADVPN_VERSION}.tar.gz"
BIN_PATH="${INSTALL_PREFIX}/bin/badvpn-udpgw"
SERVICE_PATH="/etc/systemd/system/badvpn-udpgw.service"
MENU_PATH="/usr/local/bin/menu"
MENU_PATH_SBIN="/usr/local/sbin/menu"

if [[ "${EUID}" -ne 0 ]]; then
  echo "$(tr must_root)"
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "$(tr only_apt)"
  exit 1
fi

echo "$(tr s1)"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  curl \
  build-essential \
  cmake \
  pkg-config \
  git \
  libssl-dev \
  zlib1g-dev \
  systemd

echo "$(tr s2)"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"
rm -rf "${SRC_DIR}" "${ARCHIVE}" "${SRC_DIR}-build"
curl -fL "${REPO_ARCHIVE_URL}" -o "${ARCHIVE}"
tar -xzf "${ARCHIVE}"

echo "$(tr s3)"
mkdir -p "${SRC_DIR}-build"
cd "${SRC_DIR}-build"
cmake "../${SRC_DIR}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
  -DBUILD_NOTHING_BY_DEFAULT=1 \
  -DBUILD_UDPGW=1
make -j"$(nproc)"
make install

if [[ ! -x "${BIN_PATH}" ]]; then
  echo "$(tr missing_bin)"
  exit 1
fi

echo "$(tr s4)"
if ! id -u badvpn >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin badvpn
fi

echo "$(tr s5)"
cat > "${SERVICE_PATH}" <<EOF
[Unit]
Description=BadVPN UDPGW service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=badvpn
Group=badvpn
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${BIN_PATH} --listen-addr ${LISTEN_ADDR}:${PORT} --max-clients ${MAX_CLIENTS} --max-connections-for-client ${MAX_CONN_PER_CLIENT} --client-socket-sndbuf ${SND_BUF}
Restart=on-failure
RestartSec=3
LimitNOFILE=32768

[Install]
WantedBy=multi-user.target
EOF

echo "$(tr s6)"
systemctl daemon-reload
systemctl enable --now badvpn-udpgw.service
systemctl --no-pager --full status badvpn-udpgw.service || true
install_safe_menu

echo
echo "$(tr done)"
echo "$(tr binary)"
echo "$(tr service)"
echo "$(tr port)"
echo
echo "$(tr useful)"
echo "  systemctl status badvpn-udpgw"
echo "  journalctl -u badvpn-udpgw -f"
echo "  ss -lntp | grep ${PORT}"
