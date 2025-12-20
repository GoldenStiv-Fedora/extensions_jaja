#!/bin/bash
# Скрипт для автоматической регулировки яркости экрана на основе датчика освещенности

# Путь к каталогу скрипта для лог-файла
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_FILE="$SCRIPT_DIR/autobrightness_new.log"
exec &>> "$LOG_FILE"
set -x

echo "$(date): Запуск скрипта автоматической регулировки яркости (Финальная версия с линейной интерполяцией)."

# Проверка наличия bc
if ! command -v bc >/dev/null 2>&1; then
    echo "$(date): Ошибка: Утилита 'bc' не найдена. Пожалуйста, установите её (sudo apt install bc)."
    exit 1
fi

# Динамическое определение устройства подсветки
BACKLIGHT_DEVICE=""
for device in /sys/class/backlight/*; do
    if [[ -d "$device" && -w "$device/brightness" ]]; then
        BACKLIGHT_DEVICE="$device"
        break
    fi
done

if [ -z "$BACKLIGHT_DEVICE" ]; then
    echo "$(date): Ошибка: Не удалось найти устройство управления подсветкой или оно недоступно для записи."
    exit 1
fi

# Динамическое определение датчика внешней освещенности
ILLUMINANCE_PATH=""
for sensor_path in /sys/bus/iio/devices/iio:device*/in_illuminance_input; do
    if [ -r "$sensor_path" ]; then
        ILLUMINANCE_PATH="$sensor_path"
        break
    fi
done

if [ -z "$ILLUMINANCE_PATH" ]; then
    echo "$(date): Ошибка: Не удалось найти датчик внешней освещенности или он недоступен для чтения."
    exit 1
fi

MAX_BRIGHTNESS=$(cat "$BACKLIGHT_DEVICE/max_brightness")
echo "$(date): Максимальная яркость подсветки: $MAX_BRIGHTNESS"

# Параметры для линейной интерполяции
MIN_SENSOR_VALUE=0
MAX_SENSOR_VALUE=100
MIN_TARGET_PERCENT=10
MAX_TARGET_PERCENT=100

# Интервал проверки датчика в секундах
CHECK_INTERVAL=1

# Функция для установки яркости
set_brightness() {
    local SENSOR_VALUE=$1

    # Проверка, находится ли значение датчика в допустимом диапазоне
    if (( SENSOR_VALUE < MIN_SENSOR_VALUE )); then
        SENSOR_VALUE=$MIN_SENSOR_VALUE
    elif (( SENSOR_VALUE > MAX_SENSOR_VALUE )); then
        SENSOR_VALUE=$MAX_SENSOR_VALUE
    fi

    # Предотвращаем деление на ноль, если диапазон датчика равен 0
    if (( (MAX_SENSOR_VALUE - MIN_SENSOR_VALUE) == 0 )); then
        echo "$(date): Ошибка: Диапазон датчика равен 0. Невозможно рассчитать яркость."
        TARGET_PERCENT_CLIPPED=$MIN_TARGET_PERCENT
    else
        # Рассчитываем целевой процент яркости с использованием линейной интерполяции
        # TARGET_PERCENT = MIN_TARGET_PERCENT + (SENSOR_VALUE - MIN_SENSOR_VALUE) * (MAX_TARGET_PERCENT - MIN_TARGET_PERCENT) / (MAX_SENSOR_VALUE - MIN_SENSOR_VALUE)
        TARGET_PERCENT_FLOAT=$(echo "scale=1; $MIN_TARGET_PERCENT + ($SENSOR_VALUE - $MIN_SENSOR_VALUE) * ($MAX_TARGET_PERCENT - $MIN_TARGET_PERCENT) / ($MAX_SENSOR_VALUE - $MIN_SENSOR_VALUE)" | bc -l)

        # Применяем общие ограничения, если вдруг расчет вышел за пределы
        TARGET_PERCENT_CLIPPED=$(echo "scale=1; if ($TARGET_PERCENT_FLOAT > $MAX_TARGET_PERCENT) $MAX_TARGET_PERCENT else if ($TARGET_PERCENT_FLOAT < $MIN_TARGET_PERCENT) $MIN_TARGET_PERCENT else $TARGET_PERCENT_FLOAT" | bc -l)
    fi

    # Рассчитываем абсолютное значение яркости, округляя до целого
    NEW_BRIGHTNESS=$(echo "scale=0; ($MAX_BRIGHTNESS * $TARGET_PERCENT_CLIPPED) / 100" | bc -l)
    
    # Получаем текущую яркость, чтобы избежать лишних записей
    CURRENT_BRIGHTNESS=$(cat "$BACKLIGHT_DEVICE/brightness")

    if (( NEW_BRIGHTNESS != CURRENT_BRIGHTNESS )); then
        echo "$(date): Датчик: $SENSOR_VALUE, Целевой процент: $TARGET_PERCENT_CLIPPED%, Новая яркость: $NEW_BRIGHTNESS (Текущая: $CURRENT_BRIGHTNESS)"
        echo "$NEW_BRIGHTNESS" > "$BACKLIGHT_DEVICE/brightness"
    else
        echo "$(date): Датчик: $SENSOR_VALUE, Целевой процент: $TARGET_PERCENT_CLIPPED%, Яркость не изменилась (Текущая: $CURRENT_BRIGHTNESS)"
    fi
}

# Основной цикл
while true; do
    ILLUMINANCE_VALUE=$(cat "$ILLUMINANCE_PATH" 2>/dev/null)

    if [ -n "$ILLUMINANCE_VALUE" ]; then
        set_brightness "$ILLUMINANCE_VALUE"
    else
        echo "$(date): Предупреждение: Не удалось прочитать значение датчика освещенности."
    fi

    sleep "$CHECK_INTERVAL"
done