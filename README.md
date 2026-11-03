# luci-app-boundless-tools

**Boundless Tools** — aplikasi LuCI sederhana berisi kumpulan tools kecil.
Satu aplikasi, banyak tool; tool baru cukup ditambah sebagai kartu baru
di halaman yang sama, bukan aplikasi baru.

Menu: **Services → Boundless Tools**

## Tool v1: Convert V2Ray

Tempel link akun (satu link per baris), dapatkan daftar entri
`proxies:` Clash/Mihomo — hanya daftarnya saja, tanpa header `proxies:`.

Didukung:

| Protokol | Transport | TLS |
| --- | --- | --- |
| vmess | ws, grpc, httpupgrade, tcp, h2 | TLS / nonTLS |
| vless | ws, grpc, httpupgrade, tcp, h2, reality | TLS / nonTLS / reality |
| trojan | ws, grpc, httpupgrade, tcp | TLS / nonTLS |

Aturan hasil:

- Output mengikuti contoh: `udp: true` dan `skip-cert-verify: true` selalu ada.
- Tanpa TLS: baris `tls` dan `servername`/`sni` dihilangkan. TLS tanpa SNI:
  `servername`/`sni` diisi dari Host transport, terakhir dari server.
- `httpupgrade` ditulis sebagai `network: ws` + `ws-opts.v2ray-http-upgrade: true`
  (bentuk yang dipakai Mihomo).
- `trojan` mengikuti struktur Mihomo: memakai `sni`, tanpa field `tls`.
- Nama dari nama link; kosong → `Vmess-<server>-<port>` dsb; ganda → akhiran `-2`, `-3`.
- Urutan output = urutan input. Baris rusak ditandai nomor barisnya dan dilewati.
- Tombol: Convert, Salin, Download .yaml, Bersihkan.

Konversi berjalan **100% di browser**: link tidak dikirim ke server,
tidak disimpan di STB, dan controller LuCI tidak memprosesnya.

Contoh hasil:

```yaml
  - name: 🚀 Vmess-1
    type: vmess
    server: example.com
    port: 443
    uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    alterId: 0
    cipher: auto
    udp: true
    skip-cert-verify: true
    tls: true
    servername: example.com
    network: ws
    ws-opts:
      path: /path
      headers:
        Host: example.com
```

## Install di STB (dari GitHub, repo harus sudah di-push & Public)

```sh
curl -fsSL https://raw.githubusercontent.com/syamsulsariphidayat7/luci-app-boundless-tools/main/online-install.sh | sh
```

Kalau `curl` tidak ada:

```sh
wget -qO- https://raw.githubusercontent.com/syamsulsariphidayat7/luci-app-boundless-tools/main/online-install.sh | sh
```

Installer online mengunduh rilis terbaru (tag terakhir; fallback branch
`main`), memasangnya, dan menyimpan salinan di
`/root/luci-app-boundless-tools` untuk copot/rollback.
Paksa versi/branch tertentu: `VERSION=0.1.0 sh ...` / `BRANCH=main sh ...`
(setelah script diunduh sebagai file).

Install manual dari folder ini:

```sh
scp -r luci-app-boundless-tools root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'cd /tmp/luci-app-boundless-tools && sh install.sh'
```

## Copot dari STB

Online (STB bersih langsung dari repo):

```sh
curl -fsSL https://raw.githubusercontent.com/syamsulsariphidayat7/luci-app-boundless-tools/main/online-uninstall.sh | sh
```

Dari salinan lokal hasil install online:

```sh
sh /root/luci-app-boundless-tools-uninstall.sh
```

Config `/etc/config/boundlesstools` dipertahankan; hapus juga dengan
argumen `purge`: `sh /root/luci-app-boundless-tools-uninstall.sh purge`
atau `... online-uninstall.sh | sh -s -- purge`.

## Pengembangan

Uji logika converter (di PC, butuh node):

```sh
node tests/convert.test.js
```

Struktur:

```
etc/config/boundlesstools                  penanda terpasang
usr/lib/lua/luci/controller/boundlesstools.lua   menu saja (tipis)
usr/lib/lua/luci/view/boundlesstools/dashboard.htm   halaman + converter (JS)
install.sh / uninstall.sh                  pasang/copot lokal di STB
online-install.sh / online-uninstall.sh    pasang/copot via curl dari GitHub
VERSION                                    versi aplikasi
```

Versi: lihat file `VERSION`.
