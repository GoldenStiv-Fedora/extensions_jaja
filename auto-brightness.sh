#!/bin/bash

# ==============================================================================
# Скрипт: auto-brightness.sh
# Назначение: Автоматическая регулировка яркости экрана на основе датчика внешней освещенности.
#             Скрипт предназначен для автономной установки и настройки себя как
#             системного сервиса.
# Версия: 1.0.0
# Автор: Jaja (Gemini CLI Agent)
# Протестировано на ОС: Linux Mint 22.2 (Zara)
# Язык описания: Русский
#
# Как пользоваться:
# 1. Сделайте скрипт исполняемым: `chmod +x auto-brightness.sh`
# 2. Запустите скрипт с правами root для установки и активации сервиса:
#    `sudo ./auto-brightness.sh install`
# 3. Для удаления сервиса: `sudo ./auto-brightness.sh uninstall`
# 4. Для ручного запуска/остановки:
#    `sudo systemctl start auto-brightness.service`
#    `sudo systemctl stop auto-brightness.service`
#    `sudo systemctl status auto-brightness.service`
#
# Вспомогательные файлы/директории:
# - Создает файл сервиса systemd: `/etc/systemd/system/auto-brightness.service`
# - Создает лог-файл: `/var/log/auto-brightness.log`
# - Требует наличия датчика освещенности, доступного через `/sys/bus/iio/devices/iio:device*/in_illuminance_input`.
# - Требует наличия устройства подсветки, доступного через `/sys/class/backlight/*/brightness`.
#
# Зависимости:
# - `bc`: Утилита для выполнения арифметических операций. Скрипт проверит и предложит установить.
# - `systemd`: Система инициализации (стандартная для большинства современных Linux).
#
# Механизм работы:
# 1. Динамически определяет пути к устройству подсветки и датчику освещенности.
# 2. Читает значение датчика освещенности.
# 3. Применяет линейную интерполяцию для вычисления целевого уровня яркости.
# 4. Устанавливает яркость, если она отличается от текущей, чтобы избежать лишних записей.
# 5. Ведет лог-файл для отслеживания работы.
#
# Автономность:
# Скрипт самостоятельно проверяет и устанавливает необходимые зависимости (`bc`).
# При запуске с аргументом `install` он создает и активирует systemd сервис,
# обеспечивая автозапуск при старте системы.
# ==============================================================================

# Лог-файл
LOG_FILE="/var/log/auto-brightness.log"
# Перенаправляем весь вывод скрипта в лог-файл
exec &>> "$LOG_FILE"
set -x

echo "$(date): Запуск скрипта автоматической регулировки яркости (Финальная версия с линейной интерполяцией)."

# --- Вспомогательные функции ---

log_message() {
    echo "$(date): $1"
    # Для интерактивного вывода, если скрипт запущен не как сервис
    if [[ -t 1 ]]; then
        echo "$1" >&2 # Выводим в stderr, чтобы не дублировать в логе
    fi
}

check_and_install_bc() {
    if ! command -v bc >/dev/null 2>&1; then
        log_message "Утилита 'bc' не найдена. Пытаюсь установить..."
        if sudo apt update && sudo apt install -y bc; then
            log_message "Утилита 'bc' успешно установлена."
        else
            log_message "Ошибка: Не удалось установить 'bc'. Пожалуйста, установите её вручную: sudo apt install bc."
            exit 1
        fi
    fi
}

find_backlight_device() {
    for device in /sys/class/backlight/*; do
        if [[ -d "$device" && -w "$device/brightness" ]]; then
            echo "$device"
            return 0
        fi
    done
    return 1
}

find_illuminance_sensor() {
    for sensor_path in /sys/bus/iio/devices/iio:device*/in_illuminance_input; do
        if [ -r "$sensor_path" ]; then
            echo "$sensor_path"
            return 0
        fi
    done
    return 1
}

# --- Параметры ---
BACKLIGHT_DEVICE=""
ILLUMINANCE_PATH=""
MAX_BRIGHTNESS=0
MIN_SENSOR_VALUE=0
MAX_SENSOR_VALUE=100
MIN_TARGET_PERCENT=10
MAX_TARGET_PERCENT=100
CHECK_INTERVAL=1 # Интервал проверки датчика в секундах

