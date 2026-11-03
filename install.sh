#!/bin/sh
# luci-app-boundless-tools - installer lokal (dijalankan DI DALAM STB).
# Menyalin controller + view + config, membersihkan cache LuCI,
# lalu me-restart uhttpd. Config yang sudah ada tidak ditimpa.
if [ ! -f /etc/openwrt_release ]; then
	echo "STOP: script ini untuk DI DALAM STB (OpenWrt), bukan di PC/laptop." >&2
	exit 1
fi
set -e

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CTL="usr/lib/lua/luci/controller/boundlesstools.lua"
VIEW="usr/lib/lua/luci/view/boundlesstools/dashboard.htm"
CFG="etc/config/boundlesstools"

for f in "$CTL" "$VIEW" "$CFG" "VERSION"; do
	if [ ! -f "$DIR/$f" ]; then
		echo "[boundless-tools] ERROR: file $f tidak ada di $DIR" >&2
		exit 1
	fi
done

echo "[boundless-tools] Menyalin file..."
mkdir -p /usr/lib/lua/luci/controller /usr/lib/lua/luci/view/boundlesstools /etc/config
cp -f "$DIR/$CTL" "/$CTL"
cp -f "$DIR/$VIEW" "/$VIEW"
cp -f "$DIR/VERSION" /usr/lib/lua/luci/view/boundlesstools/VERSION
if [ -f /etc/config/boundlesstools ]; then
	echo "[boundless-tools] Config lama dipertahankan."
else
	cp -f "$DIR/$CFG" /etc/config/boundlesstools
fi
chmod 644 "/$CTL" "/$VIEW" /usr/lib/lua/luci/view/boundlesstools/VERSION /etc/config/boundlesstools

echo "[boundless-tools] Membersihkan cache LuCI..."
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /tmp/luci-modulecache.* 2>/dev/null || true
if [ -x /etc/init.d/uhttpd ]; then /etc/init.d/uhttpd restart; fi

grep -q "luci.controller.boundlesstools" "/$CTL" && echo "[boundless-tools] controller OK"
[ -f "/$VIEW" ] && echo "[boundless-tools] view OK (versi $(cat /usr/lib/lua/luci/view/boundlesstools/VERSION))"
echo "[boundless-tools] SELESAI. Buka LuCI -> Services -> Boundless Tools (hard refresh: Ctrl+F5)."
