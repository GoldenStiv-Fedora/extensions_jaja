// extension.js
import St from 'gi://St';
import Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const Extension = class {
    constructor(metadata) {
        this._meta = metadata;
        this._indicator = null;
    }

    enable() {
        this._indicator = new PanelMenu.Button(0.0, 'n8n Command Entry', false);

        const icon = new St.Icon({
            gicon: Gio.icon_new_for_string(`${this._meta.path}/icons.svg`),
            style_class: 'system-status-icon',
        });

        this._indicator.add_child(icon);

        const menuItem = new PopupMenu.PopupMenuItem('Ввести команду n8n');

        menuItem.connect('activate', () => {
            try {
                Gio.Subprocess.new(
                    ['xdg-open', 'http://localhost:5678/webhook/command-entry'],
                    Gio.SubprocessFlags.NONE
                );
            } catch (e) {
                console.error('Ошибка при запуске команды:', e);
            }
        });

        this._indicator.menu.addMenuItem(menuItem);
        Main.panel.addToStatusArea('n8n-command-entry', this._indicator);
    }

    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
};

export default Extension;
