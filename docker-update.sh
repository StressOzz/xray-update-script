
#!/bin/bash
set -e

# Цвета
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
RESET="\033[0m"

GRAY='\033[38;5;236m'

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

}
print_banner
echo ""


#!/bin/bash
set -e

echo "============================================"
echo "   ТЕКУЩИЕ ВЕРСИИ ДО ОБНОВЛЕНИЯ"
echo "============================================"

# Проверка наличия docker
if command -v docker >/dev/null 2>&1; then
    echo -n "Docker:           "
    docker --version
else
    echo "Docker:           не установлен"
fi

# Compose plugin
if docker compose version >/dev/null 2>&1; then
    echo -n "Docker Compose:   "
    docker compose version
else
    echo "Docker Compose:   не найден"
fi

# containerd
if command -v containerd >/dev/null 2>&1; then
    echo -n "containerd:       "
    containerd --version
else
    echo "containerd:       не установлен"
fi

echo ""
echo "=== Обновляем индексы пакетов ==="
apt update

echo ""
echo "=== Обновляем Docker CE и комплектующие ==="
apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo ""
echo "=== Перезапускаем службы ==="
systemctl restart docker || true
systemctl restart containerd || true

echo ""
echo "============================================"
echo "   ВЕРСИИ ПОСЛЕ ОБНОВЛЕНИЯ"
echo "============================================"

if command -v docker >/dev/null 2>&1; then
    echo -n "Docker:           "
    docker --version
fi

if docker compose version >/dev/null 2>&1; then
    echo -n "Docker Compose:   "
    docker compose version
fi

if command -v containerd >/dev/null 2>&1; then
    echo -n "containerd:       "
    containerd --version
fi

echo "============================================"
echo "   ОБНОВЛЕНИЕ ЗАВЕРШЕНО"
echo "============================================"
