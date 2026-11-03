// Uji logika converter Boundless Tools dengan node:
//   node tests/convert.test.js
// Fungsi converter diekstrak apa adanya dari view dashboard.htm
// (di antara penanda CONVERTER START/END), lalu diuji dengan stub atob.
"use strict";
const fs = require("fs");
const path = require("path");

const htm = fs.readFileSync(
  path.join(__dirname, "..", "usr/lib/lua/luci/view/boundlesstools/dashboard.htm"),
  "utf8"
);
const start = htm.indexOf("// === CONVERTER START ===");
const end = htm.indexOf("// === CONVERTER END ===");
if (start < 0 || end < 0) throw new Error("penanda converter tidak ditemukan");
const src = htm.slice(start, end);
global.atob = (s) => Buffer.from(s, "base64").toString("binary");
eval(src + "\n;global.btConvertAll = btConvertAll;");

let pass = 0, fail = 0;
function check(name, cond, extra) {
  if (cond) { pass++; console.log("OK   " + name); }
  else { fail++; console.log("FAIL " + name + (extra ? "\n" + extra : "")); }
}
function b64json(o) { return Buffer.from(JSON.stringify(o), "utf8").toString("base64"); }

const UUID = "11112035-7dd8-48e1-876e-1cdb42657356";

// 1. vmess ws TLS — persis bentuk contoh Syamsul
let r = btConvertAll("vmess://" + b64json({
  v: "2", ps: "🚀 Vmess-1", add: "example.com", port: "443", id: UUID,
  aid: "0", scy: "auto", net: "ws", type: "none", host: "example.com",
  path: "/path", tls: "tls", sni: "example.com"
}));
check("vmess ws TLS ok=1", r.ok === 1 && r.errors.length === 0, JSON.stringify(r));
check("vmess ws TLS bentuk contoh",
  r.yaml.includes("- name: 🚀 Vmess-1") &&
  r.yaml.includes("uuid: " + UUID) &&
  r.yaml.includes("alterId: 0") && r.yaml.includes("cipher: auto") &&
  r.yaml.includes("tls: true") && r.yaml.includes("servername: example.com") &&
  r.yaml.includes("network: ws") && r.yaml.includes("path: /path") &&
  r.yaml.includes("Host: example.com"), r.yaml);
check("tanpa header proxies:", !/^proxies:/m.test(r.yaml), r.yaml);

// 2. vmess nonTLS tcp — tanpa baris tls/servername
r = btConvertAll("vmess://" + b64json({
  ps: "", add: "1.2.3.4", port: 80, id: UUID, aid: 0, net: "tcp", tls: ""
}));
check("vmess nonTLS tanpa tls/servername",
  r.ok === 1 && !r.yaml.includes("tls:") && !r.yaml.includes("servername:"), r.yaml);
check("vmess nama fallback", r.yaml.includes("- name: Vmess-1.2.3.4-80"), r.yaml);

// 3. vless ws TLS + sni
r = btConvertAll("vless://" + UUID + "@example.com:443?security=tls&type=ws&host=example.com&path=%2Fpath&sni=example.com#Vless-WS");
check("vless ws TLS",
  r.ok === 1 && r.yaml.includes("type: vless") && r.yaml.includes("tls: true") &&
  r.yaml.includes("servername: example.com") && r.yaml.includes("path: /path"), r.yaml);

// 4. vless grpc TLS
r = btConvertAll("vless://" + UUID + "@example.com:443?security=tls&type=grpc&serviceName=myservice&sni=example.com#Vless-GRPC");
check("vless grpc",
  r.ok === 1 && r.yaml.includes("network: grpc") &&
  r.yaml.includes("grpc-service-name: myservice"), r.yaml);

// 5. vless reality
r = btConvertAll("vless://" + UUID + "@example.com:443?security=reality&type=tcp&sni=www.example.com&fp=chrome&pbk=PUBKEY123&sid=ab12#Vless-Reality");
check("vless reality",
  r.ok === 1 && r.yaml.includes("reality-opts:") &&
  r.yaml.includes("public-key: PUBKEY123") && r.yaml.includes("short-id: ab12") &&
  r.yaml.includes("client-fingerprint: chrome"), r.yaml);

// 6. trojan ws TLS
r = btConvertAll("trojan://password123@example.com:443?security=tls&type=ws&host=example.com&path=%2Ftrojan&sni=example.com#Trojan-WS-TLS");
check("trojan ws TLS",
  r.ok === 1 && r.yaml.includes("password: password123") &&
  r.yaml.includes("sni: example.com") && r.yaml.includes("network: ws") &&
  !r.yaml.includes("tls:"), r.yaml);

// 7. trojan ws nonTLS — sni hilang
r = btConvertAll("trojan://password123@example.com:80?security=none&type=ws&host=example.com&path=%2Ftrojan#Trojan-WS-nonTLS");
check("trojan ws nonTLS tanpa sni",
  r.ok === 1 && !r.yaml.includes("sni:") && r.yaml.includes("network: ws"), r.yaml);

// 8. trojan grpc TLS
r = btConvertAll("trojan://password123@example.com:443?security=tls&type=grpc&serviceName=gunservice&sni=example.com#Trojan-GRPC");
check("trojan grpc TLS",
  r.ok === 1 && r.yaml.includes("network: grpc") &&
  r.yaml.includes("grpc-service-name: gunservice"), r.yaml);

// 9. trojan httpupgrade TLS & nonTLS -> ws + v2ray-http-upgrade
r = btConvertAll("trojan://password123@example.com:443?security=tls&type=httpupgrade&host=example.com&path=%2Fup&sni=example.com#Trojan-HU-TLS");
check("trojan httpupgrade TLS",
  r.ok === 1 && r.yaml.includes("network: ws") &&
  r.yaml.includes("v2ray-http-upgrade: true") && r.yaml.includes("sni: example.com"), r.yaml);
r = btConvertAll("trojan://password123@example.com:80?security=none&type=httpupgrade&host=example.com&path=%2Fup#Trojan-HU-nTLS");
check("trojan httpupgrade nonTLS",
  r.ok === 1 && r.yaml.includes("v2ray-http-upgrade: true") && !r.yaml.includes("sni:"), r.yaml);

// 10. nama ganda -> -2
r = btConvertAll([
  "trojan://p1@example.com:443?security=tls&type=ws#Sama",
  "trojan://p2@example.com:443?security=tls&type=ws#Sama"
].join("\n"));
check("nama ganda diberi -2", r.ok === 2 && r.yaml.includes("- name: Sama\n") && r.yaml.includes("- name: Sama-2"), r.yaml);

// 11. baris rusak dilewati, baris lain tetap jalan + nomor baris benar
r = btConvertAll([
  "trojan://p1@example.com:443?security=tls#Bagus",
  "ini-bukan-link",
  "vless://" + UUID + "@example.com:443?security=none&type=tcp#Bagus2"
].join("\n"));
check("baris rusak dilewati",
  r.ok === 2 && r.errors.length === 1 && r.errors[0].line === 2, JSON.stringify(r));

// 12. vmess grpc (serviceName dari path)
r = btConvertAll("vmess://" + b64json({
  ps: "VM-GRPC", add: "example.com", port: "443", id: UUID, aid: "0",
  net: "grpc", host: "", path: "myservice", tls: "tls", sni: "example.com"
}));
check("vmess grpc", r.ok === 1 && r.yaml.includes("grpc-service-name: myservice"), r.yaml);

console.log("\n" + pass + " lulus, " + fail + " gagal");
process.exit(fail ? 1 : 0);
