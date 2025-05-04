// extension.js

import * as St from 'gi://St';
import * as Gio from 'gi://Gio';
import * as GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as MessageTray from 'resource:///org/gnome/shell/ui/messageTray.js';


let jajaIndicator;

class JajaCommandIndicator extends PanelMenu.Button {
    constructor() {
        super(0.0, 'JAJA Command Button', false);

        const icon = new St.Icon({
            gicon: Gio.icon_new_for_string(Me.dir.get_path() + '/icon.svg'),
            style_class: 'system-status-icon',
        });

        this.add_child(icon);

        const entryItem = new PopupMenu.PopupBaseMenuItem({ reactive: false });
        this.entry = new St.Entry({
            hint_text: 'Введите команду для JAJA',
            track_hover: true,
            can_focus: true,
        });

        entryItem.add_child(this.entry);
        this.menu.addMenuItem(entryItem);

        const sendItem = new PopupMenu.PopupMenuItem('Отправить');
        sendItem.connect('activate', () => {
            let command = this.entry.get_text();
            this.sendCommand(command);
        });

        this.menu.addMenuItem(sendItem);
    }

    sendCommand(command) {
        try {
            let subprocess = Gio.Subprocess.new(
                ['curl', '-X', 'POST', '-H', 'Content-Type: application/json',
                 '-d', JSON.stringify({ text: command }),
                 'http://localhost:5678/webhook/command-input'],
                Gio.SubprocessFlags.NONE
            );

            subprocess.init(null);
            this._showNotification('Команда отправлена', command);
        } catch (e) {
            this._showNotification('Ошибка', e.message);
        }
    }

    _showNotification(title, text) {
        const source = new MessageTray.SystemNotificationSource();
        Main.messageTray.add(source);

        const notification = new MessageTray.Notification(source, title, text);
        notification.setTransient(true);
        source.notify(notification);
    }
}

function init() {}

function enable() {
    jajaIndicator = new JajaCommandIndicator();
    Main.panel.addToStatusArea('jaja-n8n-command', jajaIndicator);
}

function disable() {
    if (jajaIndicator) {
        jajaIndicator.destroy();
        jajaIndicator = null;
    }
}
