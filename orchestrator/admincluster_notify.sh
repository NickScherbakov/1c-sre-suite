#!/usr/bin/env bash
# ==============================================================================
# Скрипт мгновенного оповещения DevOps-команды об инцидентах и ротации процессов
# ==============================================================================

set -euo pipefail

CONFIG="/etc/admincluster/config.conf"
if [[ -f "$CONFIG" ]]; then
    . "$CONFIG"
fi

DRYRUN=0
FILE=""
PROFILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --file) FILE="$2"; shift 2;;
        --profile) PROFILE="$2"; shift 2;;
        --dry-run) DRYRUN=1; shift;;
        *) shift;;
    esac
done

SUBJECT="⚠️ [1C:SRE-Контур] Обнаружены 'перестарки' rphost в кластере ${PROFILE}"
BODY="Сервер: $(hostname)
Профиль: ${PROFILE}

Выявлены процессы rphost, превысившие допустимый период непрерывного использования и не имеющие активных соединений.
Запущена процедура безопасной ротации. Отчет выгружен в: ${FILE}"

if [[ $DRYRUN -eq 1 ]]; then
    logger -t admincluster-monitor "DRYRUN ALERT: ${SUBJECT}"
    echo "DRYRUN: Уведомление сформировано, но отправка заблокирована."
    exit 0
fi

# Отправка оповещения в Telegram-канал
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"         -d chat_id="${TELEGRAM_CHAT_ID}"         -d text="${SUBJECT}

${BODY}" >/dev/null 2>&1 || true
fi

# Отправка дублирующего письма на почту дежурной смены
if [[ -n "${ALERT_EMAIL:-}" ]]; then
    echo -e "${BODY}" | mail -s "${SUBJECT}" "${ALERT_EMAIL}" || true
fi

logger -t admincluster-monitor "Уведомление об инциденте ротации отправлено для ${PROFILE}"
