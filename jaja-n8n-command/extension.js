// 🧠 JAJA N8N COMMAND EXTENSION v1.3
// ФАЙЛ: extension.js
// НАЗНАЧЕНИЕ: Основной файл расширения GNOME Shell для работы с n8n
// ОСОБЕННОСТИ:
// - Отправка команд в n8n через вебхук
// - История последних 5 команд
// - Настраиваемый интерфейс
// - Уведомления о выполнении команд

import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

export default class Extension {
    /**
     * Конструктор класса расширения
     * @param {object} metadata - Метаданные расширения
     */
    constructor(metadata) {
        this._meta = metadata;       // Метаданные расширения
        this._indicator = null;      // Индикатор на панели
        this._settings = null;       // Настройки расширения
        this._history = [];         // История команд (максимум 10)
        this._entry = null;          // Поле ввода команды
    }

    /**
     * Загрузка настроек из GSettings
     * @returns {boolean} Успешность загрузки настроек
     */
    _loadSettings() {
        try {
            const schemaDir = Gio.File.new_for_path(`${this._meta.path}/schemas`);
            const schemaSource = Gio.SettingsSchemaSource.new_from_directory(
                schemaDir.get_path(),
                Gio.SettingsSchemaSource.get_default(),
                false
            );
            const schema = schemaSource.lookup('org.gnome.shell.extensions.jaja-n8n-command', true);
            this._settings = new Gio.Settings({ settings_schema: schema });
            return true;
        } catch (e) {
            console.error('Ошибка загрузки настроек:', e);
            return false;
        }
    }

    /**
     * Включение расширения
     */
    enable() {
        if (!this._loadSettings()) {
            console.error('Не удалось загрузить настройки, расширение отключено');
            return;
        }

        // Создание индикатора на панели
        this._indicator = new PanelMenu.Button(0.0, 'n8n Command', false);
        
        // Установка иконки
        const iconFile = Gio.File.new_for_path(`${this._meta.path}/connect.png`);
        const icon = new St.Icon({
            gicon: new Gio.FileIcon({ file: iconFile }),
            style_class: 'system-status-icon',
            icon_size: 22
        });
        this._indicator.add_child(icon);

        // Создание контейнера для элементов интерфейса
        const container = new PopupMenu.PopupBaseMenuItem({ reactive: false });
        const box = new St.BoxLayout({ vertical: false, style_class: 'n8n-input-box' });

        // Поле ввода команды
        this._entry = new St.Entry({
            style_class: 'n8n-command-entry',
            hint_text: 'Введите команду для n8n',
            can_focus: true,
            x_expand: true
        });

        // Кнопка отправки
        const sendButton = new St.Button({ 
            label: 'Отправить', 
            style_class: 'n8n-send-button' 
        });
        this._updateButtonStyle(sendButton);
        this._settings.connect('changed::button-color', () => this._updateButtonStyle(sendButton));

        // Меню истории команд
        const historyMenu = new PopupMenu.PopupSubMenuMenuItem('История команд');
        this._updateHistoryMenu(historyMenu);

        // Сборка интерфейса
        box.add_child(this._entry);
        box.add_child(sendButton);
        container.actor.add_child(box);
        this._indicator.menu.addMenuItem(container);
        this._indicator.menu.addMenuItem(historyMenu);
        Main.panel.addToStatusArea(this._meta.uuid, this._indicator);

        // Обработчики событий
        sendButton.connect('clicked', () => this._sendCommand(this._entry));
        this._entry.clutter_text.connect('key-press-event', (_, event) => {
            const key = event.get_key_symbol();
            if ((key === Clutter.KEY_Return || key === Clutter.KEY_KP_Enter) &&
                this._settings.get_boolean('send-on-enter')) {
                this._sendCommand(this._entry);
                return Clutter.EVENT_STOP;
            }
            return Clutter.EVENT_PROPAGATE;
        });
    }

    /**
     * Обновление стиля кнопки отправки
     * @param {St.Button} button - Кнопка для стилизации
     */
    _updateButtonStyle(button) {
        const color = this._settings.get_string('button-color');
        button.style = `
            background-color: ${color};
            color: white;
            border-radius: 5px;
            padding: 6px 12px;
            margin-left: 8px;
        `;
    }

    /**
     * Добавление команды в историю
     * @param {string} cmd - Команда для добавления в историю
     */
    _addToHistory(cmd) {
        if (this._history.length >= 10) {
            this._history.shift();
        }
        this._history.push(cmd);
    }

    /**
     * Обновление меню истории команд
     * @param {PopupMenu.PopupSubMenuMenuItem} menu - Меню для обновления
     */
    _updateHistoryMenu(menu) {
        menu.menu.removeAll();
        this._history.slice().reverse().forEach(cmd => {
            const item = new PopupMenu.PopupMenuItem(cmd);
            item.connect('activate', () => {
                this._entry.set_text(cmd);
                this._entry.grab_key_focus();
                this._sendCommand(this._entry);
            });
            menu.menu.addMenuItem(item);
        });
    }

    /**
     * Отправка команды в n8n
     * @param {St.Entry} entry - Поле ввода команды
     */
    async _sendCommand(entry) {
        const text = entry.get_text().trim();
        if (!text) return;

        // Уведомление о отправке (если включено в настройках)
        const showNotify = this._settings.get_boolean('show-send-notify');
        if (showNotify) {
            Main.notify('JAJA n8n', `Команда отправлена: ${text}`);
        }

        // Добавление в историю и обновление меню
        this._addToHistory(text);
        this._updateHistoryMenu(this._indicator.menu._getMenuItems()[1]);

        // Формирование и отправка команды curl
        const url = this._settings.get_string('n8n-url');
        const escaped = JSON.stringify(text).slice(1, -1); // Экранирование для команд с пробелами
        const cmd = `curl -s -X POST -H 'Content-Type: application/json' -d '{"cmd":"${escaped}"}' '${url}'`;

        try {
            const [success, output] = await this._executeCommand(cmd);
            if (!success) {
                Main.notifyError('JAJA n8n', output || 'Ошибка при выполнении команды');
            }
            entry.set_text('');
        } catch (e) {
            Main.notifyError('JAJA n8n', e.message || 'Неизвестная ошибка');
        }
    }

    /**
     * Выполнение shell-команды
     * @param {string} command - Команда для выполнения
     * @returns {Promise<[boolean, string]>} Результат выполнения [успех, вывод]
     */
    _executeCommand(command) {
        return new Promise((resolve) => {
            const proc = Gio.Subprocess.new(
                ['bash', '-c', command],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
            proc.wait_async(null, (proc, res) => {
                try {
                    const success = proc.wait_finish(res);
                    const [status, stdout, stderr] = proc.communicate_utf8(null, null);
                    resolve([success, stdout || stderr]);
                } catch (e) {
                    resolve([false, e.message]);
                }
            });
        });
    }

    /**
     * Отключение расширения
     */
    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
        this._settings = null;
        this._history = [];
        this._entry = null;
    }
}
