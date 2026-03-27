#!/usr/bin/env bash
set -Eeuo pipefail

# Instalador seguro de badvpn-udpgw para Debian/Ubuntu.
# - No descarga binarios opacos de terceros.
# - Compila desde fuente oficial.
# - Configura servicio systemd (sin screen ni /etc/autostart).

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

if [[ "${EUID}" -ne 0 ]]; then
  echo "Este script debe ejecutarse como root."
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Solo compatible con Debian/Ubuntu (apt)."
  exit 1
fi

echo "[1/6] Instalando dependencias..."
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

echo "[2/6] Descargando codigo fuente oficial..."
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"
rm -rf "${SRC_DIR}" "${ARCHIVE}" "${SRC_DIR}-build"
curl -fL "${REPO_ARCHIVE_URL}" -o "${ARCHIVE}"
tar -xzf "${ARCHIVE}"

echo "[3/6] Compilando badvpn-udpgw..."
mkdir -p "${SRC_DIR}-build"
cd "${SRC_DIR}-build"
cmake "../${SRC_DIR}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
  -DBUILD_NOTHING_BY_DEFAULT=1 \
  -DBUILD_UDPGW=1
make -j"$(nproc)"
make install

if [[ ! -x "${BIN_PATH}" ]]; then
  echo "No se encontro ${BIN_PATH} despues de la instalacion."
  exit 1
fi

echo "[4/6] Creando usuario de servicio..."
if ! id -u badvpn >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin badvpn
fi

echo "[5/6] Creando servicio systemd..."
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

echo "[6/6] Habilitando y arrancando servicio..."
systemctl daemon-reload
systemctl enable --now badvpn-udpgw.service
systemctl --no-pager --full status badvpn-udpgw.service || true

echo
echo "Instalacion completada."
echo "Binario: ${BIN_PATH}"
echo "Servicio: badvpn-udpgw.service"
echo "Puerto: ${LISTEN_ADDR}:${PORT}"
echo
echo "Comandos utiles:"
echo "  systemctl status badvpn-udpgw"
echo "  journalctl -u badvpn-udpgw -f"
echo "  ss -lntp | grep ${PORT}"
