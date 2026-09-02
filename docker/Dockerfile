FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8

# Установка системных утилит, шрифтов и графических библиотек для headless-режима
RUN apt-get update && apt-get install -y --no-install-recommends     locales ca-certificates curl file git procps     xvfb xauth fontconfig dbus-x11 libwebkit2gtk-4.0-37     libgl1 libglx-mesa0 msttcorefonts     && locale-gen ru_RU.UTF-8     && update-locale LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8     && fc-cache -fv     && rm -rf /var/lib/apt/lists/*

# Создание непривилегированного пользователя runner для выполнения шагов CI
RUN groupadd -g 1001 runner     && useradd -u 1001 -g runner -m -s /bin/bash runner     && mkdir -p /opt/1cv8 /var/1c/db /var/1c/licenses     && chown -R runner:runner /opt/1cv8 /var/1c/db /var/1c/licenses

# Автоматическая установка платформы из подготовленного deb-дистрибутива (через ONBUILD ON PUSH)
ONBUILD COPY ./dist/*.deb /tmp/1c-dist/
ONBUILD RUN apt-get update && (dpkg -i /tmp/1c-dist/*.deb || apt-get install -fy)     && rm -rf /tmp/1c-dist /var/lib/apt/lists/*

USER runner
WORKDIR /home/runner
ENV DISPLAY=:99

CMD ["/bin/bash"]
