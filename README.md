[![Infostart](https://infostart.ru/bitrix/templates/sandbox_empty/assets/tpl/abo/img/logo.svg)](https://infostart.ru/public/2779597/) - Первая часть

[![Infostart](https://infostart.ru/bitrix/templates/sandbox_empty/assets/tpl/abo/img/logo.svg)](https://infostart.ru/public/2780378/) - Вторая часть

# DevOps & Stability Enterprise Suite for 1C on Linux

Комплекс инструментов обеспечения надежности, непрерывной интеграции (CI/CD) и автоматизированной эксплуатации крупных кластеров «1С:Предприятие 8.3» на платформе Linux.

## 📂 Структура репозитория

* `config/` — оптимизированные шаблоны настроек технологического журнала и HASP-лицензирования.
* `docker/` — Dockerfile для сборки сборочных агентов с графическим стеком (Xvfb) и шрифтами.
* `scripts/` — скрипты сборки и конвертации метаданных из EDT в формат Конфигуратора.
* `orchestrator/` — комплект SRE-инструментов для ротации rphost и алертинга.

## 🚀 Быстрый старт

### 1. Сборка Docker-образа
Для подготовки сборочного раннера поместите deb-дистрибутивы платформы 1С в подкаталог `docker/dist` и выполните:
```bash
docker build -t 1c-ci-runner:latest ./docker
```

### 2. Запуск синтаксического контроля
Скрипт проверяет код BSL во всех контекстах и реализует 5 рубежей защиты:
```bash
./scripts/1c-ci-linux-build-v4.sh -c "/F/tmp/build_db" -e "MyExtension" -u "Admin" -w "SecurePass" -s "./src/extension"
```

### 3. Настройка SRE-мониторинга
Установите службу автоматического выявления "перестарков" на сервере 1С:
```bash
cd orchestrator
sudo ./install_admincluster.sh
```
Настройте параметры в `/etc/admincluster/config.conf` и активируйте таймер systemd:
```bash
sudo systemctl enable --now admincluster-monitor@prod.timer
```

---
Разработано совместно в рамках проекта «1С:SRE-Контур». Свободная лицензия MIT.
