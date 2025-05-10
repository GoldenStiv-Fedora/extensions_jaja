#!/bin/bash
# Скрипт установки расширений GNOME из репозитория GitHub
# Версия: 1.0
# Автор: GoldenStiv
# Для GNOME 47+ (Wayland)
#Запуск скрипта: chmod +x install_jaja_extension.sh && ./install_jaja_extension.sh

# Описание:
# Этот скрипт автоматически:
# 1. Клонирует репозиторий с расширениями
# 2. Устанавливает расширение jaja-n8n-command
# 3. Компилирует схемы GSettings
# 4. Очищает временные файлы
# 5. Не включает расширения автоматически (нужно сделать вручную после перезагрузки)

# Конфигурация
REPO_URL="https://github.com/GoldenStiv-Fedora/extensions_jaja.git"
TMP_DIR="$HOME/Downloads/gnome-extensions-tmp"
EXTENSION_ID="jaja-n8n-command@jaja.goldenstiv"
EXTENSION_DIR="$HOME/.local/share/gnome-shell/extensions/$EXTENSION_ID"
EXTENSION_SOURCE="$TMP_DIR/jaja-n8n-command"

# Функция для вывода сообщений с цветом
function message {
    case $1 in
        info)    echo -e "\033[1;34m$2\033[0m" ;;  # Синий
        success) echo -e "\033[1;32m$2\033[0m" ;;  # Зеленый
        warning) echo -e "\033[1;33m$2\033[0m" ;;  # Желтый
        error)   echo -e "\033[1;31m$2\033[0m" ;;  # Красный
        *)       echo -e "$2" ;;
    esac
}

# Проверяем зависимости
function check_dependencies {
    local missing=()
    
    # Проверяем наличие glib-compile-schemas
    if ! command -v glib-compile-schemas &> /dev/null; then
        missing+=("glib2")
    fi
    
    # Проверяем наличие git
    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi
    
    # Если есть отсутствующие зависимости
    if [ ${#missing[@]} -gt 0 ]; then
        message error "Отсутствуют необходимые пакеты: ${missing[*]}"
        message info "Установите их командой:"
        message info "sudo dnf install ${missing[*]}"
        exit 1
    fi
}

# Очистка временных файлов
function cleanup {
    message info "Очистка временных файлов..."
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
        message success "Временные файлы удалены"
    fi
}

# Основная функция установки
function install_extension {
    message info "Начало установки расширения $EXTENSION_ID"
    
    # Проверяем зависимости
    check_dependencies
    
    # Создаем временную директорию
    mkdir -p "$TMP_DIR"
    
    # Клонируем репозиторий
    message info "Клонирование репозитория..."
    git clone "$REPO_URL" "$TMP_DIR" || {
        message error "Ошибка при клонировании репозитория"
        exit 1
    }
    message success "Репо успешно склонирован в $TMP_DIR"
    
    # Проверяем наличие исходников расширения
    if [ ! -d "$EXTENSION_SOURCE" ]; then
        message error "Директория с расширением не найдена: $EXTENSION_SOURCE"
        cleanup
        exit 1
    fi
    
    # Создаем директорию для расширения
    message info "Создание директории расширения..."
    mkdir -p "$EXTENSION_DIR"
    
    # Копируем файлы расширения
    message info "Копирование файлов расширения..."
    cp -r "$EXTENSION_SOURCE"/* "$EXTENSION_DIR/" || {
        message error "Ошибка при копировании файлов расширения"
        cleanup
        exit 1
    }
    
    # Компилируем схемы GSettings
    message info "Компиляция схем GSettings..."
    if [ -d "$EXTENSION_DIR/schemas" ]; then
        glib-compile-schemas "$EXTENSION_DIR/schemas" || {
            message error "Ошибка при компиляции схем GSettings"
            cleanup
            exit 1
        }
        message success "Схемы GSettings успешно скомпилированы"
    else
        message warning "Директория schemas не найдена, компиляция не выполнена"
    fi
    
    # Проверяем наличие иконок
    if [ ! -f "$EXTENSION_DIR/connect.png" ] || [ ! -f "$EXTENSION_DIR/disconnect.png" ]; then
        message warning "Иконки connect.png и/или disconnect.png не найдены в $EXTENSION_DIR"
        message info "Пожалуйста, добавьте их вручную для корректного отображения статуса"
    fi
    
    # Устанавливаем правильные разрешения
    message info "Установка разрешений..."
    chmod -R 755 "$EXTENSION_DIR"
    
    # Проверяем установку
    if [ -f "$EXTENSION_DIR/metadata.json" ]; then
        message success "Расширение успешно установлено в $EXTENSION_DIR"
    else
        message error "Что-то пошло не так, metadata.json не найден"
        cleanup
        exit 1
    fi
    
    # Очистка
    cleanup

    # === УВЕДОМЛЕНИЕ ===
   notify-send "JAJA Extension" "Расширение успешно установлено и включено 🎉"

    # Финал
    message success "Установка завершена успешно!"
    message info "Для активации расширения:"
    message info "1. Перезагрузите GNOME (Alt+F2, введите 'r' и нажмите Enter)"
    message info "2. Включите расширение в 'Расширения' или через 'gnome-extensions-app'"
    message info "3. Настройте расширение через 'gnome-extensions-app'"
}

# Запускаем установку
install_extension
