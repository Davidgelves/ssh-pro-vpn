#!/bin/bash
# Actualiza solo los modulos en /bin (y mueve cabecalho/bot/py a /etc/SSHPlus)
# desde GitHub. Mismo origen que Install/list.
# Uso en la VPS (root):
#   bash <(wget -qO- https://raw.githubusercontent.com/USER/REPO/main/script/update_bin_modulos.sh)
# O tras git push:
#   export SSHPLUS_GH_USER_REPO="usuario/repo"
#   bash script/update_bin_modulos.sh
#
# Por defecto: Davidgelves/ssh-pro-vpn (mismo repo que el instalador actual).
# Si copiaste el ejemplo "usuario/tu-repo" en /root/.bashrc o /etc/profile, quitalo o exporta el repo bueno.

set -euo pipefail

[[ "${EUID:-0}" -eq 0 ]] || {
	echo "Ejecutar como root."
	exit 1
}

# Quitar \r y espacios (copias desde Windows / .bashrc mal pegadas)
_sshplus_trim() {
	local r="${1:-}"
	r="${r//$'\r'/}"
	r="${r//$'\n'/}"
	r="${r#"${r%%[![:space:]]*}"}"
	r="${r%"${r##*[![:space:]]}"}"
	printf '%s' "$r"
}
SSHPLUS_GH_USER_REPO="$(_sshplus_trim "${SSHPLUS_GH_USER_REPO:-Davidgelves/ssh-pro-vpn}")"
[[ -z "$SSHPLUS_GH_USER_REPO" ]] && SSHPLUS_GH_USER_REPO="Davidgelves/ssh-pro-vpn"
SSHPLUS_GH_BRANCH="$(_sshplus_trim "${SSHPLUS_GH_BRANCH:-main}")"
[[ -z "$SSHPLUS_GH_BRANCH" ]] && SSHPLUS_GH_BRANCH="main"
# Placeholders del ejemplo (cualquier variante) — forzar repo real
_r_lc=$(printf '%s' "$SSHPLUS_GH_USER_REPO" | tr '[:upper:]' '[:lower:]')
if [[ "$_r_lc" == *usuario/tu-repo* ]] || [[ "$_r_lc" == "tu_usuario/tu_repo" ]] || [[ "$_r_lc" == "usuario/repo" ]]; then
	SSHPLUS_GH_USER_REPO="Davidgelves/ssh-pro-vpn"
fi
unset SSHPLUS_RAW
SSHPLUS_RAW="https://raw.githubusercontent.com/${SSHPLUS_GH_USER_REPO}/${SSHPLUS_GH_BRANCH}"

mkdir -p /etc/SSHPlus
rm -f /etc/SSHPlus/ShellBot.sh /etc/SSHPlus/cabecalho /etc/SSHPlus/open.py /etc/SSHPlus/proxy.py /etc/SSHPlus/wsproxy.py 2>/dev/null || true

_dir1='/bin'
_dir2='/etc/SSHPlus'
_mdls=("addhost" "ajuda" "sshplus_lang" "alterarlimite" "alterarsenha" "tcptweaker.sh" "gltunnel" "utili" "multi" "apache2menu" "check" "chuser" "limit" "rps_cpu" "attscript" "badvpn" "badpro" "badpro1" "badvpn2" "badvpn3" "banner" "bashtop" "ddos" "blocksite" "blockt" "blockuser" "bot" "botssh" "conexao" "criarteste" "criarusuario" "delhost" "delscript" "detalhes" "droplimiter" "expcleaner" "fr" "infousers" "inst-botteste" "initcheck" "instsqd" "limiter" "menu" "menub" "mudardata" "mtuning" "open.py" "otimizar" "painelv2ray" "proxy.py" "reiniciarservicos" "reiniciarsistema" "remover" "senharoot" "ShellBot.sh" "speedtest" "sshmonitor" "swapmemory" "trafegototal" "trojan-go" "uexpired" "userbackup" "verifatt" "verifbot" "v2raymanager" "webmin.sh" "websocket.sh" "wsproxy.py" "pkill.sh")

echo "[*] Origen: ${SSHPLUS_RAW}/Modulos/"
for _arq in ${_mdls[@]}; do
	[[ -e $_dir1/$_arq ]] && rm -f "$_dir1/$_arq"
	wget -qO "$_dir1/$_arq" "${SSHPLUS_RAW}/Modulos/$_arq" || {
		echo "[x] Fallo: $_arq"
		exit 1
	}
	chmod +x "$_dir1/$_arq"
done
# Solo mover si existen (cabecalho puede no estar en el repo)
for _f in cabecalho bot open.py proxy.py wsproxy.py; do
	[[ -e "$_dir1/$_f" ]] && mv -f "$_dir1/$_f" "$_dir2/"
done
_lvk=$(wget -qO- "${SSHPLUS_RAW}/Modulos/versao" || true)
if [[ -n "${_lvk:-}" ]]; then
	echo "$_lvk" | sed -n '1 p' | cut -d' ' -f2 >/bin/versao 2>/dev/null || true
	cat /bin/versao >/home/sshplus 2>/dev/null || true
fi
echo "[OK] Modulos actualizados en /bin (repo ${SSHPLUS_GH_USER_REPO} @ ${SSHPLUS_GH_BRANCH})."
