# Keep Awake for Ubuntu

An Amphetamine-style **Keep Awake** toggle in GNOME Quick Settings for Ubuntu
24.04 / GNOME Shell 46. The backend runs `systemd-inhibit` with
`--what=handle-lid-switch:sleep --mode=block` to keep Ubuntu running when the
laptop lid closes. SSH, RDP, TeamViewer, VPN and background services can keep
running, provided their own configuration and network connection permit it.

## Requirements

- Ubuntu 24.04 with GNOME Shell 46 and systemd-logind.
- `bash`, `sudo`, `visudo`, `systemd-inhibit`, GNOME Shell and standard Ubuntu
  core utilities. These are normally included in the desktop installation.
- Administrator access for installation; a non-root desktop login for the toggle.

## Install

Review the scripts, then run from this repository:

```sh
sudo ./install.sh
```

The installer derives the allowed login from `SUDO_USER`. To choose another
existing desktop account, or when installing from a root shell:

```sh
sudo ./install.sh --user YOUR_LOGIN
```

Log out and back in so GNOME discovers the system-wide extension. In a terminal
inside the chosen user's GNOME session, run **without sudo**:

```sh
gnome-extensions enable keepawake@fitz
```

Open Quick Settings and switch **Keep Awake** on. On Wayland, logging out and
back in is necessary to reload Shell; an in-place Shell restart is unavailable.
A user-installed extension with the same UUID can shadow this system-wide copy;
check `gnome-extensions info keepawake@fitz` if the expected version does not load.

## Use and verify

```sh
sudo -n /usr/local/bin/keep-awake on
sudo -n /usr/local/bin/keep-awake status
systemd-inhibit --list
sudo -n /usr/local/bin/keep-awake off
```

While on, the inhibitor list should contain **Keep Awake**, with `sleep` and
`handle-lid-switch` in block mode. Confirm remote access while the lid is open,
then close it and confirm the connection still works. Turning the toggle off
releases the inhibitor; Ubuntu's normal power policy applies again.

The inhibitor does not disable screen locking, configure remote access, maintain
VPN connectivity, or start any network services. It is not persistent across
reboots. Keep ventilation clear when running a laptop with its lid closed.

## Installation and sudo security

The installer supports only Ubuntu 24.04 / GNOME 46. It installs:

| Destination | Owner | Mode |
| --- | --- | --- |
| `/usr/local/bin/keep-awake` | `root:root` | `0755` |
| `/usr/share/gnome-shell/extensions/keepawake@fitz/extension.js` | `root:root` | `0644` |
| `/usr/share/gnome-shell/extensions/keepawake@fitz/metadata.json` | `root:root` | `0644` |
| `/etc/sudoers.d/keep-awake` | `root:root` | `0440` |

The generated drop-in grants the selected login only these exact commands:

```sudoers
YOUR_LOGIN ALL=(root) NOPASSWD: NOSETENV: /usr/local/bin/keep-awake on, /usr/local/bin/keep-awake off, /usr/local/bin/keep-awake status
```

There are no command wildcards, unrestricted passwordless sudo grants, or changes
to global sudo defaults. Login names are validated before interpolation. The
extension uses `sudo -n`, so it cannot open a password prompt from Quick Settings.
Ubuntu's normal sudo environment reset and secure PATH must remain enabled: the
preserved backend invokes standard commands by name. Privileged destination
parents must remain owned and writable only by trusted administrators.

The installer checks the current configuration using `visudo -c`, validates the
candidate drop-in with `visudo -cf`, and runs `visudo -c` again after installation.
It restores the previous drop-in if the final check fails. Program files remain
installed if that final validation fails. Installation is not a full transactional
backup system; back up existing custom files before installing over them.

Re-running installation replaces these files and replaces the allowed login in
this project's drop-in. It does not append duplicate rules. The extension is
visible system-wide, but only the selected login gets this passwordless grant.
Other sudoers rules remain in effect and may grant additional privileges.

## Uninstall

As the desktop user, first disable the extension:

```sh
gnome-extensions disable keepawake@fitz
systemd-inhibit --list
sudo -n /usr/local/bin/keep-awake off
sudo ./uninstall.sh
```

Log out and back in afterward. Uninstallation removes the installed backend,
the two extension files, and this project's sudoers drop-in. It checks the full
sudoers configuration before and after removing the rule and restores it on
validation failure. Other files in the extension directory are retained.
It does not restore versions overwritten during installation.

## Provenance and current limitations

`bin/keep-awake`, `extension.js`, and `metadata.json` were copied byte-for-byte
from the user's tested system-wide Ubuntu installation. The original backend
credit is retained. The packaging scripts are new. The existing sudoers file
could not be read during packaging because elevated access required a password;
the rule above is newly generated, not a copy of that unread file.

The original implementation intentionally remains unchanged:

- The backend records a PID in `/run/keep-awake.pid`. It does not lock concurrent
  operations or verify process identity. A stale, reused PID could report the
  wrong state or cause `off` to signal an unrelated process. Verify a suspicious
  PID against the inhibitor list before stopping it; do not rapidly toggle from
  multiple sessions. The uninstaller refuses to run while this PID file exists.
- `on` reports success before confirming inhibitor acquisition. Use
  `systemd-inhibit --list` to verify the actual lock.
- The toggle reads status when enabled, then launches commands asynchronously
  without checking their exit status or polling external state. A checked toggle
  alone is not proof that inhibition succeeded. Disabling the extension does
  not release an active inhibitor; use `off` explicitly.
- GNOME versions other than 46 are not declared supported.

## Development checks

```sh
bash -n install.sh uninstall.sh bin/keep-awake
python3 -m json.tool gnome-extension/keepawake@fitz/metadata.json
node --input-type=module --check < gnome-extension/keepawake@fitz/extension.js
python3 tests/check.py
```

The test uses an isolated copy of the backend, a temporary PID file, and mocked
commands. It does not acquire a real inhibitor or change system files. JavaScript
syntax validation does not validate GNOME APIs. Installation, sudo authorization,
GNOME rendering, and physical lid behavior need a real desktop integration test.

## License

MIT; see [LICENSE](LICENSE). The original script credit remains in the backend.
