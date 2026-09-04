#!/usr/bin/env bash
# Скрипт автоматического маскирования базы данных 1С на PostgreSQL с помощью pg_anon
# Реализует концепцию: Безопасный пайплайн без промежуточной копии на диске

set -euo pipefail

# Переменные по умолчанию
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASS="${DB_PASS:-}"
PROD_DB="production_1c"
ANON_STAGE_DB="stage_anonymized_1c"
RULES_FILE="config/pg-anon-1c.yml"
OUTPUT_DUMP="/workspace/out/anonymized_dev.dump"

echo "[*] Старт процесса обезличивания базы данных..."

# Шаг 1. Создание изолированной базы данных для маскирования
echo "[*] Создание staging СУБД: $ANON_STAGE_DB..."
PGPASSWORD="$DB_PASS" dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" --if-exists "$ANON_STAGE_DB"
PGPASSWORD="$DB_PASS" createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -O "$DB_USER" "$ANON_STAGE_DB"

# Шаг 2. Копирование структуры и данных напрямую через конвейер (без сохранения промежуточного дампа на диск)
echo "[*] Перенос данных из $PROD_DB в $ANON_STAGE_DB в потоке..."
PGPASSWORD="$DB_PASS" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc "$PROD_DB" \
  | PGPASSWORD="$DB_PASS" pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$ANON_STAGE_DB"

# Шаг 3. Применение правил обезличивания pg_anon
echo "[*] Запуск маскирования pg_anon..."
if [ -f "$RULES_FILE" ]; then
  pg_anon -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$ANON_STAGE_DB" -c "$RULES_FILE"
else
  echo "[-] Ошибка: Файл правил $RULES_FILE не найден!"
  exit 1
fi

# Шаг 4. Очистка сеансовых и служебных данных 1С (Post-anonymization sql script)
echo "[*] Выполнение пост-обработки СУБД для среды разработки..."
PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$ANON_STAGE_DB" << 'SQL'
-- 1. Сброс паролей всех пользователей для возможности входа разработчиков
UPDATE v8users SET password = '';

-- 2. Очистка истории активных сеансов и блокировок в системных таблицах
-- Удаление блокировок и активных соединений, специфичных для метаданных платформы
DELETE FROM _ConfigChngR;        -- Очистка таблиц регистрации изменений метаданных
DELETE FROM _AccumRegChgR;       -- Очистка регистрации изменений регистров накопления
DELETE FROM _InfoRgChgR;         -- Очистка регистрации изменений регистров сведений
SQL

# Шаг 5. Экспорт готового обезличенного дампа для разработчиков
echo "[*] Создание чистого дампа для разработчиков..."
PGPASSWORD="$DB_PASS" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc -d "$ANON_STAGE_DB" -f "$OUTPUT_DUMP"

# Шаг 6. Удаление временной базы маскирования
echo "[*] Удаление staging СУБД $ANON_STAGE_DB..."
PGPASSWORD="$DB_PASS" dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$ANON_STAGE_DB"

echo "[+] Обезличивание успешно завершено! Дамп сохранен в $OUTPUT_DUMP"
exit 0
