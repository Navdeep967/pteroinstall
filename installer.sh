#!/bin/bash

set -e

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

echo -e "${GREEN}=== Pterodactyl Panel Installer (Docker) ===${RESET}"

# Update system
echo -e "${YELLOW}Updating system...${RESET}"
apt update -y && apt upgrade -y

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${RESET}"
apt install -y docker.io docker-compose nano curl git

# Create directories
echo -e "${YELLOW}Creating directories...${RESET}"
mkdir -p ~/pterodactyl/panel
cd ~/pterodactyl/panel

# Create docker-compose.yml
echo -e "${YELLOW}Creating docker-compose.yml...${RESET}"
cat > docker-compose.yml <<'EOF'
version: '3.8'

x-common:
  database:
    &db-environment
    MYSQL_PASSWORD: &db-password "CHANGE_ME"
    MYSQL_ROOT_PASSWORD: "CHANGE_ME_TOO"
  panel:
    &panel-environment
    APP_URL: "https://pterodactyl.example.com"
    APP_TIMEZONE: "UTC"
    APP_SERVICE_AUTHOR: "noreply@example.com"
    TRUSTED_PROXIES: "*"
  mail:
    &mail-environment
    MAIL_FROM: "noreply@example.com"
    MAIL_DRIVER: "smtp"
    MAIL_HOST: "mail"
    MAIL_PORT: "1025"
    MAIL_USERNAME: ""
    MAIL_PASSWORD: ""
    MAIL_ENCRYPTION: "true"

services:
  database:
    image: mariadb:10.5
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - "./data/database:/var/lib/mysql"
    environment:
      <<: *db-environment
      MYSQL_DATABASE: "panel"
      MYSQL_USER: "pterodactyl"

  cache:
    image: redis:alpine
    restart: always

  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    ports:
      - "8030:80"
      - "4433:443"
    links:
      - database
      - cache
    volumes:
      - "./data/var:/app/var"
      - "./data/nginx:/etc/nginx/http.d"
      - "./data/certs:/etc/letsencrypt"
      - "./data/logs:/app/storage/logs"
    environment:
      <<: [*panel-environment, *mail-environment]
      DB_PASSWORD: *db-password
      APP_ENV: "production"
      APP_ENVIRONMENT_ONLY: "false"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"
      DB_HOST: "database"
      DB_PORT: "3306"

networks:
  default:
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

# Create required folders
echo -e "${YELLOW}Creating data folders...${RESET}"
mkdir -p ./data/{database,var,nginx,certs,logs}

# Start containers
echo -e "${YELLOW}Starting Docker containers...${RESET}"
docker-compose up -d

# Create admin user
echo -e "${YELLOW}Creating admin user...${RESET}"
docker-compose run --rm panel php artisan p:user:make

echo -e "${GREEN}=== Installation Complete! ===${RESET}"
echo -e "Panel should be available at: ${YELLOW}http://YOUR_SERVER_IP:8030${RESET}"
