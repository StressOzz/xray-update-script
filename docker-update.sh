#!/bin/bash
clear
set -e

# Цвета
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${YELLOW}[*] Начинаем проверку Docker...${RESET}"

# Текущая версия Docker (если есть)
CURRENT_FULL=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
CURRENT=$(echo "$CURRENT_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
CURRENT=${CURRENT:-"не установлен"}
echo -e "${YELLOW}[*] Текущая версия Docker: ${GREEN}${CURRENT}${RESET}"

# Удаляем старые версии Docker (молча)
apt remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# Устанавливаем зависимости (молча)
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

# Получаем последнюю доступную версию Docker
apt update -qq
LATEST_FULL=$(apt-cache policy docker-ce | grep Candidate | awk '{print $2}')
LATEST=$(echo "$LATEST_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
LATEST=${LATEST:-"не найдено"}
echo -e "${YELLOW}[*] Последняя доступная версия Docker: ${GREEN}${LATEST}${RESET}"

# Если текущая версия совпадает с последней
if [ "$CURRENT" == "$LATEST" ]; then
    echo -e "${GREEN}[+] Установлена последняя версия Docker (${CURRENT}). Обновление не требуется.${RESET}"
    exit 0
fi

# Устанавливаем/обновляем Docker
echo -e "${YELLOW}[*] Обновляем Docker...${RESET}"
if ! apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1; then
    echo -e "${RED}[!] Ошибка: не удалось установить Docker${RESET}"
    exit 1
fi

# Итоговая версия
NEW_VER_FULL=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
NEW_VER=$(echo "$NEW_VER_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/')
NEW_VER=${NEW_VER:-"не установлен"}
echo -e "${YELLOW}[*] Итоговая версия Docker после обновления: ${GREEN}${NEW_VER}${RESET}"

echo -e "${GREEN}[+] Docker обновлён! Все контейнеры, включая Xray, остаются нетронутыми.${RESET}"
