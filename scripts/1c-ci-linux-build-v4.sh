#!/usr/bin/env bash
# ==============================================================================
# Скрипт сборки и синтаксического контроля конфигураций и расширений 1С на Linux
# Версия 4.0 - Промышленный стандарт со всеми 5 рубежами защиты
# ==============================================================================

set -euo pipefail

PATH_1C="/opt/1cv8/x86_64/current/1cv8"
DB_CONNECTION=""
DB_USER="Admin"
DB_PASS=""
EXT_NAME=""
TIMEOUT_LIMIT=300
SRC_DIR=""

RUN_ID=$(date +%Y%m%d_%H%M%S)_$RANDOM
LOG_FILE="/tmp/1c_log_${RUN_ID}.txt"
ERR_FILE="/tmp/1c_err_${RUN_ID}.txt"

# POSIX-паттерн ошибок компиляции во всех языковых локалях ОС
ERR_PATTERN="ошибка\|неопознан\|ожидается\|не определен\|несоответств\|не найден\|неверн\|error\|expected\|undefined\|mismatch\|not found\|invalid\|failed"

usage() {
    echo "Использование: $0 [опции]"
    echo "  -c CONNECT_STR  Строка подключения к базе 1С"
    echo "  -e EXT_NAME     Имя расширения (если собираем расширение)"
    echo "  -u USER         Имя администратора ИБ"
    echo "  -w PASSWORD     Пароль администратора ИБ"
    echo "  -s SRC_DIR      Каталог исходных кодов для Diff-контроля (Рубеж 5)"
    exit 1
}

# Парсинг аргументов
while getopts "c:e:u:w:s:h" opt; do
    case "$opt" in
        c) DB_CONNECTION=$OPTARG ;;
        e) EXT_NAME=$OPTARG ;;
        u) DB_USER=$OPTARG ;;
        w) DB_PASS=$OPTARG ;;
        s) SRC_DIR=$OPTARG ;;
        h|*) usage ;;
    esac
done

if [[ -z "$DB_CONNECTION" ]]; then
    echo "[-] Ошибка: Не указана строка подключения (-c)" >&2
    usage
fi

cleanup() {
    echo "[*] Запуск процедуры очистки дескрипторов и временных файлов..."
    rm -f "$LOG_FILE" "$ERR_FILE" "/tmp/diff_result_${RUN_ID}.txt" 2>/dev/null || true
}
trap cleanup EXIT

# Рубеж 4 (предотвращение взаимных блокировок): зачистка зависших .1cLck перед запуском
if [[ "$DB_CONNECTION" =~ ^/[Ff]"?([^";]+) ]] && ! pgrep -f "1cv8" >/dev/null; then
    BASE_PATH="${BASH_REMATCH[1]}"
    echo "[*] Зачистка зависших файлов блокировок в каталоге ${BASE_PATH}..."
    rm -f "${BASE_PATH}"/*.1cLck "${BASE_PATH}"/1Cv8.lk 2>/dev/null || true
fi

# Подготовка аргументов запуска Конфигуратора для синтаксического контроля
CMD_ARGS="DESIGNER $DB_CONNECTION /N "$DB_USER" /P "$DB_PASS" /CheckModules -Server -ThinClient -WebClient /Out "$LOG_FILE" -NoTruncate"
if [[ -n "$EXT_NAME" ]]; then
    CMD_ARGS="$CMD_ARGS -Extension "$EXT_NAME""
fi

echo "[*] Запуск ядра платформы 1С (Запуск ID: ${RUN_ID})..."
set +e
timeout --preserve-status "$TIMEOUT_LIMIT" "$PATH_1C" $CMD_ARGS 2> "$ERR_FILE"
STATUS=$?
set -e

if [[ $STATUS -ne 0 ]]; then
    echo "[-] Критический сбой платформы 1С или превышен таймаут выполнения (Код возврата: $STATUS)" >&2
    if [[ -s "$ERR_FILE" ]]; then
        cat "$ERR_FILE" >&2
    fi
    exit "$STATUS"
fi

# Рубеж 2: Проверка физического наличия и ненулевого размера лога
if [[ ! -s "$LOG_FILE" ]]; then
    echo "[-] Рубеж 2 провален: Лог-файл пуст или не создан. Сбой ядра до старта компилятора!" >&2
    if [[ -s "$ERR_FILE" ]]; then
        cat "$ERR_FILE" >&2
    fi
    exit 100
fi

# Рубеж 1: Динамическая нормализация кодировок и удаление BOM-байтов
MIME=$(file -b --mime-encoding "$LOG_FILE")
echo "[*] Определение кодировки лога: ${MIME}"
if [[ "$MIME" != "utf-8" && "$MIME" != "us-ascii" ]]; then
    echo "[*] Конвертация лога из ${MIME} в UTF-8..."
    iconv -f "$MIME" -t UTF-8 "$LOG_FILE" -o "${LOG_FILE}.tmp"
    mv -f "${LOG_FILE}.tmp" "$LOG_FILE"
fi
# Очистка BOM
sed -i '1s/^ï»¿//' "$LOG_FILE"

# Рубеж 3: Поиск ошибок синтаксиса по мультиязычному шаблону
if grep -Eiq "$ERR_PATTERN" "$LOG_FILE"; then
    echo "[-] Рубеж 3 провален: Обнаружены синтаксические ошибки в модулях!" >&2
    grep -EiaC 3 "$ERR_PATTERN" "$LOG_FILE" >&2
    exit 1
fi

# Рубеж 5: Diff-верификация факта соответствия СУБД исходному коду в Git
if [[ -n "$SRC_DIR" && -d "$SRC_DIR" ]]; then
    echo "[*] Запуск Рубежа 5: выгрузка конфигурации из базы для diff-сравнения..."
    TMP_DUMP="/tmp/dump_${RUN_ID}"
    mkdir -p "$TMP_DUMP"
    
    DUMP_ARGS="DESIGNER $DB_CONNECTION /N "$DB_USER" /P "$DB_PASS" /DumpConfigToFiles "$TMP_DUMP""
    if [[ -n "$EXT_NAME" ]]; then
        DUMP_ARGS="$DUMP_ARGS -Extension "$EXT_NAME""
    fi
    
    "$PATH_1C" $DUMP_ARGS >/dev/null
    
    set +e
    diff -r --strip-trailing-cr -x "ConfigDumpInfo.xml" -x "*.orig" "$SRC_DIR" "$TMP_DUMP" > /tmp/diff_result_${RUN_ID}.txt
    DIFF_STATUS=$?
    set -e
    
    rm -rf "$TMP_DUMP"
    
    if [[ $DIFF_STATUS -ne 0 ]]; then
        echo "[-] Рубеж 5 провален: Код в СУБД отличается от исходного кода в коммите!" >&2
        cat /tmp/diff_result_${RUN_ID}.txt >&2
        exit 2
    fi
    echo "[+] Рубеж 5 успешно пройден: 100% идентичность коммита и СУБД подтверждена."
fi

echo "[+] Сборка и синтаксический контроль успешно завершены без замечаний."
exit 0
