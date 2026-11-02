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
                table.insert(parts, string.format("%q:%s", tostring(k), json_encode(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    elseif t == "string" then
        local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    else
        return "null"
    end
end

local function json_decode_simple(str)
    local obj = {}
    if not str then return obj end
    for k, v in str:gmatch('"([%w_%-]+)"%s*:%s*"([^"]*)"') do
        obj[k] = v
    end
    for k, v in str:gmatch('"([%w_%-]+)"%s*:%s*([%d%.]+)') do
        obj[k] = tonumber(v)
    end
    for k, v in str:gmatch('"([%w_%-]+)"%s*:%s*(true)') do
        obj[k] = true
    end
    for k, v in str:gmatch('"([%w_%-]+)"%s*:%s*(false)') do
        obj[k] = false
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
    if server then
        return true, server_ip, server_port
    end

    if not socket then
        local ok, s = pcall(require, "socket")
        if ok and s then socket = s else return false, "LuaSocket not available" end
    end

    port = port or 8048
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

local function read_exact_bytes(client, count)
    local chunks = {}
    local remaining = count
    while remaining > 0 do
        local chunk_size = math.min(remaining, 65536)
        local data, err, partial = client:receive(chunk_size)
        if data then
            table.insert(chunks, data)
            remaining = remaining - #data
        elseif partial and #partial > 0 then
            table.insert(chunks, partial)
            remaining = remaining - #partial
        else
            break
        end
    end
    return table.concat(chunks)
end

local function send_response(client, status_code, content_type, body, extra_headers)
    local status_text = "OK"
    if status_code == 206 then status_text = "Partial Content"
    elseif status_code == 400 then status_text = "Bad Request"
    elseif status_code == 404 then status_text = "Not Found"
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
        client:send(table.concat(headers, "\r\n"))
        if body and #body > 0 then
            -- Send body in chunks of 64KB
            local sent = 0
            while sent < #body do
                local chunk = body:sub(sent + 1, sent + 65536)
                client:send(chunk)
                sent = sent + #chunk
            end
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
            local t_name = (renderer and renderer.getThemeDisplayName) and renderer.getThemeDisplayName(t_theme, false) or t_theme
            html = html:gsub("__DEVICE_IP__", string.format("%s:%d", server_ip, server_port))
            html = html:gsub("__INITIAL_THEME__", t_theme)
            html = html:gsub("__INITIAL_THEME_NAME__", t_name)
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
        local t_name = (renderer and renderer.getThemeDisplayName) and renderer.getThemeDisplayName(t_theme, false) or t_theme
        local json = json_encode({
            theme = t_theme,
            name = t_name,
            timestamp = os.time()
        })
        send_response(client, 200, "application/json; charset=utf-8", json)
        client:close()
        return
    end

    -- 3. Status info: GET /api/status
    if path == "/api/status" then
        local playlist = sound_module and sound_module.getPlaylist and sound_module.getPlaylist() or {}
        local storage_info = { total_mb = 0, free_mb = 0 }
        pcall(function()
            local h = io.popen and io.popen("df -m . 2>/dev/null")
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
                local size = 0
                if love and love.filesystem then
                    local info = love.filesystem.getInfo(t.path)
                    if info and info.size then size = info.size end
                end
                table.insert(tracks, {
                    filename = t.filename,
                    title = t.title or t.filename,
                    artist = t.artist or "Unknown",
                    is_builtin = is_builtin,
                    size = size
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

        if range_hdr and not is_dl then
            local s_start, s_end = range_hdr:match("bytes=(%d+)%-(%d*)")
            local start_b = tonumber(s_start) or 0
            local end_b = tonumber(s_end) or (total_size - 1)
            if end_b >= total_size then end_b = total_size - 1 end
            local slice_len = end_b - start_b + 1
            local slice = file_data:sub(start_b + 1, end_b + 1)
            table.insert(extra, string.format("Content-Range: bytes %d-%d/%d", start_b, end_b, total_size))
            send_response(client, 206, mime, slice, extra)
        else
            send_response(client, 200, mime, file_data, extra)
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
        local boundary = ct:match("boundary=([^;%s]+)")
        local cl = tonumber(headers["content-length"]) or 0

        if not boundary or cl <= 0 or cl > 50 * 1024 * 1024 then
            send_response(client, 400, "application/json", json_encode({success = false, error = "Invalid upload request"}))
            client:close()
            return
        end

        local body = read_exact_bytes(client, cl)
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
                    fn = sanitize_filename(url_decode(fn))
                    local ext = fn:match("%.([^.]+)$")
                    ext = ext and ext:lower() or ""
                    if ext == "mp3" or ext == "ogg" or ext == "wav" then
                        if love and love.filesystem then
                            love.filesystem.createDirectory("assets/music")
                            love.filesystem.write("assets/music/" .. fn, file_data)
                        else
                            local f = io.open("assets/music/" .. fn, "wb")
                            if f then f:write(file_data); f:close() end
                        end
                        table.insert(saved_files, fn)
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
            os.remove("assets/music/" .. safe_name)
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
        local data = json_decode_simple(body)
        local old_fn = data.old_filename
        local title = data.title or ""
        local artist = data.artist or ""

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
        local safe_new = sanitize_filename(string.format("%s - %s.%s", title, artist, ext))

        if love and love.filesystem then
            local old_content = love.filesystem.read("assets/music/" .. safe_old)
            if old_content then
                love.filesystem.write("assets/music/" .. safe_new, old_content)
                love.filesystem.remove("assets/music/" .. safe_old)
            end
        else
            local f = io.open("assets/music/" .. safe_old, "rb")
            if f then
                local content = f:read("*a")
                f:close()
                local f2 = io.open("assets/music/" .. safe_new, "wb")
                if f2 then f2:write(content); f2:close() end
                os.remove("assets/music/" .. safe_old)
            end
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
