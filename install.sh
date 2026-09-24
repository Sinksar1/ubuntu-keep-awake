#!/bin/bash
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
usage() { echo "Usage: sudo ./install.sh [--user LOGIN]"; }
fail() { echo "Error: $*" >&2; exit 1; }
user=${SUDO_USER:-}
if [[ $# == 1 && $1 == --help ]]; then usage; exit 0; fi
if [[ $# == 2 && $1 == --user ]]; then user=$2
elif [[ $# != 0 ]]; then usage >&2; exit 1; fi
[[ $EUID == 0 ]] || fail 'Run with sudo.'
# Restrict sudoers syntax; never interpolate arbitrary account names.
[[ $user =~ ^[a-zA-Z_][a-zA-Z0-9_.@-]*$ && $user != root ]] || fail 'Specify a non-root login with --user LOGIN.'
id "$user" >/dev/null 2>&1 || fail "Unknown login: $user"
[[ $(id -u "$user") != 0 ]] || fail 'The selected login must not have UID 0.'
. /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || fail 'Ubuntu 24.04 is required.'
for tool in gnome-shell systemd-inhibit sudo visudo install; do
    command -v "$tool" >/dev/null || fail "Missing dependency: $tool"
done
[[ $(gnome-shell --version) == 'GNOME Shell 46.'* ]] || fail 'GNOME Shell 46 is required.'
src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
for file in bin/keep-awake gnome-extension/keepawake@fitz/extension.js gnome-extension/keepawake@fitz/metadata.json; do
    [[ -f $src/$file ]] || fail "Missing source: $file"
done
# Refuse redirected destinations before writing privileged files.
for dest in /usr/local /usr/local/bin /usr/local/bin/keep-awake /usr/share/gnome-shell /usr/share/gnome-shell/extensions /usr/share/gnome-shell/extensions/keepawake@fitz /usr/share/gnome-shell/extensions/keepawake@fitz/extension.js /usr/share/gnome-shell/extensions/keepawake@fitz/metadata.json /etc/sudoers.d /etc/sudoers.d/keep-awake; do
    [[ ! -L $dest ]] || fail "Refusing symlink: $dest"
done
visudo -c
umask 077
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
rule=/etc/sudoers.d/keep-awake
printf '%s\n' '# Managed by ubuntu-keep-awake/install.sh' \
    "$user ALL=(root) NOPASSWD: NOSETENV: /usr/local/bin/keep-awake on, /usr/local/bin/keep-awake off, /usr/local/bin/keep-awake status" > "$tmp/rule"
chmod 0440 "$tmp/rule"
visudo -cf "$tmp/rule"
[[ ! -e $rule ]] || cp -p -- "$rule" "$tmp/previous-rule"
install -d -o root -g root -m 0755 /usr/local/bin /usr/share/gnome-shell/extensions/keepawake@fitz /etc/sudoers.d
install -o root -g root -m 0755 "$src/bin/keep-awake" /usr/local/bin/keep-awake
install -o root -g root -m 0644 "$src/gnome-extension/keepawake@fitz/extension.js" "$src/gnome-extension/keepawake@fitz/metadata.json" /usr/share/gnome-shell/extensions/keepawake@fitz/
install -o root -g root -m 0440 "$tmp/rule" "$rule"
if ! visudo -c; then
    if [[ -f $tmp/previous-rule ]]; then cp -p -- "$tmp/previous-rule" "$rule"; else rm -f -- "$rule"; fi
    fail 'Sudoers validation failed; previous rule restored. Installed program files remain.'
fi
# Confirm passwordless status access as the selected user (read-only).
if ! sudo -u "$user" -- sudo -n /usr/local/bin/keep-awake status >/dev/null; then
    if [[ -f $tmp/previous-rule ]]; then cp -p -- "$tmp/previous-rule" "$rule"; else rm -f -- "$rule"; fi
    fail 'Rule is not effective; previous rule restored. Check /etc/sudoers includes /etc/sudoers.d.'
fi
printf 'Installed for %s. Log out and back in, then run as that user:\n  gnome-extensions enable keepawake@fitz\n' "$user"
