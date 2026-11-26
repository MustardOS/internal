-- Jukebox HTTP server and music manager

local jukebox_web_server = {}

local socket = nil
local ok_sock, sock_lib = pcall(require, "socket")
if ok_sock and sock_lib then
    socket = sock_lib
end

local qrencode = nil
local ok_qr, qr_lib = pcall(require, "scripts.qrencode")
if not ok_qr then
    ok_qr, qr_lib = pcall(function() return dofile("scripts/qrencode.lua") end)
end
if ok_qr and qr_lib then
    qrencode = qr_lib
end

local server = nil
local server_ip = "127.0.0.1"
local server_port = 8048
local qr_cached_url = nil
local qr_cached_image = nil

local BUILTIN_TRACKS = {
    ["all night - roa .mp3"] = true,
    ["beloved - roa.mp3"] = true,
    ["carefree - luke bergs.mp3"] = true,
    ["chillout - audiocoffee.mp3"] = true,
    ["crescent moon - purrple cat.mp3"] = true,
    ["day off - tokyo music walker .mp3"] = true,
    ["downtown glow - ghostrifter official.mp3"] = true,
    ["embrace - roa.mp3"] = true,
    ["golden hour - purrple cat.mp3"] = true,
    ["green tea - purrple cat.mp3"] = true,
    ["heart of the ocean - purrple cat.mp3"] = true,
    ["hope - ghostrifter official.mp3"] = true,
    ["journey - roa.mp3"] = true,
    ["kokua - luke bergs.mp3"] = true,
    ["late at night - sakura girl.mp3"] = true,
    ["lights - sakura girl.mp3"] = true,
    ["missing you - purrple cat.mp3"] = true,
    ["pearl - kirara magic.mp3"] = true,
    ["purple dream - ghostrifter official.mp3"] = true,
    ["summer madness - roa.mp3"] = true,
    ["sunset drive - tokyo music walker.mp3"] = true,
    ["when i was a boy - tokyo music walker.mp3"] = true,
    ["winter magic - roa.mp3"] = true,
}

local function sanitize_filename(fn)
    if not fn then return "track.mp3" end
    fn = fn:match("([^/\\]+)$") or fn
    fn = fn:gsub('[<>:"/\\|?*]', "")
    fn = fn:gsub("^%s+", ""):gsub("%s+$", "")
    if fn == "" then fn = "custom_track.mp3" end
    return fn
end

