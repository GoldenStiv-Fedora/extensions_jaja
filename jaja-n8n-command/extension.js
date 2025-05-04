// extension.js
import * as St from 'gi://St';
import * as Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

let indicator = null;

const Extension = class {
    enable() {
        indicator = new PanelMenu.Button(0.0, 'n8n Command Input', false);

        const icon = new St.Icon({
            gicon: Gio.icon_new_for_string(`${Me.path}/icons/icon-symbolic.svg`),
            style_class: 'system-status-icon',
        });

        indicator.add_child(icon);

        const menuItem = new PopupMenu.PopupMenuItem('Открыть n8n-интерфейс команд');

        menuItem.connect('activate', () => {
            try {
                Gio.Subprocess.new(
                    ['xdg-open', 'http://localhost:5678/webhook/command-entry'],
                    Gio.SubprocessFlags.NONE
                );
            } catch (e) {
                logError(e, 'Ошибка запуска интерфейса команд');
            }
        });

        indicator.menu.addMenuItem(menuItem);
        Main.panel.addToStatusArea('n8n-command-indicator', indicator);
    }

    disable() {
        if (indicator) {
            indicator.destroy();
            indicator = null;
        }
    }

    init() {
        // можно оставить пустым
    }
};

export default Extension;
