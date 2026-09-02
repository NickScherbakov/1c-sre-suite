#!/usr/bin/env bash
# ==============================================================================
# РЎРєСЂРёРїС‚ РјРіРЅРѕРІРµРЅРЅРѕРіРѕ РѕРїРѕРІРµС‰РµРЅРёСЏ DevOps-РєРѕРјР°РЅРґС‹ РѕР± РёРЅС†РёРґРµРЅС‚Р°С… Рё СЂРѕС‚Р°С†РёРё РїСЂРѕС†РµСЃСЃРѕРІ
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

SUBJECT="вљ пёЏ [1C:SRE-РљРѕРЅС‚СѓСЂ] РћР±РЅР°СЂСѓР¶РµРЅС‹ 'РїРµСЂРµСЃС‚Р°СЂРєРё' rphost РІ РєР»Р°СЃС‚РµСЂРµ ${PROFILE}"
BODY="РЎРµСЂРІРµСЂ: $(hostname)
РџСЂРѕС„РёР»СЊ: ${PROFILE}

Р’С‹СЏРІР»РµРЅС‹ РїСЂРѕС†РµСЃСЃС‹ rphost, РїСЂРµРІС‹СЃРёРІС€РёРµ РґРѕРїСѓСЃС‚РёРјС‹Р№ РїРµСЂРёРѕРґ РЅРµРїСЂРµСЂС‹РІРЅРѕРіРѕ РёСЃРїРѕР»СЊР·РѕРІР°РЅРёСЏ Рё РЅРµ РёРјРµСЋС‰РёРµ Р°РєС‚РёРІРЅС‹С… СЃРѕРµРґРёРЅРµРЅРёР№.
Р—Р°РїСѓС‰РµРЅР° РїСЂРѕС†РµРґСѓСЂР° Р±РµР·РѕРїР°СЃРЅРѕР№ СЂРѕС‚Р°С†РёРё. РћС‚С‡РµС‚ РІС‹РіСЂСѓР¶РµРЅ РІ: ${FILE}"

if [[ $DRYRUN -eq 1 ]]; then
    logger -t admincluster-monitor "DRYRUN ALERT: ${SUBJECT}"
    echo "DRYRUN: РЈРІРµРґРѕРјР»РµРЅРёРµ СЃС„РѕСЂРјРёСЂРѕРІР°РЅРѕ, РЅРѕ РѕС‚РїСЂР°РІРєР° Р·Р°Р±Р»РѕРєРёСЂРѕРІР°РЅР°."
    exit 0
fi

# РћС‚РїСЂР°РІРєР° РѕРїРѕРІРµС‰РµРЅРёСЏ РІ Telegram-РєР°РЅР°Р»
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"         -d chat_id="${TELEGRAM_CHAT_ID}"         -d text="${SUBJECT}

${BODY}" >/dev/null 2>&1 || true
fi

# РћС‚РїСЂР°РІРєР° РґСѓР±Р»РёСЂСѓСЋС‰РµРіРѕ РїРёСЃСЊРјР° РЅР° РїРѕС‡С‚Сѓ РґРµР¶СѓСЂРЅРѕР№ СЃРјРµРЅС‹
if [[ -n "${ALERT_EMAIL:-}" ]]; then
    echo -e "${BODY}" | mail -s "${SUBJECT}" "${ALERT_EMAIL}" || true
fi

logger -t admincluster-monitor "РЈРІРµРґРѕРјР»РµРЅРёРµ РѕР± РёРЅС†РёРґРµРЅС‚Рµ СЂРѕС‚Р°С†РёРё РѕС‚РїСЂР°РІР»РµРЅРѕ РґР»СЏ ${PROFILE}"
