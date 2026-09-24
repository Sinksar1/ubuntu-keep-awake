import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class KeepAwakeExtension extends Extension {
    enable() {
        this._toggle = new QuickSettings.QuickToggle({
            title: 'Keep Awake',
            iconName: 'caffeine-cup-symbolic',
            toggleMode: true,
        });

        // Read the real state from our script
        try {
            let [, stdout] = GLib.spawn_command_line_sync(
                'sudo -n /usr/local/bin/keep-awake status'
            );

            let status = new TextDecoder().decode(stdout).trim();
            this._toggle.checked = status.includes('ON');
        } catch (e) {
            console.error(`Keep Awake: ${e}`);
        }

        this._toggle.connect('clicked', () => {
            let action = this._toggle.checked ? 'on' : 'off';

            try {
                Gio.Subprocess.new(
                    [
                        'sudo',
                        '-n',
                        '/usr/local/bin/keep-awake',
                        action
                    ],
                    Gio.SubprocessFlags.NONE
                );
            } catch (e) {
                console.error(`Keep Awake: ${e}`);
            }
        });

        this._indicator = new QuickSettings.SystemIndicator();

        this._indicator.quickSettingsItems.push(this._toggle);

        Main.panel.statusArea.quickSettings.addExternalIndicator(
            this._indicator
        );
    }

    disable() {
        this._toggle?.destroy();
        this._toggle = null;

        this._indicator?.destroy();
        this._indicator = null;
    }
}
