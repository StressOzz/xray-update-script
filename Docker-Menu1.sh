#!/bin/bash
set -e

# --- Цвета ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m' # нет цвета

while true; do
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${CYAN}          DOCKER MANAGEMENT MENU${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "1) Обновить Docker"
    echo -e "2) Полностью удалить Docker"
    echo -e "3) Показать что есть в Docker"
    echo -e "Enter) Выход"
    echo -e "${BLUE}============================================${NC}"
    read -p "Выберите действие: " choice

    case "$choice" in
        1)
            echo -e "${BLUE}============================================${NC}"
            echo -e "${CYAN}   ТЕКУЩИЕ ВЕРСИИ ДО ОБНОВЛЕНИЯ${NC}"
            echo -e "${BLUE}============================================${NC}"

            # Docker
            if command -v docker >/dev/null 2>&1; then
                echo -e "${GREEN}Docker: $(docker --version)${NC}"
            else
                echo -e "${RED}Docker: не установлен${NC}"
            fi

            # Compose plugin
            if docker compose version >/dev/null 2>&1; then
                echo -e "${GREEN}Docker Compose: $(docker compose version)${NC}"
            else
                echo -e "${RED}Docker Compose: не найден${NC}"
            fi

            # containerd
            if command -v containerd >/dev/null 2>&1; then
                echo -e "${GREEN}containerd: $(containerd --version)${NC}"
            else
                echo -e "${RED}containerd: не установлен${NC}"
            fi

            echo ""
            echo -e "${CYAN}=== Обновляем индексы пакетов ===${NC}"
            apt update

            echo ""
            echo -e "${CYAN}=== Обновляем Docker CE и комплектующие ===${NC}"
            apt install -y \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin

            echo ""
            echo -e "${CYAN}=== Перезапускаем службы ===${NC}"
            systemctl restart docker || true
            systemctl restart containerd || true

            echo ""
            echo -e "${BLUE}============================================${NC}"
            echo -e "${CYAN}   ВЕРСИИ ПОСЛЕ ОБНОВЛЕНИЯ${NC}"
            echo -e "${BLUE}============================================${NC}"

            command -v docker >/dev/null 2>&1 && echo -e "${GREEN}Docker:           $(docker --version)${NC}"
            docker compose version >/dev/null 2>&1 && echo -e "${GREEN}Docker Compose:   $(docker compose version)${NC}"
            command -v containerd >/dev/null 2>&1 && echo -e "${GREEN}containerd:       $(containerd --version)${NC}"

            echo -e "${BLUE}============================================${NC}"
            echo -e "${GREEN}   ОБНОВЛЕНИЕ ЗАВЕРШЕНО${NC}"
            echo -e "${BLUE}============================================${NC}"
            read -p "Нажмите Enter для возврата в меню..." dummy
            ;;
        2)
            echo -e "${CYAN}=== Полное удаление Docker ===${NC}"

            echo -e "${CYAN}Останавливаем службы Docker...${NC}"
            systemctl stop docker 2>/dev/null || true
            systemctl stop docker.socket 2>/dev/null || true
            systemctl stop containerd 2>/dev/null || true

            echo -e "${CYAN}Удаляем контейнеры, образы, тома и сети...${NC}"
            docker ps -aq | xargs -r docker rm -f || true
            docker images -q | xargs -r docker rmi -f || true
            docker volume ls -q | xargs -r docker volume rm -f || true
            docker network ls -q | grep -v "bridge\|host\|none" | xargs -r docker network rm || true

            echo -e "${CYAN}Удаляем пакеты Docker...${NC}"
            apt purge -y docker-ce docker-ce-cli docker-ce-rootless-extras docker-buildx-plugin docker-compose-plugin containerd.io docker-desktop 2>/dev/null || true
            apt purge -y docker.io containerd runc docker-engine 2>/dev/null || true

            echo -e "${CYAN}Удаляем каталоги и конфиги...${NC}"
            rm -rf /var/lib/docker /var/lib/containerd /etc/docker /etc/containerd /etc/systemd/system/docker.service.d /etc/systemd/system/containerd.service.d
            rm -f /run/docker.sock /var/run/docker.sock
            rm -rf /run/docker /var/run/docker /run/containerd /var/run/containerd
            rm -f /etc/systemd/system/docker.service /etc/systemd/system/docker.socket /etc/systemd/system/containerd.service

            systemctl daemon-reload || true
            apt autoremove -y

            echo -e "${GREEN}Docker полностью удалён${NC}"
            read -p "Нажмите Enter для возврата в меню..." dummy
            ;;
        3)
            echo -e "${CYAN}=== Состояние Docker ===${NC}"
            echo -e "${BLUE}--- Контейнеры ---${NC}"
            docker ps -a || echo "Нет контейнеров"

            echo -e "${BLUE}--- Образы ---${NC}"
            docker images || echo "Нет образов"

            echo -e "${BLUE}--- Тома ---${NC}"
            docker volume ls || echo "Нет томов"

            echo -e "${BLUE}--- Сети ---${NC}"
            docker network ls || echo "Нет сетей"

            echo -e "${BLUE}============================================${NC}"
            read -p "Нажмите Enter для возврата в меню..." dummy
            ;;
        0|*)
            echo -e "${CYAN}Выход...${NC}"
            exit 0
            ;;
    esac
done
