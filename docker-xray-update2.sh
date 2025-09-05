#!/bin/bash
clear
set -e

# Цвета
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

CONTAINER="amnezia-xray"

##########################
# Проверка и обновление Docker
##########################
echo -e "${YELLOW}[*] Проверка Docker...${RESET}"

# Текущая версия Docker
CURRENT_FULL=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
CURRENT=$(echo "$CURRENT_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
CURRENT=${CURRENT:-"не установлен"}
echo -e "${YELLOW}[*] Текущая версия Docker: ${GREEN}${CURRENT}${RESET}"

# Удаляем старые версии Docker тихо
apt remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# Устанавливаем зависимости тихо
apt update -qq
apt install -y -qq ca-certificates curl gnupg lsb-release >/dev/null 2>&1

# Проверка ключа Docker и добавление при отсутствии
if ! apt-key list 2>/dev/null | grep -q 7EA0A9C3F273FCD8; then
    echo -e "${YELLOW}[*] Добавляем ключ Docker...${RESET}"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

# Добавляем репозиторий Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list >/dev/null

# Получаем последнюю версию Docker тихо
apt update -qq
LATEST_FULL=$(apt-cache policy docker-ce | grep Candidate | awk '{print $2}')
LATEST=$(echo "$LATEST_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
LATEST=${LATEST:-"не найдено"}
echo -e "${YELLOW}[*] Последняя доступная версия Docker: ${GREEN}${LATEST}${RESET}"

# Если актуально, пропускаем обновление
if [ "$CURRENT" == "$LATEST" ]; then
    echo -e "${GREEN}[+] Docker актуален (${CURRENT}). Обновление не требуется.${RESET}"
else
    echo -e "${YELLOW}[*] Обновляем Docker...${RESET}"
    apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
    NEW_VER_FULL=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
    NEW_VER=$(echo "$NEW_VER_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
    echo -e "${YELLOW}[*] Итоговая версия Docker: ${GREEN}${NEW_VER}${RESET}"
fi

##########################
# Проверка и обновление Xray
##########################
echo -e "\n${YELLOW}[*] Проверка Xray в контейнере ${CONTAINER}...${RESET}"

# Текущая версия Xray
CURRENT=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}')
echo -e "${YELLOW}[*] Текущая версия Xray: ${GREEN}${CURRENT}${RESET}"

# Последняя версия с GitHub
LATEST=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest \
    | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
if [ -z "$LATEST" ]; then
    echo -e "${RED}[!] Не удалось получить последнюю версию Xray.${RESET}"
    exit 1
fi
echo -e "${YELLOW}[*] Последняя версия Xray: ${GREEN}${LATEST}${RESET}"

# Если актуально, пропускаем обновление
if [ "$CURRENT" == "$LATEST" ]; then
    echo -e "${GREEN}[+] Установлена последняя версия Xray (${CURRENT}). Обновление не требуется.${RESET}"
else
    echo -e "${YELLOW}[*] Версия устарела. Обновляем Xray...${RESET}"

    # Подчищаем старый архив и временные файлы
    docker exec $CONTAINER sh -c 'rm -f /Xray-linux-64.zip'
    docker exec $CONTAINER sh -c 'rm -rf /tmp/xray-new'

    # Скачиваем и устанавливаем Xray
    docker exec $CONTAINER sh -c "
        wget -q -O /Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$LATEST/Xray-linux-64.zip &&
        unzip -oq /Xray-linux-64.zip -d /tmp/xray-new &&
        cp /tmp/xray-new/xray /usr/bin/xray &&
        chmod +x /usr/bin/xray &&
        rm -f /Xray-linux-64.zip &&
        rm -rf /tmp/xray-new
    "

    # Перезапускаем контейнер тихо
    echo -e "${YELLOW}[*] Перезапускаем контейнер ${CONTAINER}...${RESET}"
    docker restart $CONTAINER >/dev/null

    # Итоговая версия
    NEW_VER=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}')
    echo -e "${YELLOW}[*] Новая версия Xray: ${GREEN}${NEW_VER}${RESET}"
fi

echo -e "\n${GREEN}[+] Обновление Docker и Xray завершено!${RESET}"
