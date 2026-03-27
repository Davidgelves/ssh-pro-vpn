# SSH-PLUS (version saneada)

Este proyecto fue ajustado para uso mas seguro de BadVPN UDPGW en Debian/Ubuntu.

## Cambios de seguridad

- Se elimino el flujo de instalacion por `bash <(wget ...)`.
- El entrypoint `ssh-plus` ya no descarga ni ejecuta scripts remotos.
- Se usa instalador local: `instalar-badvpn-seguro.sh`.
- Se configura `systemd` en lugar de `screen` + `/etc/autostart`.
- No se usa `chmod 777`.

## Instalacion recomendada

Copiar la carpeta al VPS y ejecutar:

```bash
chmod +x ./ssh-plus ./instalar-badvpn-seguro.sh
sudo ./ssh-plus
```

## Idioma / Language

El instalador permite seleccionar idioma al iniciar:

- `1` Espanol
- `2` English

Tambien puedes forzar idioma por variable:

```bash
sudo LANG_CHOICE=es ./ssh-plus
sudo LANG_CHOICE=en ./ssh-plus
```

## Variables opcionales

```bash
sudo PORT=7301 MAX_CLIENTS=2000 ./instalar-badvpn-seguro.sh
```

## Verificacion

```bash
systemctl status badvpn-udpgw
journalctl -u badvpn-udpgw -f
ss -lntp | grep 7300
```
