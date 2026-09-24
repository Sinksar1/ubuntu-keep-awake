#!/bin/bash
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
if [[ $# == 1 && $1 == --help ]]; then echo 'Usage: sudo ./uninstall.sh'; exit 0; fi
[[ $# == 0 && $EUID == 0 ]] || { echo 'Usage: sudo ./uninstall.sh' >&2; exit 1; }
rule=/etc/sudoers.d/keep-awake
extension=/usr/share/gnome-shell/extensions/keepawake@fitz
for dest in /etc/sudoers.d "$rule" /usr/local/bin /usr/local/bin/keep-awake /usr/share/gnome-shell /usr/share/gnome-shell/extensions "$extension"; do
    [[ ! -L $dest ]] || { echo "Refusing symlink: $dest" >&2; exit 1; }
done
# Stop explicitly before uninstalling: do not kill a potentially reused PID here.
if [[ -e /run/keep-awake.pid ]]; then
    echo 'Keep Awake has a PID file. Verify the inhibitor and run sudo keep-awake off before uninstalling.' >&2
    exit 1
fi
visudo -c
umask 077
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
[[ ! -e $rule ]] || cp -p -- "$rule" "$tmp/rule"
rm -f -- "$rule"
if ! visudo -c; then
    [[ ! -f $tmp/rule ]] || cp -p -- "$tmp/rule" "$rule"
    echo 'Sudoers validation failed; previous rule restored.' >&2
    exit 1
fi
rm -f -- /usr/local/bin/keep-awake "$extension/extension.js" "$extension/metadata.json"
if [[ -d $extension ]]; then rmdir -- "$extension" || echo "Other files remain in $extension; retained." >&2; fi
echo 'Removed Keep Awake and its sudoers rule. Log out and back in to refresh GNOME Shell.'
