#!/bin/bash
#Запуск: chmod +x install_jaja_extension.sh && ./install_jaja_extension.sh
 

# === ПАРАМЕТРЫ ===
EXTENSION_ID="jaja-n8n-command@jaja.goldenstiv"
REPO_URL="https://github.com/GoldenStiv-Fedora/extensions_jaja.git"
LOCAL_DIR="$HOME/.local/share/gnome-shell/extensions/$EXTENSION_ID"

# === СКАЧИВАЕМ РЕПО ===
echo "[JAJA Installer] Клонируем репозиторий..."
git clone --depth=1 "$REPO_URL" /tmp/jaja-extension || {
    echo "Ошибка при клонировании репозитория"
    exit 1
}

# === СОЗДАЕМ ПАПКУ И КОПИРУЕМ ФАЙЛЫ ===
mkdir -p "$LOCAL_DIR"
cp -r /tmp/jaja-extension/jaja-n8n-command/* "$LOCAL_DIR"

# === УДАЛЯЕМ ВРЕМЕННЫЕ ФАЙЛЫ ===
rm -rf /tmp/jaja-extension

# === ОБНОВЛЯЕМ СПИСОК РАСШИРЕНИЙ ===
echo "[JAJA Installer] Обновляем список расширений..."
gnome-extensions reset "$EXTENSION_ID" 2>/dev/null
gnome-extensions enable "$EXTENSION_ID"

# === ПЕРЕЗАПУСК ОБОЛОЧКИ (Только X11) ===
if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
    echo "[JAJA Installer] Перезапуск GNOME Shell..."
    echo "r" | gnome-shell --replace &
else
    echo "[JAJA Installer] На Wayland необходимо выйти и зайти заново, чтобы активировать расширение."
fi

# === УВЕДОМЛЕНИЕ ===
notify-send "JAJA Extension" "Расширение успешно установлено и включено 🎉"

echo "[JAJA Installer] Установка завершена."
