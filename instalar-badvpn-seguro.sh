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

service_on() {
  local s="$1"
  systemctl is-active "$s" >/dev/null 2>&1
}

svc_mark() {
  if service_on "$1"; then
    printf "${GREEN}o${NC}"
  else
    printf "${RED}x${NC}"
  fi
}

install_pkg() {
  local pkg="$1"
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
}

setup_squid_minimal() {
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
access_log stdio:/var/log/squid/access.log
SQUID
}

install_openssh() {
  install_pkg openssh-server
  systemctl enable --now ssh
}

install_squid() {
  install_pkg squid
  setup_squid_minimal
  systemctl enable --now squid
}

install_dropbear() {
  install_pkg dropbear
  sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear || true
  sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=442/' /etc/default/dropbear || true
  systemctl enable --now dropbear
}

install_openvpn() {
  install_pkg openvpn
  systemctl enable --now openvpn || true
}

install_dante() {
  install_pkg dante-server
  cat > /etc/danted.conf <<'DANTE'
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 1080
external: eth0
socksmethod: none
clientmethod: none
user.privileged: root
user.unprivileged: nobody
client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: connect error
}
socks pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  protocol: tcp udp
  log: connect error
}
DANTE
  systemctl enable --now danted || systemctl enable --now danted.service || true
}

install_stunnel() {
  install_pkg stunnel4
  mkdir -p /etc/stunnel
  if [[ ! -f /etc/stunnel/stunnel.pem ]]; then
    openssl req -new -x509 -days 3650 -nodes \
      -subj "/CN=$(hostname)" \
      -out /etc/stunnel/stunnel.pem \
      -keyout /etc/stunnel/stunnel.pem >/dev/null 2>&1
    chmod 600 /etc/stunnel/stunnel.pem
  fi
  cat > /etc/stunnel/stunnel.conf <<'STUNNEL'
pid = /var/run/stunnel4.pid
setuid = stunnel4
setgid = stunnel4
foreground = no
debug = 3
[sslssh]
accept = 443
connect = 127.0.0.1:22
cert = /etc/stunnel/stunnel.pem
STUNNEL
  sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/stunnel4 || true
  systemctl enable --now stunnel4
}

