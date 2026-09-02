#!/usr/bin/env bash
# ==============================================================================
# РЎРєСЂРёРїС‚ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРѕРіРѕ СЂР°Р·РІРµСЂС‚С‹РІР°РЅРёСЏ SRE-СЃР»СѓР¶Р±С‹ СЂРѕС‚Р°С†РёРё РїСЂРѕС†РµСЃСЃРѕРІ
# ==============================================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[-] Р­С‚РѕС‚ СЃРєСЂРёРїС‚ РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ Р·Р°РїСѓС‰РµРЅ СЃ РїСЂР°РІР°РјРё root (sudo)!" >&2
   exit 1
fi

INSTALL_DIR="/opt/admincluster"
CONFIG_DIR="/etc/admincluster"

echo "[*] РџРѕРґРіРѕС‚РѕРІРєР° РґРёСЂРµРєС‚РѕСЂРёР№..."
mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}"

echo "[*] РљРѕРїРёСЂРѕРІР°РЅРёРµ РёСЃРїРѕР»РЅСЏРµРјС‹С… СЃРєСЂРёРїС‚РѕРІ РІ ${INSTALL_DIR}..."
cp admincluster_run.sh "${INSTALL_DIR}/"
cp admincluster_notify.sh "${INSTALL_DIR}/"
chmod +x "${INSTALL_DIR}"/*.sh

echo "[*] РЎРѕР·РґР°РЅРёРµ С„Р°Р№Р»Р° Р±Р°Р·РѕРІРѕР№ РєРѕРЅС„РёРіСѓСЂР°С†РёРё..."
cat << 'INNER_EOF' > "${CONFIG_DIR}/config.conf"
# /etc/admincluster/config.conf
# РўРѕРєРµРЅ Р±РѕС‚Р° Рё ID С†РµР»РµРІРѕРіРѕ С‡Р°С‚Р° РґРµР¶СѓСЂРЅРѕР№ DevOps-СЃРјРµРЅС‹
TELEGRAM_BOT_TOKEN="0000000000:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
TELEGRAM_CHAT_ID="-1001234567890"

# РђРґСЂРµСЃ РґР»СЏ РґСѓР±Р»РёСЂРѕРІР°РЅРёСЏ РєСЂРёС‚РёС‡РµСЃРєРёС… Р°Р»РµСЂС‚РѕРІ РЅР° РїРѕС‡С‚Сѓ
ALERT_EMAIL="ops-alerts@your-enterprise.com"

# РџСѓС‚Рё Рє СѓС‚РёР»РёС‚Р°Рј 1РЎ Рё RAS
EPF_PATH="/opt/admincluster/AdminClusterMonitor.epf"
HELPER_PATH="/opt/admincluster"
INNER_EOF

cat << 'INNER_EOF' > "${CONFIG_DIR}/profiles.json"
{
  "prod": {
    "Name": "prod",
    "RasHost": "127.0.0.1",
    "RasPort": 1545,
    "Description": "РџСЂРѕРґСѓРєС‚РёРІРЅС‹Р№ РєР»Р°СЃС‚РµСЂ 1РЎ"
  }
}
INNER_EOF

echo "[*] РЈСЃС‚Р°РЅРѕРІРєР° РѕРіСЂР°РЅРёС‡РµРЅРёР№ РїСЂР°РІ РґРѕСЃС‚СѓРїР° Рє СЃРµРєСЂРµС‚Р°Рј..."
chown -R root:root "${INSTALL_DIR}" "${CONFIG_DIR}"
chmod 750 "${INSTALL_DIR}"
chmod 640 "${CONFIG_DIR}"/*.conf "${CONFIG_DIR}"/*.json

echo "[*] Р РµРіРёСЃС‚СЂР°С†РёСЏ С€Р°Р±Р»РѕРЅРѕРІ Systemd..."
cp admincluster-monitor@.service /etc/systemd/system/
cp admincluster-monitor@.timer /etc/systemd/system/

systemctl daemon-reload

echo "[+] РЈСЃС‚Р°РЅРѕРІРєР° AdminClusterMonitor СѓСЃРїРµС€РЅРѕ Р·Р°РІРµСЂС€РµРЅР°."
echo "    1. РќР°СЃС‚СЂРѕР№С‚Рµ С‚РѕРєРµРЅС‹ Telegram РІ /etc/admincluster/config.conf"
echo "    2. Р—Р°РїСѓСЃС‚РёС‚Рµ С‚Р°Р№РјРµСЂ: sudo systemctl enable --now admincluster-monitor@prod.timer"
