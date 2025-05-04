// extension.js
import St from 'gi://St';
import Gio from 'gi://Gio';
import Main from 'resource:///org/gnome/shell/ui/main.js';
import PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const Extension = class {
    constructor(meta) {
        this._meta = meta;
        this._indicator = null;
    }

    enable() {
        this._indicator = new PanelMenu.Button(0.0, 'n8n Command Input', false);

        // Иконка
        const iconPath = `${this._meta.path}/icons/icon-symbolic.svg`;
        const icon = new St.Icon({
            gicon: Gio.icon_new_for_string(iconPath),
            style_class: 'system-status-icon',
        });

        this._indicator.add_child(icon);

        // Меню
        const menuItem = new PopupMenu.PopupMenuItem('Открыть n8n-интерфейс команд');

        menuItem.connect('activate', () => {
            try {
                Gio.Subprocess.new(
                    ['xdg-open', 'http://localhost:5678/webhook/command-entry'],
                    Gio.SubprocessFlags.NONE
                );
            } catch (e) {
                console.error('Ошибка при открытии n8n-интерфейса:', e);
            }
        });

        this._indicator.menu.addMenuItem(menuItem);
        Main.panel.addToStatusArea('n8n-command-indicator', this._indicator);
    }

    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
};

export default Extension;