# --- Основная логика работы сервиса ---
run_service() {
    log_message "Инициализация параметров..."
    BACKLIGHT_DEVICE=$(find_backlight_device)
    if [ $? -ne 0 ]; then
        log_message "Ошибка: Не удалось найти устройство управления подсветкой или оно недоступно для записи. Завершение работы."
        exit 1
    fi

    ILLUMINANCE_PATH=$(find_illuminance_sensor)
    if [ $? -ne 0 ]; then
        log_message "Ошибка: Не удалось найти датчик внешней освещенности или он недоступен для чтения. Завершение работы."
        exit 1
    fi

    MAX_BRIGHTNESS=$(cat "$BACKLIGHT_DEVICE/max_brightness")
    log_message "Максимальная яркость подсветки: $MAX_BRIGHTNESS"

    # Функция для установки яркости
    set_brightness() {
        local SENSOR_VALUE=$1

        # Проверка, находится ли значение датчика в допустимом диапазоне
        if (( SENSOR_VALUE < MIN_SENSOR_VALUE )); then
            SENSOR_VALUE=$MIN_SENSOR_VALUE
        elif (( SENSOR_VALUE > MAX_SENSOR_VALUE )); then
            SENSOR_VALUE=$MAX_SENSOR_VALUE
        fi

        # Предотвращаем деление на ноль
        if (( (MAX_SENSOR_VALUE - MIN_SENSOR_VALUE) == 0 )); then
            log_message "Ошибка: Диапазон датчика равен 0. Невозможно рассчитать яркость."
            TARGET_PERCENT_CLIPPED=$MIN_TARGET_PERCENT
        else
            TARGET_PERCENT_FLOAT=$(echo "scale=1; $MIN_TARGET_PERCENT + ($SENSOR_VALUE - $MIN_SENSOR_VALUE) * ($MAX_TARGET_PERCENT - $MIN_TARGET_PERCENT) / ($MAX_SENSOR_VALUE - $MIN_SENSOR_VALUE)" | bc -l)
            TARGET_PERCENT_CLIPPED=$(echo "scale=1; if ($TARGET_PERCENT_FLOAT > $MAX_TARGET_PERCENT) $MAX_TARGET_PERCENT else if ($TARGET_PERCENT_FLOAT < $MIN_TARGET_PERCENT) $MIN_TARGET_PERCENT else $TARGET_PERCENT_FLOAT" | bc -l)
        fi

        NEW_BRIGHTNESS=$(echo "scale=0; ($MAX_BRIGHTNESS * $TARGET_PERCENT_CLIPPED) / 100" | bc -l)
        
        CURRENT_BRIGHTNESS=$(cat "$BACKLIGHT_DEVICE/brightness")

        if (( NEW_BRIGHTNESS != CURRENT_BRIGHTNESS )); then
            log_message "Датчик: $SENSOR_VALUE, Целевой процент: $TARGET_PERCENT_CLIPPED%, Новая яркость: $NEW_BRIGHTNESS (Текущая: $CURRENT_BRIGHTNESS)"
            echo "$NEW_BRIGHTNESS" > "$BACKLIGHT_DEVICE/brightness"
        else
            log_message "Датчик: $SENSOR_VALUE, Целевой процент: $TARGET_PERCENT_CLIPPED%, Яркость не изменилась (Текущая: $CURRENT_BRIGHTNESS)"
        fi
    }

    # Основной цикл
    while true; do
        ILLUMINANCE_VALUE=$(cat "$ILLUMINANCE_PATH" 2>/dev/null)

        if [ -n "$ILLUMINANCE_VALUE" ]; then
            set_brightness "$ILLUMINANCE_VALUE"
        else
            log_message "Предупреждение: Не удалось прочитать значение датчика освещенности."
        fi

        sleep "$CHECK_INTERVAL"
    done
}

# --- Управление сервисом systemd ---

SERVICE_FILE_CONTENT="[Unit]
Description=Automatic screen brightness adjustment
After=systemd-user-sessions.service multi-user.target graphical.target

[Service]
ExecStart=$(readlink -f "$0") run_service
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target"

install_service() {
    log_message "Проверка и установка утилиты 'bc'..."
    check_and_install_bc

    log_message "Установка systemd сервиса auto-brightness..."
    if [ "$(id -u)" -ne 0 ]; then
        log_message "Ошибка: Для установки сервиса требуются права root. Запустите 'sudo $0 install'."
        exit 1
    fi

    echo "$SERVICE_FILE_CONTENT" | sudo tee "/etc/systemd/system/auto-brightness.service" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable auto-brightness.service
    sudo systemctl start auto-brightness.service
    log_message "Сервис auto-brightness успешно установлен и запущен."
    log_message "Для проверки статуса: sudo systemctl status auto-brightness.service"
}

uninstall_service() {
    log_message "Удаление systemd сервиса auto-brightness..."
    if [ "$(id -u)" -ne 0 ]; then
        log_message "Ошибка: Для удаления сервиса требуются права root. Запустите 'sudo $0 uninstall'."
        exit 1
    fi

    sudo systemctl stop auto-brightness.service
    sudo systemctl disable auto-brightness.service
    sudo rm "/etc/systemd/system/auto-brightness.service"
    sudo systemctl daemon-reload
    log_message "Сервис auto-brightness успешно удален."
}

# --- Обработка аргументов командной строки ---
case "$1" in
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    run_service)
        # Этот аргумент используется systemd для запуска основной логики скрипта
        run_service
        ;;
    *)
        log_message "Неизвестный аргумент или запуск без аргументов. Используйте 'install' или 'uninstall'."
        log_message "Запуск скрипта без аргументов не поддерживается для непосредственной работы, используйте systemd сервис."
        exit 1
        ;;
esac
