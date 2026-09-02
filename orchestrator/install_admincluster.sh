#!/usr/bin/env bash
# ==============================================================================
# Скрипт автоматического развертывания SRE-службы ротации процессов
# ==============================================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[-] Этот скрипт должен быть запущен с правами root (sudo)!" >&2
   exit 1
fi

INSTALL_DIR="/opt/admincluster"
CONFIG_DIR="/etc/admincluster"

echo "[*] Подготовка директорий..."
mkdir -p "${INSTALL_DIR}" "${CONFIG_DIR}"

echo "[*] Копирование исполняемых скриптов в ${INSTALL_DIR}..."
cp admincluster_run.sh "${INSTALL_DIR}/"
cp admincluster_notify.sh "${INSTALL_DIR}/"
chmod +x "${INSTALL_DIR}"/*.sh

echo "[*] Создание файла базовой конфигурации..."
cat << 'INNER_EOF' > "${CONFIG_DIR}/config.conf"
# /etc/admincluster/config.conf
# Токен бота и ID целевого чата дежурной DevOps-смены
TELEGRAM_BOT_TOKEN="0000000000:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
TELEGRAM_CHAT_ID="-1001234567890"

# Адрес для дублирования критических алертов на почту
ALERT_EMAIL="ops-alerts@your-enterprise.com"

# Пути к утилитам 1С и RAS
EPF_PATH="/opt/admincluster/AdminClusterMonitor.epf"
HELPER_PATH="/opt/admincluster"
INNER_EOF

cat << 'INNER_EOF' > "${CONFIG_DIR}/profiles.json"
{
  "prod": {
    "Name": "prod",
    "RasHost": "127.0.0.1",
    "RasPort": 1545,
    "Description": "Продуктивный кластер 1С"
  }
}
INNER_EOF

echo "[*] Установка ограничений прав доступа к секретам..."
chown -R root:root "${INSTALL_DIR}" "${CONFIG_DIR}"
chmod 750 "${INSTALL_DIR}"
chmod 640 "${CONFIG_DIR}"/*.conf "${CONFIG_DIR}"/*.json

echo "[*] Регистрация шаблонов Systemd..."
cp admincluster-monitor@.service /etc/systemd/system/
cp admincluster-monitor@.timer /etc/systemd/system/

systemctl daemon-reload

echo "[+] Установка AdminClusterMonitor успешно завершена."
echo "    1. Настройте токены Telegram в /etc/admincluster/config.conf"
echo "    2. Запустите таймер: sudo systemctl enable --now admincluster-monitor@prod.timer"
