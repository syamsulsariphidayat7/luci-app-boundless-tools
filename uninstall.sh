#!/bin/sh
# luci-app-boundless-tools - uninstaller (dijalankan DI DALAM STB).
# Menghapus controller + view dan cache LuCI. Config
# /etc/config/boundlesstools dipertahankan, kecuali argumen: purge
if [ ! -f /etc/openwrt_release ]; then
	echo "STOP: script ini untuk DI DALAM STB (OpenWrt), bukan di PC/laptop." >&2
	exit 1
fi
set -e

echo "[boundless-tools] Menghapus file aplikasi..."
rm -f /usr/lib/lua/luci/controller/boundlesstools.lua
rm -rf /usr/lib/lua/luci/view/boundlesstools

if [ "$1" = "purge" ]; then
	echo "[boundless-tools] purge: config ikut dihapus."
	rm -f /etc/config/boundlesstools
	rm -rf /root/luci-app-boundless-tools
	rm -f /root/luci-app-boundless-tools-uninstall.sh
else
	echo "[boundless-tools] Config dipertahankan (argumen 'purge' untuk menghapusnya juga)."
fi

echo "[boundless-tools] Membersihkan cache LuCI..."
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /tmp/luci-modulecache.* 2>/dev/null || true
if [ -x /etc/init.d/uhttpd ]; then /etc/init.d/uhttpd restart; fi

echo "[boundless-tools] SELESAI. Menu Services -> Boundless Tools sudah hilang."
