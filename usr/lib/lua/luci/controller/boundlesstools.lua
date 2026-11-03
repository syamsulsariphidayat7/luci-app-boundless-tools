module("luci.controller.boundlesstools", package.seeall)

-- luci-app-boundless-tools: kumpulan tools kecil di LuCI.
-- Controller melayani halaman Boundless Tools (Services) dan
-- endpoint Versi & Update di dalamnya:
--   GET  version    -> { installed } dari stempel VERSION di folder view
--   GET  check      -> bandingkan versi terpasang vs tag terbaru GitHub
--   POST update     -> jalankan online-install rilis terbaru (detached)
--   GET  updatelog  -> log + rc proses update untuk polling halaman
-- Logika tool-toolnya sendiri (v1: Convert V2Ray) berjalan 100% di
-- browser pada file view; link yang dikonversi tidak pernah sampai
-- ke controller ini.
function index()
	if not nixio.fs.access("/etc/config/boundlesstools") then
		return
	end
	entry({"admin", "services", "boundlesstools"},
		template("boundlesstools/dashboard"), "Boundless Tools", 92)
	entry({"admin", "services", "boundlesstools", "version"},
		call("action_version")).leaf = true
	entry({"admin", "services", "boundlesstools", "check"},
		call("action_check")).leaf = true
	entry({"admin", "services", "boundlesstools", "update"},
		post("action_update")).leaf = true
	entry({"admin", "services", "boundlesstools", "updatelog"},
		call("action_updatelog")).leaf = true
end

local REPO_SLUG     = "syamsulsariphidayat7/luci-app-boundless-tools"
local REPO_API      = "https://api.github.com/repos/" .. REPO_SLUG
local REPO_RAW      = "https://raw.githubusercontent.com/" .. REPO_SLUG
local VERSION_FILE  = "/usr/lib/lua/luci/view/boundlesstools/VERSION"
local UPDATE_LOG    = "/tmp/boundlesstools-update.log"
local UPDATE_RC     = "/tmp/boundlesstools-update.rc"
local UPDATE_PID    = "/tmp/boundlesstools-update.pid"
local UPDATE_SCRIPT = "/tmp/boundlesstools-online-install.sh"

local function write_json(tbl, status)
	if status then luci.http.status(status, status == 400 and "Bad Request" or "Error") end
	luci.http.prepare_content("application/json")
	luci.http.write(luci.jsonc.stringify(tbl))
end

-- Wajib POST + token CSRF yang sah.
local function require_post()
	local disp = luci.dispatcher
	if disp and disp.test_post_security then
		return disp.test_post_security()
	end
	if luci.http.getenv("REQUEST_METHOD") ~= "POST" then
		luci.http.status(405, "Method Not Allowed")
		return false
	end
	local tok  = luci.http.formvalue("token")
	local want = disp and disp.context and disp.context.authtoken
	if tok and want and tok == want then
		return true
	end
	luci.http.status(403, "Forbidden")
	return false
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local function read_tail(path, max)
	local f = io.open(path, "rb")
	if not f then return "" end
	local size = f:seek("end") or 0
	local off = size - max
	if off < 0 then off = 0 end
	f:seek("set", off)
	local data = f:read("*a") or ""
	f:close()
	return data
end

local function read_trim(path)
	local s = read_file(path)
	if not s then return nil end
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then return nil end
	return s
end

local function installed_version()
	local v = read_trim(VERSION_FILE)
	if not v then return "?" end
	return (v:gsub("^v", ""))
end

-- Ambil teks dari URL: curl bila ada, kalau tidak wget.
local function fetch_text(url)
	local out = luci.sys.exec(string.format(
		"if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 6 --max-time 20 %s; "
		.. "elif command -v wget >/dev/null 2>&1; then wget -qO- --timeout=20 %s; fi 2>/dev/null",
		luci.util.shellquote(url), luci.util.shellquote(url)))
	return out or ""
end

-- Tag rilis terbaru dari API GitHub (per_page=1, tanpa jq).
local function latest_tag()
	local out = fetch_text(REPO_API .. "/tags?per_page=1")
	if not out or out == "" then return nil end
	local tag = out:match('"name"%s*:%s*"([^"]+)"')
	if not tag or tag == "" then return nil end
	return tag
end

local function update_running()
	if read_trim(UPDATE_RC) then return false end
	local pid = read_trim(UPDATE_PID)
	if pid and pid:match("^%d+$") and nixio.fs.access("/proc/" .. pid) then
		return true
	end
	return false
end

-- GET /version
function action_version()
	write_json({ ok = true, installed = installed_version() })
end

-- GET /check
function action_check()
	local installed = installed_version()
	local tag = latest_tag()
	if not tag then
		return write_json({ ok = false,
			error = "Gagal menghubungi GitHub. Cek koneksi internet STB.",
			installed = installed }, 502)
	end
	local latest = tag:gsub("^v", "")
	write_json({
		ok = true,
		installed = installed,
		latest = tag,
		update_available = latest ~= installed,
	})
end

-- POST /update — unduh online-install.sh tag terbaru, jalankan
-- DETACHED (lepas dari uhttpd yang akan di-restart installer).
-- Wrapper menulis pid-nya sendiri dan rc di akhir, log ke /tmp.
function action_update()
	if not require_post() then return end
	if update_running() then
		return write_json({ ok = false, error = "Update sedang berjalan. Tunggu sampai selesai." }, 409)
	end
	local tag = latest_tag()
	if not tag then
		return write_json({ ok = false,
			error = "Gagal menghubungi GitHub. Cek koneksi internet STB." }, 502)
	end
	local script_url = REPO_RAW .. "/" .. tag .. "/online-install.sh"

	luci.sys.call(string.format("rm -f %s %s %s",
		luci.util.shellquote(UPDATE_LOG),
		luci.util.shellquote(UPDATE_RC),
		luci.util.shellquote(UPDATE_PID)))

	local body = string.format([[
echo "[boundless-tools] Mengunduh online-install.sh rilis %s ..."
if curl -fsSL --connect-timeout 10 --max-time 60 %s -o %s 2>/dev/null || wget -q --timeout=60 %s -O %s 2>/dev/null; then
    sh %s
else
    echo "[boundless-tools] Gagal mengunduh online-install.sh dari GitHub"
    false
fi]],
		tag,
		luci.util.shellquote(script_url),
		luci.util.shellquote(UPDATE_SCRIPT),
		luci.util.shellquote(script_url),
		luci.util.shellquote(UPDATE_SCRIPT),
		luci.util.shellquote(UPDATE_SCRIPT))

	local wrapper = string.format("echo $$ > %s\n%s\necho $? > %s\nrm -f %s",
		UPDATE_PID, body, UPDATE_RC, UPDATE_PID)

	local prefix = ""
	if luci.sys.call("command -v setsid >/dev/null 2>&1") == 0 then
		prefix = "setsid "
	elseif luci.sys.call("command -v nohup >/dev/null 2>&1") == 0 then
		prefix = "nohup "
	end
	luci.sys.call(string.format("%ssh -c %s </dev/null >%s 2>&1 &",
		prefix, luci.util.shellquote(wrapper),
		luci.util.shellquote(UPDATE_LOG)))

	write_json({ ok = true, started = true, latest = tag })
end

-- GET /updatelog — keadaan proses update untuk polling halaman.
function action_updatelog()
	local rc = read_trim(UPDATE_RC)
	local code
	if rc and rc:match("^%-?%d+$") then code = tonumber(rc) end
	write_json({
		ok = true,
		log = read_tail(UPDATE_LOG, 4000),
		rc = code,
		running = update_running(),
	})
end
