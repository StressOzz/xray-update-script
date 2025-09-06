#!/bin/bash
clear
set -e

# Цвета
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

GRAY='\033[38;5;236m'

VERSION="v1.2"

clear

print_banner() {
  echo ""
  echo "  ██████ ▄▄▄█████▓ ██▀███  ▓█████   ██████   ██████ "
  echo "▒██    ▒ ▓  ██▒ ▓▒▓██ ▒ ██▒▓█   ▀ ▒██    ▒ ▒██    ▒ "
  echo "░ ▓██▄   ▒ ▓██░ ▒░▓██ ░▄█ ▒▒███   ░ ▓██▄   ░ ▓██▄   "
  echo "  ▒   ██▒░ ▓██▓ ░ ▒██▀▀█▄  ▒▓█  ▄   ▒   ██▒  ▒   ██▒"
  echo "▒██████▒▒  ▒██▒ ░ ░██▓ ▒██▒░▒████▒▒██████▒▒▒██████▒▒"
  echo "▒ ▒▓▒ ▒ ░  ▒ ░░   ░ ▒▓ ░▒▓░░░ ▒░ ░▒ ▒▓▒ ▒ ░▒ ▒▓▒ ▒ ░"
  echo "░ ░▒  ░ ░    ░      ░▒ ░ ▒░ ░ ░  ░░ ░▒  ░ ░░ ░▒  ░ ░"
  echo "░  ░  ░    ░        ░░   ░    ░   ░  ░  ░  ░  ░  ░  "
  echo "      ░              ░        ░  ░      ░        ░  "
  echo -e "                                                ${GRAY}${VERSION}${RESET}"

}
print_banner
echo ""



CONTAINER="amnezia-xray"

# Получаем текущую версию Xray в контейнере
CURRENT=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}')

echo -e "${YELLOW}[*] Текущая версия Xray в контейнере: ${GREEN}${CURRENT}${RESET}"

# Получаем последнюю версию Xray с GitHub
LATEST=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST" ]; then
    echo -e "${RED}[!] Не удалось получить последнюю версию.${RESET}"
    exit 1
fi

echo -e "${YELLOW}[*] Последняя версия Xray: ${GREEN}${LATEST}${RESET}"

# Проверяем, совпадают ли версии
if [ "$CURRENT" == "$LATEST" ]; then
    echo -e "${GREEN}[+] Установлена последняя версия Xray. Обновление не требуется.${RESET}"
    exit 0
fi

echo -e "${YELLOW}[*] Версия устарела. Обновляем Xray...${RESET}"

# Удаляем старый архив и временную папку внутри контейнера
docker exec $CONTAINER sh -c 'rm -f /Xray-linux-64.zip'
docker exec $CONTAINER sh -c 'rm -rf /tmp/xray-new'

# Скачиваем, распаковываем и устанавливаем внутри контейнера
docker exec $CONTAINER sh -c "
wget -q -O /Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$LATEST/Xray-linux-64.zip &&
unzip -oq /Xray-linux-64.zip -d /tmp/xray-new &&
cp /tmp/xray-new/xray /usr/bin/xray &&
chmod +x /usr/bin/xray &&
rm -f /Xray-linux-64.zip &&
rm -rf /tmp/xray-new
"

# Перезапускаем контейнер тихо
echo -e "${YELLOW}[*] Перезапускаем контейнер...${RESET}"
docker restart $CONTAINER >/dev/null

# Проверяем версию после обновления
NEW_VER=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}')
echo -e "${YELLOW}[*] Новая версия Xray в контейнере: ${GREEN}${NEW_VER}${RESET}"

echo -e "${GREEN}[+] Обновление завершено!${RESET}"
