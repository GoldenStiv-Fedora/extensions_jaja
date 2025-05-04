import St from 'gi://St';
import Main from 'resource:///org/gnome/shell/ui/main.js';
import PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import { Gio, GLib, Soup } from 'gi://Gio';
import PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

let JaJaExtension;

class JajaCommandExtension extends PanelMenu.Button {
  constructor() {
    super(0.0, 'JAJA N8N Command', false);

    const icon = new St.Icon({
      gicon: Gio.icon_new_for_string(Me.path + '/icon.svg'),
      style_class: 'system-status-icon',
    });
    this.add_child(icon);

    // Поле ввода команды
    const box = new St.BoxLayout({ vertical: false });
    this.entry = new St.Entry({ style_class: 'jaja-entry', can_focus: true });
    box.add_child(this.entry);

    // Кнопка отправки
    const button = new St.Button({ label: 'Отправить', style_class: 'jaja-button' });
    button.connect('clicked', () => this._sendCommand());
    box.add_child(button);

    const item = new PopupMenu.PopupBaseMenuItem({ reactive: false });
    item.actor.add_child(box);
    this.menu.addMenuItem(item);
  }

  _sendCommand() {
    const session = new Soup.Session();
    const message = Soup.form_request_new_from_hash('POST', 'http://localhost:5678/webhook/command-input', {
      command: this.entry.get_text(),
    });
    session.send_and_read_async(message, 0, null, null);
    Main.notify('JAJA Agent', `Команда отправлена: ${this.entry.get_text()}`);
    this.entry.set_text('');
  }
}

function init() {}

function enable() {
  JaJaExtension = new JajaCommandExtension();
  Main.panel.addToStatusArea('jaja-n8n-command', JaJaExtension);
}

function disable() {
  JaJaExtension.destroy();
}
