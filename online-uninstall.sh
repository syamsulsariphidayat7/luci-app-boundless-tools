#!/bin/sh
# luci-app-boundless-tools - pencopot ONLINE (dijalankan DI DALAM STB).
# Memakai salinan lokal uninstaller bila ada; kalau tidak, mengunduh
# uninstall.sh dari branch main repo. Argumen diteruskan, jadi
# purge ikut bekerja:  ... | sh -s -- purge
set -e

if [ ! -f /etc/openwrt_release ]; then
	echo "STOP: script ini untuk DI DALAM STB (OpenWrt), bukan di PC/laptop." >&2
	exit 1
fi

if [ -f /root/luci-app-boundless-tools-uninstall.sh ]; then
	echo "[boundless-tools] Memakai uninstaller lokal."
	exec sh /root/luci-app-boundless-tools-uninstall.sh "$@"
fi

REPO="syamsulsariphidayat7/luci-app-boundless-tools"
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT INT TERM

echo "[boundless-tools] Download uninstaller dari branch main..."
if command -v curl >/dev/null 2>&1; then
	curl -fsSL "https://raw.githubusercontent.com/$REPO/main/uninstall.sh" -o "$TMPD/uninstall.sh"
elif command -v wget >/dev/null 2>&1; then
	wget -q -O "$TMPD/uninstall.sh" "https://raw.githubusercontent.com/$REPO/main/uninstall.sh"
else
	echo "[boundless-tools] ERROR: curl dan wget tidak ditemukan." >&2
	exit 1
fi

exec sh "$TMPD/uninstall.sh" "$@"
