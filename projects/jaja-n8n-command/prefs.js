// 🧠 JAJA N8N COMMAND EXTENSION v1.3
// ФАЙЛ: prefs.js
// НАЗНАЧЕНИЕ: Окно настроек расширения
// ОСОБЕННОСТИ:
// - Настройка URL вебхука n8n
// - Включение/отключение отправки по Enter
// - Выбор цвета кнопки
// - Управление уведомлениями

import Gtk from 'gi://Gtk';
import Gio from 'gi://Gio';
import Adw from 'gi://Adw';

/**
 * Получение объекта настроек
 * @returns {Gio.Settings} Объект настроек
 * @throws {Error} Если схема настроек не найдена
 */
function getSettings() {
    const schemaDir = Gio.File.new_for_path(import.meta.url.substring(7)).get_parent();
    const schemaSource = Gio.SettingsSchemaSource.new_from_directory(
        schemaDir.get_child('schemas').get_path(),
        Gio.SettingsSchemaSource.get_default(),
        false
    );
    
    const schema = schemaSource.lookup(
        'org.gnome.shell.extensions.jaja-n8n-command',
        false
    );
    
    if (!schema) {
        throw new Error('Схема настроек не найдена в указанном расположении');
    }
    
    return new Gio.Settings({ settings_schema: schema });
}

export default class JajaPrefs {
    constructor() {
        try {
            this._settings = getSettings();
        } catch (e) {
            logError(e, 'Не удалось загрузить настройки');
            throw e;
        }
    }

    /**
     * Заполнение окна настроек
     * @param {Adw.PreferencesWindow} window - Окно настроек
     */
    fillPreferencesWindow(window) {
        try {
            const page = new Adw.PreferencesPage();
            const group = new Adw.PreferencesGroup({
                title: 'Настройки n8n Command',
                description: 'Конфигурация интеграции с n8n',
            });

            // Настройка URL вебхука
            const urlRow = new Adw.EntryRow({
                title: 'n8n Webhook URL',
                text: this._settings.get_string('n8n-url'),
            });
            urlRow.connect('changed', (row) => {
                this._settings.set_string('n8n-url', row.get_text());
            });
            group.add(urlRow);

            // Настройка отправки по Enter
            const enterRow = new Adw.SwitchRow({
                title: 'Отправка по Enter',
                subtitle: 'Отправлять команду при нажатии Enter',
                active: this._settings.get_boolean('send-on-enter'),
            });
            enterRow.connect('notify::active', (row) => {
                this._settings.set_boolean('send-on-enter', row.active);
            });
            group.add(enterRow);

            // Настройка цвета кнопки
            const colorRow = new Adw.EntryRow({
                title: 'Цвет кнопки (HEX)',
                text: this._settings.get_string('button-color'),
            });
            colorRow.connect('changed', (row) => {
                this._settings.set_string('button-color', row.get_text());
            });
            group.add(colorRow);

            // Настройка уведомлений
            const notifyRow = new Adw.SwitchRow({
                title: 'Уведомления при отправке',
                subtitle: 'Показывать уведомление при отправке команды',
                active: this._settings.get_boolean('show-send-notify'),
            });
            notifyRow.connect('notify::active', (row) => {
                this._settings.set_boolean('show-send-notify', row.active);
            });
            group.add(notifyRow);

            page.add(group);
            window.add(page);
        } catch (e) {
            logError(e, 'Ошибка при создании интерфейса настроек');
            throw e;
        }
    }
}
