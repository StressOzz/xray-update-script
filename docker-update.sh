#!/bin/bash
set -e

# Цвета
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${YELLOW}[*] Начинаем обновление Docker...${RESET}"

# Удаляем старые версии, если они есть
echo -e "${YELLOW}[*] Проверка старых версий Docker...${RESET}"
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Устанавливаем зависимости
echo -e "${YELLOW}[*] Устанавливаем необходимые пакеты...${RESET}"
apt update
apt install -y ca-certificates curl gnupg lsb-release

# Добавляем официальный ключ Docker
echo -e "${YELLOW}[*] Добавляем официальный ключ Docker...${RESET}"
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Добавляем репозиторий Docker
echo -e "${YELLOW}[*] Добавляем репозиторий Docker...${RESET}"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Обновляем пакеты и устанавливаем Docker
echo -e "${YELLOW}[*] Устанавливаем/обновляем Docker...${RESET}"
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Проверяем версию
VERSION=$(docker --version)
echo -e "${GREEN}[+] Docker успешно обновлён! Текущая версия: ${VERSION}${RESET}"

echo -e "${GREEN}[+] Все контейнеры, включая Xray, остаются нетронутыми.${RESET}"
