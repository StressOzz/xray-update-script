#!/bin/bash
clear
set -e

# Цвета
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

CONTAINER="amnezia-xray"

echo -e "${YELLOW}[*] Текущая версия Xray в контейнере:${RESET}"
docker exec $CONTAINER xray --version || echo -e "${RED}Xray не найден${RESET}"

# Получаем последнюю версию Xray с GitHub
LATEST=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST" ]; then
    echo -e "${RED}[!] Не удалось получить последнюю версию.${RESET}"
    exit 1
fi

echo -e "${YELLOW}[*] Последняя версия: $LATEST${RESET}"
URL="https://github.com/XTLS/Xray-core/releases/download/v$LATEST/Xray-linux-64.zip"

# Удаляем старый архив и распакованную папку внутри контейнера, если есть
docker exec $CONTAINER sh -c 'rm -f /tmp/Xray-linux-64.zip'
docker exec $CONTAINER sh -c 'rm -rf /tmp/xray-new'

# Скачиваем и распаковываем внутри контейнера
echo -e "${YELLOW}[*] Скачиваем и распаковываем Xray $LATEST внутри контейнера...${RESET}"
docker exec $CONTAINER sh -c "
wget -q -O /tmp/Xray-linux-64.zip $URL &&
unzip -oq /tmp/Xray-linux-64.zip -d /tmp/xray-new &&
cp /tmp/xray-new/xray /usr/bin/xray &&
chmod +x /usr/bin/xray
"

# Перезапускаем контейнер
echo -e "${YELLOW}[*] Перезапускаем контейнер...${RESET}"
docker restart $CONTAINER

# Проверяем версию после обновления
echo -e "${YELLOW}[*] Новая версия Xray в контейнере:${RESET}"
docker exec $CONTAINER xray --version

echo -e "${GREEN}[+] Обновление завершено!${RESET}"
