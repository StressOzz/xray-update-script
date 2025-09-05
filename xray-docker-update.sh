#!/bin/bash
clear
set -e

# Цвета
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

CONTAINER="amnezia-xray"

# ================== Обновление Docker ==================
echo -e "${YELLOW}[*] Проверка Docker...${RESET}"

CURRENT_DOCKER_FULL=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
CURRENT_DOCKER=$(echo "$CURRENT_DOCKER_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/') 
CURRENT_DOCKER=${CURRENT_DOCKER:-"не установлен"}
echo -e "${YELLOW}[*] Текущая версия Docker: ${GREEN}${CURRENT_DOCKER}${RESET}"

# Удаляем старые версии Docker (молча)
apt remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# Устанавливаем зависимости (молча)
apt update -qq
apt install -y -qq ca-certificates curl gnupg lsb-release >/dev/null 2>&1

# Удаляем старый ключ Docker
rm -f /etc/apt/keyrings/docker.gpg

# Добавляем официальный ключ Docker
mkdir -p /etc/apt/keyrings
if ! curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    echo -e "${RED}[!] Ошибка: не удалось добавить ключ Docker${RESET}"
    exit 1
fi

# Добавляем репозиторий Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list >/dev/null

# Получаем последнюю доступную версию Docker
apt update -qq
LATEST_DOCKER_FULL=$(apt-cache policy docker-ce | grep Candidate | awk '{print $2}')
LATEST_DOCKER=$(echo "$LATEST_DOCKER_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
LATEST_DOCKER=${LATEST_DOCKER:-"не найдено"}
echo -e "${YELLOW}[*] Последняя доступная версия Docker: ${GREEN}${LATEST_DOCKER}${RESET}"

if [ "$CURRENT_DOCKER" == "$LATEST_DOCKER" ]; then
    echo -e "${GREEN}[+] Docker актуален (${CURRENT_DOCKER}). Обновление не требуется.${RESET}"
else
    echo -e "${YELLOW}[*] Обновляем Docker...${RESET}"
    if ! apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1; then
        echo -e "${RED}[!] Ошибка: не удалось установить Docker${RESET}"
        exit 1
    fi
    NEW_DOCKER_FULL=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
    NEW_DOCKER=$(echo "$NEW_DOCKER_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
    echo -e "${YELLOW}[*] Итоговая версия Docker: ${GREEN}${NEW_DOCKER}${RESET}"
fi

# ================== Обновление Xray ==================
echo -e "\n${YELLOW}[*] Проверка Xray в контейнере ${CONTAINER}...${RESET}"

CURRENT_XRAY=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}')
echo -e "${YELLOW}[*] Текущая версия Xray: ${GREEN}${CURRENT_XRAY}${RESET}"

LATEST_XRAY=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest \
    | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST_XRAY" ]; then
    echo -e "${RED}[!] Не удалось получить последнюю версию Xray.${RESET}"
    exit 1
fi
echo -e "${YELLOW}[*] Последняя версия Xray: ${GREEN}${LATEST_XRAY}${RESET}"

if [ "$CURRENT_XRAY" == "$LATEST_XRAY" ]; then
    echo -e "${GREEN}[+] Установлена последняя версия Xray (${CURRENT_XRAY}). Обновление не требуется.${RESET}"
else
    echo -e "${YELLOW}[*] Версия устарела. Обновляем Xray...${RESET}"

    # Подчищаем старый архив и временную папку
    docker exec $CONTAINER sh -c 'rm -f /Xray-linux-64.zip'
    docker exec $CONTAINER sh -c 'rm -rf /tmp/xray-new'

    # Скачиваем, распаковываем и ставим новую версию
    docker exec $CONTAINER sh -c "
    wget -q -O /Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$LATEST_XRAY/Xray-linux-64.zip &&
    unzip -oq /Xray-linux-64.zip -d /tmp/xray-new &&
    cp /tmp/xray-new/xray /usr/bin/xray &&
    chmod +x /usr/bin/xray &&
    rm -f /Xray-linux-64.zip &&
    rm -rf /tmp/xray-new
    "

    echo -e "${YELLOW}[*] Перезапускаем контейнер ${CONTAINER}...${RESET}"
    docker restart $CONTAINER >/dev/null

    NEW_XRAY=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}')
    echo -e "${YELLOW}[*] Новая версия Xray: ${GREEN}${NEW_XRAY}${RESET}"
fi

echo -e "\n${GREEN}[+] Обновление Docker и Xray завершено!${RESET}"
