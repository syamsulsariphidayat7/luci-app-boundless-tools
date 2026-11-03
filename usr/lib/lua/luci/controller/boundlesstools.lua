module("luci.controller.boundlesstools", package.seeall)

-- luci-app-boundless-tools: kumpulan tools kecil di LuCI.
-- Controller ini SENGAJA tipis: hanya mendaftarkan menu
-- Services -> Boundless Tools dan menyajikan halaman view.
-- Semua logika tool (v1: Convert V2Ray) berjalan 100% di browser
-- pada file view; tidak ada daemon, tidak ada endpoint data,
-- dan link yang dikonversi tidak pernah dikirim ke mana pun.
function index()
	if not nixio.fs.access("/etc/config/boundlesstools") then
		return
	end
	entry({"admin", "services", "boundlesstools"},
		template("boundlesstools/dashboard"), "Boundless Tools", 92)
end