draw_panel() {
  local mem_total mem_used_pct cpu_used_pct cpu_cores host_name up_time now_date now_time
  mem_total="$(free -h | awk '/Mem:/ {print $2}')"
  mem_used_pct="$(free | awk '/Mem:/ {printf "%.2f%%", ($3/$2)*100}')"
  cpu_used_pct="$(top -bn1 | awk -F',' '/Cpu\(s\)/ {gsub("%id","",$4); gsub(" ","",$4); printf "%.1f%%", 100-$4; exit}')"
  cpu_cores="$(nproc)"
  host_name="$(hostname)"
  up_time="$(uptime -p)"
  now_date="$(date '+%d-%m-%y')"
  now_time="$(date '+%T')"

  clear
  echo -e "${RED}===============================================================${NC}"
  echo -e "${WHITE}                 SSH-PRO ${CYAN}PANEL SEGURO${NC}"
  echo -e "${RED}===============================================================${NC}"
  echo -e "${GREEN}NOMBRE DEL SERVIDOR${NC}: ${WHITE}${host_name}${NC}"
  echo -e "${GREEN}SERVIDOR ENCENDIDO${NC}: ${WHITE}${up_time}${NC}"
  echo -e "${GREEN}FECHA${NC}: ${WHITE}${now_date}${NC}    ${GREEN}HORA${NC}: ${WHITE}${now_time}${NC}"
  echo -e "${RED}---------------------------------------------------------------${NC}"
  echo -e "${CYAN}SISTEMA${NC}      RAM: ${WHITE}${mem_total}${NC} (${YELLOW}${mem_used_pct}${NC})   CPU: ${WHITE}${cpu_cores}${NC} cores (${YELLOW}${cpu_used_pct}${NC})"
  echo -e "${RED}---------------------------------------------------------------${NC}"
  echo -e "${WHITE}[01]${NC} OpenSSH        [$(svc_mark ssh)]   ${WHITE}[12]${NC} Speedtest"
  echo -e "${WHITE}[02]${NC} Squid Proxy    [$(svc_mark squid)]   ${WHITE}[13]${NC} Banner (proximamente)"
  echo -e "${WHITE}[03]${NC} Dropbear       [$(svc_mark dropbear)]   ${WHITE}[14]${NC} Trafico (proximamente)"
  echo -e "${WHITE}[04]${NC} OpenVPN        [$(svc_mark openvpn)]   ${WHITE}[15]${NC} Optimizar (proximamente)"
  echo -e "${WHITE}[05]${NC} Proxy Socks    [$(svc_mark danted)]   ${WHITE}[16]${NC} Backup (proximamente)"
  echo -e "${WHITE}[06]${NC} SSL Tunnel     [$(svc_mark stunnel4)]   ${WHITE}[17]${NC} Herramientas (proximamente)"
  echo -e "${WHITE}[07]${NC} BadVPN Estado  [$(svc_mark badvpn-udpgw)]   ${WHITE}[18]${NC} Limiter (proximamente)"
  echo -e "${WHITE}[08]${NC} BadVPN Reiniciar            ${WHITE}[19]${NC} Firewall (proximamente)"
  echo -e "${WHITE}[09]${NC} BadVPN Logs                 ${WHITE}[20]${NC} Info VPS"
  echo -e "${WHITE}[10]${NC} Puertos en escucha          ${WHITE}[21]${NC} V2Ray/Trojan (en desarrollo seguro)"
  echo -e "${WHITE}[11]${NC} Ayuda comandos              ${WHITE}[22]${NC} Mas (proximamente)"
  echo -e "${WHITE}[ 0]${NC} Salir"
  echo -e "${RED}===============================================================${NC}"
}

show_status_short() {
  systemctl --no-pager --full status badvpn-udpgw.service | sed -n '1,10p' || true
}

show_port() {
  ss -lntp | grep -E "badvpn-udpgw|:7300|:7301|:7302" || true
}

while true; do
  draw_panel
  read -r -p "INFORME UNA OPCION: " opt
  case "${opt}" in
    1) install_openssh; sleep 1 ;;
    2) install_squid; sleep 1 ;;
    3) install_dropbear; sleep 1 ;;
    4) install_openvpn; sleep 1 ;;
    5) install_dante; sleep 1 ;;
    6) install_stunnel; sleep 1 ;;
    7) show_status_short; read -r -p "Enter para continuar..." _ ;;
    8) systemctl restart badvpn-udpgw && echo "BadVPN reiniciado."; sleep 1 ;;
    9) journalctl -u badvpn-udpgw -f ;;
    10) show_port; read -r -p "Enter para continuar..." _ ;;
    11)
      echo "Comandos utiles:"
      echo "  menu"
      echo "  systemctl status ssh squid dropbear openvpn stunnel4 danted badvpn-udpgw"
      echo "  systemctl status badvpn-udpgw"
      echo "  journalctl -u badvpn-udpgw -f"
      echo "  ss -lntp | grep 7300"
      read -r -p "Enter para continuar..." _
      ;;
    12) install_pkg speedtest-cli || true; speedtest || true; read -r -p "Enter para continuar..." _ ;;
    13|14|15|16|17|18|19) echo "Opcion en desarrollo."; sleep 1 ;;
    20) uname -a; lsb_release -a 2>/dev/null || true; read -r -p "Enter para continuar..." _ ;;
    21|22) echo "Opcion en desarrollo seguro."; sleep 1 ;;
    0) exit 0 ;;
    *) echo "Opcion invalida"; sleep 1 ;;
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
