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

mem_total="$(free -h | awk '/Mem:/ {print $2}')"
mem_used_pct="$(free | awk '/Mem:/ {printf "%.2f%%", ($3/$2)*100}')"
cpu_used_pct="$(top -bn1 | awk -F',' '/Cpu\(s\)/ {gsub("%id","",$4); gsub(" ","",$4); printf "%.1f%%", 100-$4; exit}')"
cpu_cores="$(nproc)"
host_name="$(hostname)"
up_time="$(uptime -p)"
now_date="$(date '+%d-%m-%y')"
now_time="$(date '+%T')"

is_badvpn_on() {
  systemctl is-active badvpn-udpgw >/dev/null 2>&1
}

draw_panel() {
  clear
  echo -e "${RED}===============================================================${NC}"
  echo -e "${WHITE}                 SSH-PRO ${CYAN}@DAVIDGELVES${NC}"
  echo -e "${RED}===============================================================${NC}"
  echo -e "${GREEN}NOMBRE DEL SERVIDOR${NC}: ${WHITE}${host_name}${NC}"
  echo -e "${GREEN}SERVIDOR ENCENDIDO${NC}: ${WHITE}${up_time}${NC}"
  echo -e "${GREEN}FECHA${NC}: ${WHITE}${now_date}${NC}    ${GREEN}HORA${NC}: ${WHITE}${now_time}${NC}"
  echo -e "${RED}---------------------------------------------------------------${NC}"
  echo -e "${CYAN}SISTEMA${NC}      RAM: ${WHITE}${mem_total}${NC} (${YELLOW}${mem_used_pct}${NC})   CPU: ${WHITE}${cpu_cores}${NC} cores (${YELLOW}${cpu_used_pct}${NC})"
  echo -e "${RED}---------------------------------------------------------------${NC}"
  echo -e "${WHITE}[01]${NC} Ver estado BadVPN            ${WHITE}[12]${NC} Speedtest (proximamente)"
  echo -e "${WHITE}[02]${NC} Reiniciar BadVPN             ${WHITE}[13]${NC} Banner (proximamente)"
  echo -e "${WHITE}[03]${NC} Ver logs BadVPN              ${WHITE}[14]${NC} Trafico (proximamente)"
  echo -e "${WHITE}[04]${NC} Puerto en escucha            ${WHITE}[15]${NC} Optimizar (proximamente)"
  echo -e "${WHITE}[05]${NC} Estado systemd completo      ${WHITE}[16]${NC} Backup (proximamente)"
  echo -e "${WHITE}[06]${NC} Habilitar autostart          ${WHITE}[17]${NC} Herramientas (proximamente)"
  echo -e "${WHITE}[07]${NC} Deshabilitar autostart       ${WHITE}[18]${NC} Limiter (proximamente)"
  if is_badvpn_on; then
    echo -e "${WHITE}[08]${NC} Menu BadVPN ${GREEN}(ON)${NC}            ${WHITE}[19]${NC} Firewall (proximamente)"
  else
    echo -e "${WHITE}[08]${NC} Menu BadVPN ${RED}(OFF)${NC}           ${WHITE}[19]${NC} Firewall (proximamente)"
  fi
  echo -e "${WHITE}[09]${NC} Detener BadVPN              ${WHITE}[20]${NC} Info VPS (proximamente)"
  echo -e "${WHITE}[10]${NC} Iniciar BadVPN              ${WHITE}[21]${NC} Checkuser (proximamente)"
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
    1) show_status_short; read -r -p "Enter para continuar..." _ ;;
    2) systemctl restart badvpn-udpgw && echo "Reiniciado."; sleep 1 ;;
    3) journalctl -u badvpn-udpgw -f ;;
    4) show_port; read -r -p "Enter para continuar..." _ ;;
    5) systemctl --no-pager --full status badvpn-udpgw.service || true; read -r -p "Enter para continuar..." _ ;;
    6) systemctl enable badvpn-udpgw && echo "Autostart habilitado."; sleep 1 ;;
    7) systemctl disable badvpn-udpgw && echo "Autostart deshabilitado."; sleep 1 ;;
    8) show_status_short; read -r -p "Enter para continuar..." _ ;;
    9) systemctl stop badvpn-udpgw && echo "Servicio detenido."; sleep 1 ;;
    10) systemctl start badvpn-udpgw && echo "Servicio iniciado."; sleep 1 ;;
    11)
      echo "Comandos utiles:"
      echo "  systemctl status badvpn-udpgw"
      echo "  journalctl -u badvpn-udpgw -f"
      echo "  ss -lntp | grep 7300"
      read -r -p "Enter para continuar..." _
      ;;
    12|13|14|15|16|17|18|19|20|21|22) echo "Opcion en desarrollo."; sleep 1 ;;
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
