#!/usr/bin/env bash
# ==============================================================================
# Обертка запуска регулярного мониторинга процессов и поиска "перестарков"
# ==============================================================================

set -euo pipefail

CONFIG="/etc/admincluster/config.conf"
if [[ -f "$CONFIG" ]]; then
    . "$CONFIG"
else
    echo "[-] Конфиг $CONFIG не найден!" >&2
    exit 1
fi

PROFILE=""
DRYRUN=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile) PROFILE="$2"; shift 2;;
        --dry-run) DRYRUN=1; shift;;
        *) shift;;
    esac
done

if [[ -z "$PROFILE" ]]; then
    echo "[-] Ошибка: Не указан профиль (--profile NAME)" >&2
    exit 1
fi

LOG_TAG="admincluster-monitor"
logger -t "$LOG_TAG" "Запуск проверки профиля ${PROFILE} (dry-run=${DRYRUN})"

# В реальном промышленном контуре здесь запускается headless-обработка
# которая опрашивает RAS API (порт 1545), находит rphost у которого
# соединения == 0 и время жизни > 24ч, после чего переводит его в "off"
# и безопасно останавливает.

# Имитируем логику в рамках скрипта-обертки для systemd
echo "[*] Опрос RAS API для профиля ${PROFILE}..."
# Имитация нахождения проблемного процесса:
STALE_FOUND=0

if [[ $STALE_FOUND -eq 1 ]]; then
    /opt/admincluster/admincluster_notify.sh --profile "$PROFILE" --file "/var/log/stale_report.csv"
fi

echo "[+] Проверка профиля ${PROFILE} завершена."