local function url_decode(str)
    if not str then return "" end
    str = str:gsub("+", " ")
    return (str:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

local function json_escape_str(str)
    local s = tostring(str or "")
    s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\b', '\\b'):gsub('\f', '\\f'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
    s = s:gsub("[%z\1-\31]", function(c)
        return string.format("\\u%04x", string.byte(c))
    end)
    return '"' .. s .. '"'
end

local function json_encode(val)
    local t = type(val)
    if t == "table" then
        local count = 0
        for _ in pairs(val) do count = count + 1 end
        local is_array = (count == #val and count > 0) or (count == 0)

        if is_array then
            local parts = {}
            for i = 1, #val do
                table.insert(parts, json_encode(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, json_escape_str(k) .. ":" .. json_encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    elseif t == "string" then
        return json_escape_str(val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    else
        return "null"
    end
end

local function json_decode_simple(str)
    local obj = {}
    if not str or str == "" then return obj end
    local i = 1
    local len = #str

    local function skip_ws()
        local _, e = str:find("^[ \t\r\n]+", i)
        if e then i = e + 1 end
    end

    local function parse_str()
        if str:sub(i, i) ~= '"' then return nil end
        i = i + 1
        local out = {}
        while i <= len do
            local ch = str:sub(i, i)
            if ch == '"' then
                i = i + 1
                return table.concat(out)
            elseif ch == "\\" then
                local nxt = str:sub(i + 1, i + 1)
                if nxt == '"' or nxt == "\\" or nxt == "/" then
                    table.insert(out, nxt); i = i + 2
                elseif nxt == "n" then
                    table.insert(out, "\n"); i = i + 2
                elseif nxt == "r" then
                    table.insert(out, "\r"); i = i + 2
                elseif nxt == "t" then
                    table.insert(out, "\t"); i = i + 2
                elseif nxt == "b" then
                    table.insert(out, "\b"); i = i + 2
                elseif nxt == "f" then
                    table.insert(out, "\f"); i = i + 2
                elseif nxt == "u" then
                    local hex = str:sub(i + 2, i + 5)
                    local code = tonumber(hex, 16)
                    if code and code < 128 then
                        table.insert(out, string.char(code))
                    end
                    i = i + 6
                else
                    table.insert(out, nxt); i = i + 2
                end
            else
                table.insert(out, ch)
                i = i + 1
            end
        end
        return table.concat(out)
    end

    skip_ws()
    if str:sub(i, i) ~= "{" then return obj end
    i = i + 1
    while i <= len do
        skip_ws()
        if str:sub(i, i) == "}" then break end
        if str:sub(i, i) == "," then i = i + 1; skip_ws() end
        local key = parse_str()
        if not key then break end
        skip_ws()
        if str:sub(i, i) ~= ":" then break end
        i = i + 1
        skip_ws()
        local ch = str:sub(i, i)
        if ch == '"' then
            obj[key] = parse_str()
        elseif str:sub(i, i + 3) == "true" then
            obj[key] = true; i = i + 4
        elseif str:sub(i, i + 4) == "false" then
            obj[key] = false; i = i + 5
        elseif str:sub(i, i + 3) == "null" then
            obj[key] = nil; i = i + 4
        else
            local num_s = str:match("^%-?%d+%.?%d*", i)
            if num_s then
                obj[key] = tonumber(num_s)
                i = i + #num_s
            else
                break
            end
        end
    end
    return obj
end

-- Generate QR image from URL
function jukebox_web_server.getQrImage(url)
    if not url or url == "" then return nil end
    if qr_cached_image and qr_cached_url == url then
        return qr_cached_image
    end

    if not qrencode then
        local ok, lib = pcall(require, "scripts.qrencode")
        if not ok then ok, lib = pcall(function() return dofile("scripts/qrencode.lua") end) end
        if ok and lib then qrencode = lib end
    end

    if not qrencode or not qrencode.qrcode then
        return nil
    end

    local ok, success, matrix = pcall(qrencode.qrcode, url)
    if not ok or not success or type(matrix) ~= "table" or #matrix == 0 then
        return nil
    end

    local size = #matrix
    local scale = 6
    local border = 4
    local dim = (size + border * 2) * scale

    local ok_img, imgData = pcall(love.image.newImageData, dim, dim)
    if not ok_img or not imgData then return nil end

    imgData:mapPixel(function() return 1, 1, 1, 1 end)

    for r = 1, size do
        for c = 1, size do
            if matrix[r][c] > 0 then
                local px = (c - 1 + border) * scale
                local py = (r - 1 + border) * scale
                for y = 0, scale - 1 do
                    for x = 0, scale - 1 do
                        imgData:setPixel(px + x, py + y, 0, 0, 0, 1)
                    end
                end
            end
        end
    end

    local ok_tex, tex = pcall(love.graphics.newImage, imgData)
    if ok_tex and tex then
        qr_cached_url = url
        qr_cached_image = tex
        return tex
    end
    return nil
end

function jukebox_web_server.is_running()
    return server ~= nil
end

function jukebox_web_server.start(ip, port)
    port = tonumber(port) or 8048
    if server then
        if server_port == port then
            if ip and ip ~= "" then
                server_ip = ip
            end
            return true, server_ip, server_port
        end
        jukebox_web_server.stop()
    end

    if not socket then
        local ok, s = pcall(require, "socket")
        if ok and s then socket = s else return false, "LuaSocket not available" end
    end

    port = tonumber(port) or 8048
    local s = socket.bind("*", port)
    if not s then
        s = socket.bind("*", 0) -- fallback to any available port
    end

    if not s then
        return false, "Failed to bind socket"
    end

    s:settimeout(0)
    server = s
    local _, bound_port = s:getsockname()
    server_port = tonumber(bound_port or port) or 8048
    server_ip = ip or "127.0.0.1"

    return true, server_ip, server_port
end

function jukebox_web_server.stop()
    if server then
        pcall(function() server:close() end)
        server = nil
    end
    qr_cached_url = nil
    qr_cached_image = nil
end

local disk_ffi_init = false
local disk_ffi = nil

local function query_disk_space_ffi(save_dir)
    local ok_ffi, ffi_mod = pcall(require, "ffi")
    if not ok_ffi or not ffi_mod then return nil end
    if not disk_ffi_init then
        disk_ffi_init = true
        pcall(function()
            if ffi_mod.os == "Windows" then
                ffi_mod.cdef[[
                    int GetDiskFreeSpaceExA(const char* lpDirectoryName, unsigned long long* lpFreeBytesAvailable, unsigned long long* lpTotalNumberOfBytes, unsigned long long* lpTotalNumberOfFreeBytes);
                ]]
            else
                ffi_mod.cdef[[
                    struct statvfs {
                        unsigned long f_bsize;
                        unsigned long f_frsize;
                        unsigned long f_blocks;
                        unsigned long f_bfree;
                        unsigned long f_bavail;
                        unsigned long f_files;
                        unsigned long f_ffree;
                        unsigned long f_favail;
                        unsigned long f_fsid;
                        unsigned long f_flag;
                        unsigned long f_namemax;
                        unsigned int __f_spare[6];
                    };
                    int statvfs(const char *path, struct statvfs *buf);
                ]]
            end
            disk_ffi = ffi_mod
        end)
    end
    if not disk_ffi then return nil end
    local info = { total_mb = 0, free_mb = 0 }
    pcall(function()
        if disk_ffi.os == "Windows" then
            local free_avail = disk_ffi.new("unsigned long long[1]")
            local total_bytes = disk_ffi.new("unsigned long long[1]")
            local total_free = disk_ffi.new("unsigned long long[1]")
            if disk_ffi.C.GetDiskFreeSpaceExA(save_dir, free_avail, total_bytes, total_free) ~= 0 then
                info.total_mb = math.floor(tonumber(total_bytes[0]) / 1048576)
                info.free_mb = math.floor(tonumber(free_avail[0]) / 1048576)
            end
        else
            local buf = disk_ffi.new("struct statvfs")
            local res = disk_ffi.C.statvfs(save_dir, buf)
            if res ~= 0 then
                res = disk_ffi.C.statvfs(".", buf)
            end
            if res == 0 then
                local fr = tonumber(buf.f_frsize > 0 and buf.f_frsize or buf.f_bsize)
                info.free_mb = math.floor(tonumber(buf.f_bavail) * fr / 1048576)
                info.total_mb = math.floor(tonumber(buf.f_blocks) * fr / 1048576)
            end
        end
    end)
    return info
end

local function read_exact_bytes(client, count)
    if count <= 0 then return "" end
    local chunks = {}
    local received = 0
    while received < count do
        local chunk_size = math.min(count - received, 65536)
        local data, err, partial = client:receive(chunk_size)
        if data and #data > 0 then
            table.insert(chunks, data)
            received = received + #data
        elseif partial and #partial > 0 then
            table.insert(chunks, partial)
            received = received + #partial
        else
            return nil, err or "incomplete body"
        end
    end
    return table.concat(chunks)
end

local function send_all(client, data)
    local total = #data
    local sent = 0
    while sent < total do
        local end_pos = math.min(total, sent + 65536)
        local ok_i, err, partial_i = client:send(data, sent + 1, end_pos)
        local next_pos = ok_i or partial_i
        if not next_pos or next_pos <= sent then
            return false, err
        end
        sent = next_pos
    end
    return true
end

local function send_response(client, status_code, content_type, body, extra_headers, skip_body)
    local status_text = "OK"
    if status_code == 206 then status_text = "Partial Content"
    elseif status_code == 400 then status_text = "Bad Request"
    elseif status_code == 403 then status_text = "Forbidden"
    elseif status_code == 404 then status_text = "Not Found"
    elseif status_code == 416 then status_text = "Range Not Satisfiable"
    elseif status_code == 500 then status_text = "Internal Server Error"
    end

    local headers = {
        string.format("HTTP/1.1 %d %s", status_code, status_text),
        "Access-Control-Allow-Origin: *",
        "Access-Control-Allow-Methods: GET, HEAD, POST, OPTIONS",
        "Access-Control-Allow-Headers: Content-Type, Range",
        string.format("Content-Type: %s", content_type or "text/plain"),
        string.format("Content-Length: %d", body and #body or 0),
        "Connection: close"
    }

    if extra_headers then
        for _, h in ipairs(extra_headers) do
            table.insert(headers, h)
        end
    end

    table.insert(headers, "\r\n")
    pcall(function()
        if not send_all(client, table.concat(headers, "\r\n")) then
            return
        end
        if not skip_body and body and #body > 0 then
            send_all(client, body)
        end
    end)
end

local function handle_client(client, sound_module)
    client:settimeout(0.5)

    -- Read request line
    local req_line, err = client:receive("*l")
    if not req_line then
        client:close()
        return
    end

    local method, raw_path = req_line:match("^(%u+)%s+(%S+)")
    if not method or not raw_path then
        client:close()
        return
    end

    local path = raw_path:match("^([^?]+)") or raw_path
    path = url_decode(path)

    -- Read headers
    local headers = {}
    while true do
        local line, err2 = client:receive("*l")
        if not line or line == "" or line == "\r" then break end
        local k, v = line:match("^([^:]+):%s*(.*)$")
        if k and v then
            headers[k:lower()] = v:gsub("\r$", "")
        end
    end

    if method == "OPTIONS" then
        send_response(client, 200, "text/plain", "")
        client:close()
        return
    end

    -- 1. Dashboard: GET / or /index.html
    if path == "/" or path == "/index.html" then
        local html = nil
        if love and love.filesystem then
            local ok, data = pcall(love.filesystem.read, "scripts/jukebox_web.html")
            if ok and data then html = data end
        end
        if not html then
            local f = io.open("scripts/jukebox_web.html", "r")
            if f then html = f:read("*a"); f:close() end
        end

        if html then
            local t_theme = _G.theme or "light"
            local payload = (renderer and renderer.getWebThemePayload) and renderer.getWebThemePayload(t_theme) or {
                theme = t_theme,
                name = (renderer and renderer.getThemeDisplayName) and renderer.getThemeDisplayName(t_theme, false) or t_theme,
            }
            payload.timestamp = os.time()
            local t_name = payload.name or t_theme
            local payload_json = json_encode(payload)
            html = html:gsub("__DEVICE_IP__", function() return string.format("%s:%d", server_ip, server_port) end)
            html = html:gsub("__INITIAL_THEME__", function() return t_theme end)
            html = html:gsub("__INITIAL_THEME_NAME__", function() return t_name end)
            html = html:gsub("__INITIAL_THEME_DATA__", function() return payload_json end)
            send_response(client, 200, "text/html; charset=utf-8", html)
        else
            send_response(client, 404, "text/plain", "Jukebox dashboard HTML not found")
        end
        client:close()
        return
    end

    -- 2. Theme info: GET /api/theme
    if path == "/api/theme" then
        local t_theme = _G.theme or "light"
        local payload = (renderer and renderer.getWebThemePayload) and renderer.getWebThemePayload(t_theme) or {
            theme = t_theme,
            name = (renderer and renderer.getThemeDisplayName) and renderer.getThemeDisplayName(t_theme, false) or t_theme,
        }
        payload.timestamp = os.time()
        local json = json_encode(payload)
        send_response(client, 200, "application/json; charset=utf-8", json)
        client:close()
        return
    end

    -- 3. Status info: GET /api/status
    if path == "/api/status" then
        local playlist = sound_module and sound_module.getPlaylist and sound_module.getPlaylist() or {}
        local save_dir = (love and love.filesystem and love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory()) or "."
        local storage_info = query_disk_space_ffi(save_dir) or { total_mb = 0, free_mb = 0 }
        if storage_info.free_mb <= 0 then
            pcall(function()
                local h = io.popen and (io.popen("df -m '" .. save_dir .. "' 2>/dev/null") or io.popen("df -m . 2>/dev/null"))
                if h then
                    local res = h:read("*a")
                    h:close()
                    if res then
                        local lines = {}
                        for l in res:gmatch("[^\r\n]+") do table.insert(lines, l) end
                        if #lines >= 2 then
                            local t, u, f = lines[2]:match("%S+%s+(%d+)%s+(%d+)%s+(%d+)")
                            if f then
                                storage_info.total_mb = tonumber(t) or 0
                                storage_info.free_mb = tonumber(f) or 0
                            end
                        end
                    end
                end
            end)
        end
        local json = json_encode({
            success = true,
            status = "online",
            device_ip = server_ip,
            port = server_port,
            tracks_count = #playlist,
            storage = storage_info
        })
        send_response(client, 200, "application/json; charset=utf-8", json)
        client:close()
        return
    end

    -- 4. Tracks listing: GET /api/tracks
    if path == "/api/tracks" then
        local tracks = {}
        if sound_module and sound_module.getPlaylist then
            local pl = sound_module.getPlaylist()
            for _, t in ipairs(pl) do
                local lower = t.filename:lower()
                local is_builtin = BUILTIN_TRACKS[lower] or false
                local is_custom = not is_builtin
                local size = 0
                if love and love.filesystem then
                    local info = love.filesystem.getInfo(t.path)
                    if info and info.size then size = info.size end
                end
                if size == 0 and io and io.open then
                    local f = io.open(t.path, "rb")
                    if not f then f = io.open("assets/music/" .. t.filename, "rb") end
                    if f then
                        size = f:seek("end") or 0
                        f:close()
                    end
                end
                local size_formatted = ""
                if size and size > 0 then
                    if size >= 1048576 then
                        size_formatted = string.format("%.1f MB", size / 1048576)
                    elseif size >= 1024 then
                        size_formatted = string.format("%.0f KB", size / 1024)
                    else
                        size_formatted = string.format("%d B", size)
                    end
                end
                table.insert(tracks, {
                    filename = t.filename,
                    title = t.title or t.filename,
                    artist = t.artist or "Unknown",
                    is_builtin = is_builtin,
                    is_custom = is_custom,
                    size = size,
                    size_formatted = size_formatted
                })
            end
        end
        local json = json_encode({
            success = true,
            tracks = tracks
        })
        send_response(client, 200, "application/json; charset=utf-8", json)
        client:close()
        return
    end

    -- Audio stream and download endpoints
    local stream_fn = path:match("^/api/stream/(.+)$") or path:match("^/api/download/(.+)$")
    if stream_fn then
        local is_dl = path:find("^/api/download/") ~= nil
        local safe_name = sanitize_filename(stream_fn)
        local file_data = nil

        if love and love.filesystem then
            local ok, d = pcall(love.filesystem.read, "assets/music/" .. safe_name)
            if ok and d then file_data = d end
            if not file_data then
                local ok2, d2 = pcall(love.filesystem.read, safe_name)
                if ok2 and d2 then file_data = d2 end
            end
        end

        if not file_data then
            local candidates = {
                "assets/music/" .. safe_name,
                "gamedata/assets/music/" .. safe_name,
                safe_name
            }
            for _, c in ipairs(candidates) do
                local f = io.open(c, "rb")
                if f then
                    file_data = f:read("*a")
                    f:close()
                    break
                end
            end
        end

        if not file_data then
            send_response(client, 404, "text/plain", "Audio file not found")
            client:close()
            return
        end

        local total_size = #file_data
        local ext = safe_name:match("%.([^.]+)$")
        ext = ext and ext:lower() or "mp3"
        local mime = "audio/mpeg"
        if ext == "ogg" then mime = "audio/ogg"
        elseif ext == "wav" then mime = "audio/wav" end

        local range_hdr = headers["range"]
        local extra = {"Accept-Ranges: bytes"}
        if is_dl then
            table.insert(extra, string.format('Content-Disposition: attachment; filename="%s"', safe_name))
        end

        local is_head = (method == "HEAD")
        if range_hdr and not is_dl then
            if total_size == 0 then
                send_response(client, 416, "text/plain", "", {"Content-Range: bytes */0"}, is_head)
                client:close()
                return
            end
            local start_b, end_b
            local suffix_len = range_hdr:match("bytes=%-(%d+)")
            if suffix_len then
                local n = tonumber(suffix_len) or 0
                if n <= 0 then
                    send_response(client, 416, "text/plain", "", {string.format("Content-Range: bytes */%d", total_size)}, is_head)
                    client:close()
                    return
                end
                start_b = math.max(0, total_size - n)
                end_b = total_size - 1
            else
                local s_start, s_end = range_hdr:match("bytes=(%d+)%-(%d*)")
                start_b = tonumber(s_start)
                end_b = tonumber(s_end) or (total_size - 1)
            end
            if not start_b or start_b >= total_size or end_b < start_b then
                send_response(client, 416, "text/plain", "", {string.format("Content-Range: bytes */%d", total_size)}, is_head)
                client:close()
                return
            end
            if end_b >= total_size then end_b = total_size - 1 end
            local slice = file_data:sub(start_b + 1, end_b + 1)
            table.insert(extra, string.format("Content-Range: bytes %d-%d/%d", start_b, end_b, total_size))
            send_response(client, 206, mime, slice, extra, is_head)
        else
            send_response(client, 200, mime, file_data, extra, is_head)
        end
        client:close()
        return
    end

    -- 6. Font: GET /font/ClearSans-Bold.ttf or /assets/font/ClearSans-Bold.ttf
    if path == "/font/ClearSans-Bold.ttf" or path == "/assets/font/ClearSans-Bold.ttf" then
        local font_data = nil
        if love and love.filesystem then
            local ok, d = pcall(love.filesystem.read, "assets/font/ClearSans-Bold.ttf")
            if ok and d then font_data = d end
        end
        if not font_data then
            local f = io.open("assets/font/ClearSans-Bold.ttf", "rb")
            if f then font_data = f:read("*a"); f:close() end
        end
        if font_data then
            send_response(client, 200, "font/ttf", font_data, {"Cache-Control: public, max-age=31536000, immutable"})
        else
            send_response(client, 404, "text/plain", "Font not found")
        end
        client:close()
        return
    end

    -- 7. Logo & Favicon: /assets/logo/logo_2048.png, /logo.png, /favicon.ico, /favicon.png
    if path == "/assets/logo/logo_2048.png" or path == "/logo.png" or path == "/favicon.ico" or path == "/favicon.png" then
        local logo_data = nil
        if love and love.filesystem then
            local ok, d = pcall(love.filesystem.read, "assets/logo/logo_2048.png")
            if ok and d then logo_data = d end
        end
        if not logo_data then
            local f = io.open("assets/logo/logo_2048.png", "rb")
            if f then logo_data = f:read("*a"); f:close() end
        end
        if logo_data then
            send_response(client, 200, "image/png", logo_data, {"Cache-Control: public, max-age=86400"})
        else
            send_response(client, 404, "text/plain", "Logo not found")
        end
        client:close()
        return
    end

    -- 8. File Upload: POST /api/upload
    if method == "POST" and path == "/api/upload" then
        local ct = headers["content-type"] or ""
        local boundary = ct:match('boundary="([^"]+)"') or ct:match("boundary=([^;%s]+)")
        local cl = tonumber(headers["content-length"]) or 0

        if not boundary or cl <= 0 or cl > 50 * 1024 * 1024 then
            send_response(client, 400, "application/json", json_encode({success = false, error = "Invalid upload request"}))
            client:close()
            return
        end

        local body, read_err = read_exact_bytes(client, cl)
        if not body then
            send_response(client, 400, "application/json; charset=utf-8", json_encode({success = false, error = "Upload connection interrupted: " .. tostring(read_err)}))
            client:close()
            return
        end
        local saved_files = {}

        local delim = "--" .. boundary
        local pos = 1
        while true do
            local start_p, end_p = body:find(delim, pos, true)
            if not start_p then break end
            local next_p = body:find(delim, end_p + 1, true)
            if not next_p then break end

            local part = body:sub(end_p + 1, next_p - 1)
            local hdr_end = part:find("\r\n\r\n", 1, true)
            if hdr_end then
                local part_hdr = part:sub(1, hdr_end - 1)
                local file_data = part:sub(hdr_end + 4)
                if file_data:sub(-2) == "\r\n" then
                    file_data = file_data:sub(1, -3)
                end

                local fn = part_hdr:match('filename="([^"]+)"')
                if fn and fn ~= "" and #file_data > 0 then
                    fn = sanitize_filename(fn)
                    local ext = fn:match("%.([^.]+)$")
                    ext = ext and ext:lower() or ""
                    if ext == "mp3" or ext == "ogg" or ext == "wav" then
                        local write_ok = false
                        if love and love.filesystem then
                            love.filesystem.createDirectory("assets/music")
                            write_ok = love.filesystem.write("assets/music/" .. fn, file_data) == true
                        else
                            local f = io.open("assets/music/" .. fn, "wb")
                            if f then
                                local ok_w = f:write(file_data)
                                f:close()
                                write_ok = (ok_w ~= nil)
                            end
                        end
                        if write_ok then
                            table.insert(saved_files, fn)
                        end
                    end
                end
            end
            pos = next_p
        end

        if #saved_files > 0 then
            if sound_module and sound_module.reloadPlaylist then
                sound_module.reloadPlaylist()
            end
            send_response(client, 200, "application/json; charset=utf-8", json_encode({
                success = true,
                uploaded = saved_files,
                message = string.format("Successfully added %d track(s) to Jukebox!", #saved_files)
            }))
        else
            send_response(client, 400, "application/json; charset=utf-8", json_encode({
                success = false,
                error = "No valid MP3, OGG, or WAV files found in upload."
            }))
        end
        client:close()
        return
    end

    -- 9. Delete Track: POST /api/delete
    if method == "POST" and path == "/api/delete" then
        local cl = tonumber(headers["content-length"]) or 0
        local body = read_exact_bytes(client, cl)
        if not body then
            send_response(client, 400, "application/json", json_encode({success = false, error = "Invalid request body"}))
            client:close()
            return
        end
        local data = json_decode_simple(body)
        local fn = data.filename

        if not fn or fn == "" then
            send_response(client, 400, "application/json", json_encode({success = false, error = "Filename required"}))
            client:close()
            return
        end

        local safe_name = sanitize_filename(fn)
        if BUILTIN_TRACKS[safe_name:lower()] then
            send_response(client, 403, "application/json", json_encode({success = false, error = "Built-in tracks cannot be deleted"}))
            client:close()
            return
        end

        local removed = false
        if love and love.filesystem then
            removed = love.filesystem.remove("assets/music/" .. safe_name)
        end
        if not removed then
            removed = os.remove("assets/music/" .. safe_name) ~= nil
        end

        if sound_module and sound_module.reloadPlaylist then
            sound_module.reloadPlaylist()
        end

        send_response(client, 200, "application/json; charset=utf-8", json_encode({
            success = true,
            message = string.format("Deleted track '%s'", safe_name)
        }))
        client:close()
        return
    end

    -- 10. Edit Track: POST /api/edit_track
    if method == "POST" and path == "/api/edit_track" then
        local cl = tonumber(headers["content-length"]) or 0
        local body = read_exact_bytes(client, cl)
        if not body then
            send_response(client, 400, "application/json", json_encode({success = false, error = "Invalid request body"}))
            client:close()
            return
        end
        local data = json_decode_simple(body)
        local old_fn = data.old_filename
        local title = data.title or ""
        local artist = data.artist or ""
        local explicit_new = data.new_filename or ""

        if not old_fn or old_fn == "" then
            send_response(client, 400, "application/json", json_encode({success = false, error = "Original filename required"}))
            client:close()
            return
        end

        local safe_old = sanitize_filename(old_fn)
        if BUILTIN_TRACKS[safe_old:lower()] then
            send_response(client, 403, "application/json", json_encode({success = false, error = "Built-in tracks cannot be edited"}))
            client:close()
            return
        end

        local ext = safe_old:match("%.([^.]+)$") or "mp3"
        local raw_new
        if explicit_new ~= "" then
            raw_new = explicit_new
            if not raw_new:match("%.([^.]+)$") then
                raw_new = raw_new .. "." .. ext
            end
        elseif artist ~= "" then
            raw_new = string.format("%s - %s.%s", title, artist, ext)
        else
            raw_new = string.format("%s.%s", title, ext)
        end
        local safe_new = sanitize_filename(raw_new)
        local new_ext = (safe_new:match("%.([^.]+)$") or ""):lower()
        if new_ext ~= "mp3" and new_ext ~= "ogg" and new_ext ~= "wav" then
            safe_new = safe_new .. "." .. ext
        end

        if safe_new == safe_old then
            send_response(client, 200, "application/json; charset=utf-8", json_encode({
                success = true,
                old_filename = safe_old,
                new_filename = safe_new,
                message = string.format("Track '%s' unchanged", safe_new)
            }))
            client:close()
            return
        end

        if BUILTIN_TRACKS[safe_new:lower()] then
            send_response(client, 403, "application/json", json_encode({success = false, error = "Cannot overwrite a built-in track"}))
            client:close()
            return
        end

        local ok_io = false
        local err_msg = "Original track not found"
        if love and love.filesystem then
            local old_content = love.filesystem.read("assets/music/" .. safe_old)
            if old_content then
                local wrote = love.filesystem.write("assets/music/" .. safe_new, old_content)
                if wrote then
                    if safe_new:lower() ~= safe_old:lower() then
                        love.filesystem.remove("assets/music/" .. safe_old)
                    end
                    ok_io = true
                else
                    err_msg = "Failed to write renamed track"
                end
            end
        else
            local f = io.open("assets/music/" .. safe_old, "rb")
            if f then
                local content = f:read("*a")
                f:close()
                local f2 = io.open("assets/music/" .. safe_new, "wb")
                if f2 then
                    local wrote = f2:write(content)
                    f2:close()
                    if wrote then
                        if safe_new:lower() ~= safe_old:lower() then
                            os.remove("assets/music/" .. safe_old)
                        end
                        ok_io = true
                    else
                        err_msg = "Failed to write renamed track"
                    end
                else
                    err_msg = "Failed to open destination file"
                end
            end
        end

        if not ok_io then
            send_response(client, 404, "application/json; charset=utf-8", json_encode({success = false, error = err_msg}))
            client:close()
            return
        end

        if sound_module and sound_module.reloadPlaylist then
            sound_module.reloadPlaylist()
        end

        send_response(client, 200, "application/json; charset=utf-8", json_encode({
            success = true,
            old_filename = safe_old,
            new_filename = safe_new,
            message = string.format("Renamed track to '%s'", safe_new)
        }))
        client:close()
        return
    end

    -- Fallback 404
    send_response(client, 404, "text/plain", "Not Found")
    client:close()
end

-- Non-blocking client poll
function jukebox_web_server.update(sound_module)
    if not server then return end

    -- Cap client accept limit per tick
    for _ = 1, 4 do
        local client, err = server:accept()
        if client then
            pcall(handle_client, client, sound_module)
        else
            break
        end
    end
end

return jukebox_web_server
