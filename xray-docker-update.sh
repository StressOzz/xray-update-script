#!/bin/bash
clear
set -e

# Цвета
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

CONTAINER="amnezia-xray"

echo -e "${YELLOW}[*] Начинаем проверку Docker...${RESET}"

# Текущая версия Docker
CURRENT_DOCKER_FULL=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
CURRENT_DOCKER=$(echo "$CURRENT_DOCKER_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
CURRENT_DOCKER=${CURRENT_DOCKER:-"не установлен"}
echo -e "${YELLOW}[*] Текущая версия Docker: ${GREEN}${CURRENT_DOCKER}${RESET}"

# Удаляем старые версии Docker (молча)
apt remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# Устанавливаем зависимости
apt update -qq
apt install -y -qq ca-certificates curl gnupg lsb-release >/dev/null 2>&1

# Удаляем старый ключ Docker
rm -f /etc/apt/keyrings/docker.gpg

# Добавляем официальный ключ Docker
echo -e "${YELLOW}[*] Устанавливаем официальный ключ Docker...${RESET}"
mkdir -p /etc/apt/keyrings
if ! curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    echo -e "${RED}[!] Ошибка: не удалось добавить ключ Docker${RESET}"
    exit 1
fi

# Добавляем репозиторий Docker
echo -e "${YELLOW}[*] Добавляем репозиторий Docker...${RESET}"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list >/dev/null

# Последняя доступная версия Docker
apt update -qq
LATEST_DOCKER_FULL=$(apt-cache policy docker-ce | grep Candidate | awk '{print $2}')
LATEST_DOCKER=$(echo "$LATEST_DOCKER_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
LATEST_DOCKER=${LATEST_DOCKER:-"не найдено"}
echo -e "${YELLOW}[*] Последняя доступная версия Docker: ${GREEN}${LATEST_DOCKER}${RESET}"

# Проверяем необходимость обновления Docker
if [ "$CURRENT_DOCKER" == "$LATEST_DOCKER" ]; then
    echo -e "${GREEN}[+] Установлена последняя версия Docker (${CURRENT_DOCKER}). Обновление не требуется.${RESET}"
else
    echo -e "${YELLOW}[*] Обновляем Docker...${RESET}"
    if ! apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1; then
        echo -e "${RED}[!] Ошибка: не удалось установить Docker${RESET}"
        exit 1
    fi
    CURRENT_DOCKER=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
    echo -e "${GREEN}[+] Docker обновлён до версии ${CURRENT_DOCKER}${RESET}"
fi

echo -e "${YELLOW}[*] Начинаем проверку Xray в контейнере ${CONTAINER}...${RESET}"

# Текущая версия Xray
CURRENT_XRAY=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}')
CURRENT_XRAY=${CURRENT_XRAY:-"не установлен"}
echo -e "${YELLOW}[*] Текущая версия Xray: ${GREEN}${CURRENT_XRAY}${RESET}"

# Последняя версия Xray
LATEST_XRAY=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
if [ -z "$LATEST_XRAY" ]; then
    echo -e "${RED}[!] Не удалось получить последнюю версию Xray.${RESET}"
    exit 1
fi
echo -e "${YELLOW}[*] Последняя версия Xray: ${GREEN}${LATEST_XRAY}${RESET}"

# Проверка необходимости обновления
if [ "$CURRENT_XRAY" == "$LATEST_XRAY" ]; then
    echo -e "${GREEN}[+] Установлена последняя версия Xray (${CURRENT_XRAY}). Обновление не требуется.${RESET}"
    exit 0
fi

echo -e "${YELLOW}[*] Версия Xray устарела. Обновляем...${RESET}"

# Удаляем старый архив и временную папку
docker exec $CONTAINER sh -c 'rm -f /Xray-linux-64.zip'
docker exec $CONTAINER sh -c 'rm -rf /tmp/xray-new'

# Скачиваем, распаковываем и ставим
docker exec $CONTAINER sh -c "
wget -q -O /Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$LATEST_XRAY/Xray-linux-64.zip &&
unzip -oq /Xray-linux-64.zip -d /tmp/xray-new &&
cp /tmp/xray-new/xray /usr/bin/xray &&
chmod +x /usr/bin/xray &&
rm -f /Xray-linux-64.zip &&
rm -rf /tmp/xray-new
"

# Перезапускаем контейнер
echo -e "${YELLOW}[*] Перезапускаем контейнер...${RESET}"
docker restart $CONTAINER >/dev/null

# Итоговая версия Xray
NEW_XRAY=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}')
echo -e "${YELLOW}[*] Новая версия Xray: ${GREEN}${NEW_XRAY}${RESET}"

echo -e "${GREEN}[+] Обновление Docker и Xray завершено!${RESET}"
