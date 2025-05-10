#!/bin/bash

# n8n installer for Fedora (user-level installation)
echo "🚀 Начинаем установку n8n для обычного пользователя..."

# Удаление старой установки
echo "🧹 Удаление предыдущих установок..."
npm uninstall -g n8n 2>/dev/null

# Установка зависимостей
echo "📦 Установка зависимостей..."
sudo dnf install -y gcc-c++ make glibc-langpack-en git curl jq wget

# Установка nvm
if [ ! -d "$HOME/.nvm" ]; then
    echo "⬇️ Установка nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# Загрузка nvm в текущую сессию
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

# Установка Node.js LTS
echo "🔧 Установка Node.js LTS (22.15.0)..."
nvm install 22.15.0
nvm use 22.15.0
nvm alias default 22.15.0

# Проверка
node -v && npm -v

# Установка n8n
echo "⚙️ Установка n8n..."
npm install -g n8n

# Создание systemd службы (user-level)
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/n8n.service <<EOF
[Unit]
Description=n8n workflow automation tool (user mode)
After=network.target

[Service]
Type=simple
ExecStart=$HOME/.nvm/versions/node/v22.15.0/bin/n8n
Restart=on-failure
Environment=PATH=$HOME/.nvm/versions/node/v22.15.0/bin:/usr/bin:/bin
WorkingDirectory=$HOME

[Install]
WantedBy=default.target
EOF

# Активация и запуск
echo "🟢 Запускаем n8n как user systemd-сервис..."
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable n8n
systemctl --user start n8n

# Включение linger для автозапуска после выхода
loginctl enable-linger "$USER"

# Ожидаем запуск
sleep 3

# Получаем ссылку
IP=$(hostname -I | awk '{print $1}')
PORT=5678
echo ""
echo "✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo "🌐 ВОЙДИТЕ В n8n ПО ССЫЛКЕ: http://$IP:$PORT"

