#!/bin/bash
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

echo -e "${YELLOW}[*] Начинаем проверку Docker...${RESET}"

# ---------------- Docker ----------------

# Текущая версия Docker (если есть)
CURRENT_FULL=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || echo "")
CURRENT=$(echo "$CURRENT_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/' || echo "не установлен")
echo -e "${YELLOW}[*] Текущая версия Docker: ${GREEN}${CURRENT}${RESET}"

# Удаляем старые версии Docker (молча)
apt remove -y -qq docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# Устанавливаем зависимости (молча)
apt install -y -qq ca-certificates curl gnupg lsb-release >/dev/null 2>&1

# Удаляем старые ключи Docker, если есть
rm -f /etc/apt/trusted.gpg.d/docker.gpg
rm -f /etc/apt/keyrings/docker.gpg

# Добавляем официальный ключ Docker
echo -e "${YELLOW}[*] Добавляем ключ Docker...${RESET}"
mkdir -p /etc/apt/keyrings
if ! curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    echo -e "${RED}[!] Ошибка: не удалось добавить ключ Docker${RESET}"
    exit 1
fi

# Добавляем репозиторий Docker
echo -e "${YELLOW}[*] Добавляем репозиторий Docker...${RESET}"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

# Обновляем индекс и получаем последнюю доступную версию
apt update -qq >/dev/null 2>&1
LATEST_FULL=$(apt-cache policy docker-ce | grep Candidate | awk '{print $2}' || echo "")
LATEST=$(echo "$LATEST_FULL" | sed -E 's/^[0-9]+:([0-9.]+).*/\1/' || echo "не найдено")
echo -e "${YELLOW}[*] Последняя доступная версия Docker: ${GREEN}${LATEST}${RESET}"

# Проверяем версию
if [ "$CURRENT" == "$LATEST" ]; then
    echo -e "${GREEN}[+] Docker актуален (${CURRENT}). Обновление не требуется.${RESET}"
else
    echo -e "${YELLOW}[*] Обновляем Docker...${RESET}"
    if ! apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1; then
        echo -e "${RED}[!] Ошибка: не удалось установить Docker${RESET}"
        exit 1
    fi
    NEW_VER=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || echo "не установлен")
    echo -e "${YELLOW}[*] Итоговая версия Docker после обновления: ${GREEN}${NEW_VER}${RESET}"
fi

# ---------------- Xray ----------------

echo -e "\n${YELLOW}[*] Проверка Xray в контейнере ${CONTAINER}...${RESET}"

# Получаем текущую версию Xray
CURRENT_X=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "не установлен")
echo -e "${YELLOW}[*] Текущая версия Xray: ${GREEN}${CURRENT_X}${RESET}"

# Получаем последнюю версию Xray с GitHub
LATEST_X=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest \
    | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
if [ -z "$LATEST_X" ]; then
    echo -e "${RED}[!] Не удалось получить последнюю версию Xray.${RESET}"
    exit 1
fi
echo -e "${YELLOW}[*] Последняя версия Xray: ${GREEN}${LATEST_X}${RESET}"

# Проверяем версии
if [ "$CURRENT_X" == "$LATEST_X" ]; then
    echo -e "${GREEN}[+] Установлена последняя версия Xray (${CURRENT_X}). Обновление не требуется.${RESET}"
else
    echo -e "${YELLOW}[*] Версия устарела. Обновляем Xray...${RESET}"
    # Удаляем старые файлы
    docker exec $CONTAINER sh -c 'rm -f /Xray-linux-64.zip'
    docker exec $CONTAINER sh -c 'rm -rf /tmp/xray-new'

    # Скачиваем, распаковываем и ставим
    docker exec $CONTAINER sh -c "
    wget -q -O /Xray-linux-64.zip https://github.com/XTLS/Xray-core/releases/download/v$LATEST_X/Xray-linux-64.zip &&
    unzip -oq /Xray-linux-64.zip -d /tmp/xray-new &&
    cp /tmp/xray-new/xray /usr/bin/xray &&
    chmod +x /usr/bin/xray &&
    rm -f /Xray-linux-64.zip &&
    rm -rf /tmp/xray-new
    "

    # Перезапускаем контейнер тихо
    echo -e "${YELLOW}[*] Перезапускаем контейнер ${CONTAINER}...${RESET}"
    docker restart $CONTAINER >/dev/null

    NEW_X=$(docker exec $CONTAINER xray --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "не установлен")
    echo -e "${YELLOW}[*] Новая версия Xray: ${GREEN}${NEW_X}${RESET}"
fi

echo -e "\n${GREEN}[+] Обновление Docker и Xray завершено!${RESET}"
