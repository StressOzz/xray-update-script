#!/bin/bash
set -e

clear
echo "============================================"
echo "          DOCKER MANAGEMENT MENU"
echo "============================================"
echo "1) Обновить Docker"
echo "2) Полностью удалить Docker"
echo "0) Выход"
echo "============================================"
read -p "Выберите действие [0-2]: " choice

case "$choice" in
    1)
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
        
        ;;
    2)
 echo "=== Останавливаем службы Docker ==="
systemctl stop docker 2>/dev/null || true
systemctl stop docker.socket 2>/dev/null || true
systemctl stop containerd 2>/dev/null || true

echo "=== Удаляем контейнеры ==="
docker ps -aq | xargs -r docker rm -f || true

echo "=== Удаляем образы ==="
docker images -q | xargs -r docker rmi -f || true

echo "=== Удаляем тома ==="
docker volume ls -q | xargs -r docker volume rm -f || true

echo "=== Удаляем пользовательские сети ==="
docker network ls -q | grep -v "bridge\|host\|none" | xargs -r docker network rm || true

echo "=== Удаляем ВСЕ пакеты Docker ==="
apt purge -y docker-ce docker-ce-cli docker-ce-rootless-extras docker-buildx-plugin docker-compose-plugin containerd.io docker-desktop 2>/dev/null || true
apt purge -y docker.io containerd runc docker-engine 2>/dev/null || true

echo "=== Удаляем каталоги и конфиги Docker ==="
rm -rf /var/lib/docker
rm -rf /var/lib/containerd
rm -rf /etc/docker
rm -rf /etc/containerd
rm -rf /etc/systemd/system/docker.service.d
rm -rf /etc/systemd/system/containerd.service.d

echo "=== Удаляем сокеты и рантайм файлы ==="
rm -f /run/docker.sock
rm -f /var/run/docker.sock
rm -rf /run/docker
rm -rf /var/run/docker
rm -rf /run/containerd
rm -rf /var/run/containerd

echo "=== Удаляем systemd юниты, если остались ==="
rm -f /etc/systemd/system/docker.service
rm -f /etc/systemd/system/docker.socket
rm -f /etc/systemd/system/containerd.service

echo "=== Перезагружаем systemd ==="
systemctl daemon-reload || true

echo "=== Чистим зависимости ==="
apt autoremove -y

echo "=== Проверка ==="
echo "docker: $(command -v docker || echo 'не найден')"
echo "containerd: $(command -v containerd || echo 'не найден')"

echo "=== Готово. Полная зачистка Docker выполнена. ==="       
        ;;
    *)
        exit 1
        ;;
esac
