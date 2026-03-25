-- ImageMorph_WarpFlow_v2.lua
-- PD Howler DogLua Audio Visualizer - Warp-Flow Image Morpher (v2.1)
-- Upgrades: Bicubic Catmull-Rom sampler, 1D flat flow tables, contrast blend.
-- Replaces linear lerp with gradient-guided block-match warp morph.
-- Pre-compute phase: Sobel edge maps + block-match flow field on image load.
-- Render phase: warp imgA forward by flow*t, warp imgB backward by flow*(1-t), blend.
-- Edge-weighted sharpening: structure snaps before haze dissolves.
-- Hold behavior: envelope must cross threshold before morph begins (imgB holds clean).
-- Audio mode OR LFO clock mode. Zoom bump on peak. All controls from v1 preserved.
-- Requires: convert.exe in C:\Program Files (x86)\Howler\
-- Requires: ffmpeg.exe on PATH (MP3 only)
-- Community Script - PD Howler DogLua

if width == nil or height == nil or GUI_AddControl == nil then
    print("Error: Must run inside PD Howler with GUI support")
    return
end

local m_sin   = math.sin
local m_cos   = math.cos
local m_sqrt  = math.sqrt
local m_floor = math.floor
local m_ceil  = math.ceil
local m_abs   = math.abs
local m_max   = math.max
local m_min   = math.min
local m_pi    = math.pi
local s_byte  = string.byte

local TEMP_DIR = "C:\\Temp"

local function ensure_temp_dir()
    os.execute('cmd /c "if not exist "' .. TEMP_DIR .. '" mkdir "' .. TEMP_DIR .. '""')
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function smoothstep(t)
    return t * t * (3.0 - 2.0 * t)
end

-- ---------------------------------------------------------------------------
-- BMP ENGINE  (proven from Sprite_Animator_v1)
-- ---------------------------------------------------------------------------
local BMP = {}

function BMP.read_u16(file)
    local d = file:read(2)
    if not d or #d < 2 then return 0 end
    local b1, b2 = string.byte(d, 1, 2)
    return b1 + b2 * 256
end

function BMP.read_u32(file)
    local d = file:read(4)
    if not d or #d < 4 then return 0 end
    local b1, b2, b3, b4 = string.byte(d, 1, 4)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

function BMP.read_s32(file)
    local v = BMP.read_u32(file)
    if v >= 2147483648 then v = v - 4294967296 end
    return v
end

function BMP.load(filepath)
    local file = io.open(filepath, "rb")
    if not file then return nil, "Cannot open: " .. filepath end
    local magic = file:read(2)
    if not magic or magic ~= "BM" then file:close(); return nil, "Not a BMP file" end
    BMP.read_u32(file)
    BMP.read_u16(file); BMP.read_u16(file)
    local pixel_offset = BMP.read_u32(file)
    local dib_size = BMP.read_u32(file)
    if dib_size < 40 then file:close(); return nil, "DIB header too small" end
    local bmp_w      = BMP.read_s32(file)
    local bmp_h      = BMP.read_s32(file)
    BMP.read_u16(file)
    local bpp         = BMP.read_u16(file)
    local compression = BMP.read_u32(file)
    BMP.read_u32(file); BMP.read_u32(file); BMP.read_u32(file)
    BMP.read_u32(file); BMP.read_u32(file)
    if compression ~= 0 and compression ~= 3 then
        file:close(); return nil, "Compressed BMP not supported"
    end
    if bpp ~= 24 and bpp ~= 32 and bpp ~= 16 then
        file:close(); return nil, "Only 16/24/32-bit BMP"
    end
    local r_shift, g_shift, b_shift = 16, 8, 0
    local r_max,   g_max,   b_max   = 255, 255, 255
    local use_masks = false
    if compression == 3 then
        local r_mask = BMP.read_u32(file)
        local g_mask = BMP.read_u32(file)
        local b_mask = BMP.read_u32(file)
        if dib_size >= 56 then BMP.read_u32(file) end
        use_masks = true
        local function find_sm(mask)
            if mask == 0 then return 0, 0 end
            local shift = 0; local tmp = mask
            while tmp > 0 and bit.band(tmp, 1) == 0 do
                shift = shift + 1; tmp = bit.rshift(tmp, 1)
            end
            local mx = 0
            while bit.band(tmp, 1) == 1 do mx = mx * 2 + 1; tmp = bit.rshift(tmp, 1) end
            if mx == 0 then mx = 1 end
            return shift, mx
        end
        r_shift, r_max = find_sm(r_mask)
        g_shift, g_max = find_sm(g_mask)
        b_shift, b_max = find_sm(b_mask)
    end
    local top_down = false
    local actual_h = bmp_h
    if bmp_h < 0 then top_down = true; actual_h = -bmp_h end
    local bpp_bytes = bpp / 8
    local row_bytes = bmp_w * bpp_bytes
    local pad = (4 - (row_bytes % 4)) % 4
    file:seek("set", pixel_offset)
    local pixels = {}
    local inv255 = 1.0 / 255.0
    for row = 0, actual_h - 1 do
        local y = top_down and row or (actual_h - 1 - row)
        pixels[y] = {}
        for col = 0, bmp_w - 1 do
            local raw = file:read(bpp_bytes)
            if not raw or #raw < bpp_bytes then
                file:close(); return nil, "Pixel data truncated"
            end
            local r, g, b
            if use_masks and bpp == 32 then
                local b1, b2, b3, b4 = string.byte(raw, 1, 4)
                r = b3 * inv255; g = b2 * inv255; b = b1 * inv255
            elseif use_masks and bpp == 16 then
                local b1, b2 = string.byte(raw, 1, 2)
                local pv = b1 + b2 * 256
                r = bit.band(bit.rshift(pv, r_shift), r_max) / r_max
                g = bit.band(bit.rshift(pv, g_shift), g_max) / g_max
                b = bit.band(bit.rshift(pv, b_shift), b_max) / b_max
            else
                local bb, bg, br = string.byte(raw, 1, 3)
                r = br * inv255; g = bg * inv255; b = bb * inv255
                if bpp == 32 then
                    local a_byte = string.byte(raw, 4)
                    if a_byte then end
                end
            end
            pixels[y][col] = { r, g, b }
        end
        if pad > 0 then file:read(pad) end
    end
    file:close()
    return { width = bmp_w, height = actual_h, bpp = bpp, pixels = pixels }, nil
end

function BMP.convert_to_bmp(src_path, dst_path)
    local cmd = 'cmd /c ""C:\\Program Files (x86)\\Howler\\convert.exe" "'
        .. src_path .. '" BMP3:"' .. dst_path .. '"" 2>&1'
    local h = io.popen(cmd)
    if h then h:read("*a"); h:close() end
    local check = io.open(dst_path, "rb")
    if check then check:close(); return true end
    return false
end

function BMP.load_any(filepath)
    ensure_temp_dir()
    local ext = string.lower(string.match(filepath, "%.(%w+)$") or "")
    if ext == "bmp" then return BMP.load(filepath) end
    local tmp = TEMP_DIR .. "\\morph_img_" .. os.time() .. ".bmp"
    if not BMP.convert_to_bmp(filepath, tmp) then
        return nil, "convert.exe failed on: " .. filepath
    end
    local spr, err = BMP.load(tmp)
    os.remove(tmp)
    return spr, err
end

function BMP.open_file_dialog(title_str)
    local ps_cmd = 'powershell -command "'
        .. "Add-Type -AssemblyName System.Windows.Forms;"
        .. "$f = New-Object System.Windows.Forms.OpenFileDialog;"
        .. "$f.Title = '" .. (title_str or "Select Image") .. "';"
        .. "$f.Filter = 'Image Files|*.bmp;*.png;*.jpg;*.jpeg;*.tif;*.tga|All Files|*.*';"
        .. "if($f.ShowDialog() -eq 'OK'){$f.FileName}"
        .. '"'
    local h = io.popen(ps_cmd)
    if h then
        local path = h:read("*l"); h:close()
        if path and path ~= "" then return path end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- BICUBIC SAMPLER  Catmull-Rom (normalized 0..1 coords)
-- 4x4 neighbourhood, preserves sharp edges through repeated sub-pixel warps.
-- Gemini correctly identified bilinear as accumulated blur over morph frames.
-- ---------------------------------------------------------------------------
local function cubic_hermite(A, B, C, D, t)
    local a = -A * 0.5 + B * 1.5 - C * 1.5 + D * 0.5
    local b =  A       - B * 2.5 + C * 2.0 - D * 0.5
    local c = -A * 0.5            + C * 0.5
    return ((a * t + b) * t + c) * t + B
end

local function img_sample(img, nx, ny)
    local fw = img.width  - 1
    local fh = img.height - 1
    local fx = clamp(nx, 0, 1) * fw
    local fy = clamp(ny, 0, 1) * fh
    local x0 = m_floor(fx); local tx = fx - x0
    local y0 = m_floor(fy); local ty = fy - y0
    local function gp(x, y)
        x = clamp(x, 0, fw); y = clamp(y, 0, fh)
        local row = img.pixels[y]
        if not row then return 0, 0, 0 end
        local px = row[x]
        if not px then return 0, 0, 0 end
        return px[1], px[2], px[3]
    end
    local rr = {}; local rg = {}; local rb = {}
    for j = -1, 2 do
        local py = y0 + j
        local r0,g0,b0 = gp(x0-1, py)
        local r1,g1,b1 = gp(x0,   py)
        local r2,g2,b2 = gp(x0+1, py)
        local r3,g3,b3 = gp(x0+2, py)
        rr[j] = cubic_hermite(r0, r1, r2, r3, tx)
        rg[j] = cubic_hermite(g0, g1, g2, g3, tx)
        rb[j] = cubic_hermite(b0, b1, b2, b3, tx)
    end
    local r = clamp(cubic_hermite(rr[-1], rr[0], rr[1], rr[2], ty), 0, 1)
    local g = clamp(cubic_hermite(rg[-1], rg[0], rg[1], rg[2], ty), 0, 1)
    local b = clamp(cubic_hermite(rb[-1], rb[0], rb[1], rb[2], ty), 0, 1)
    return r, g, b
end

-- ---------------------------------------------------------------------------
-- SOBEL LUMINANCE MAP
-- Returns flat table [y * W + x] = gradient magnitude 0..1
-- ---------------------------------------------------------------------------
local function build_sobel_map(img)
    local W = img.width
    local H = img.height
    local lum = {}
    for y = 0, H - 1 do
        local row = img.pixels[y]
        for x = 0, W - 1 do
            local px = row and row[x]
            if px then
                lum[y * W + x] = px[1] * 0.299 + px[2] * 0.587 + px[3] * 0.114
            else
                lum[y * W + x] = 0
            end
        end
    end
    local edge = {}
    local max_e = 0.0001
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local x0 = m_max(0, x - 1); local x2 = m_min(W - 1, x + 1)
            local y0 = m_max(0, y - 1); local y2 = m_min(H - 1, y + 1)
            local tl = lum[y0*W+x0]; local tc = lum[y0*W+x ]; local tr = lum[y0*W+x2]
            local ml = lum[y *W+x0];                            local mr = lum[y *W+x2]
            local bl = lum[y2*W+x0]; local bc = lum[y2*W+x ]; local br = lum[y2*W+x2]
            local gx = (tr + 2*mr + br) - (tl + 2*ml + bl)
            local gy = (bl + 2*bc + br) - (tl + 2*tc + tr)
            local mag = m_sqrt(gx*gx + gy*gy)
            edge[y*W+x] = mag
            if mag > max_e then max_e = mag end
        end
    end
    local inv = 1.0 / max_e
    for i = 0, W * H - 1 do
        edge[i] = edge[i] * inv
    end
    return edge
end

-- ---------------------------------------------------------------------------
-- BLOCK-MATCH FLOW FIELD  (LK structure tensor scoring)
-- Search over (dx,dy) candidates per block. At each candidate accumulate
-- the LK structure tensor using Sobel gradients of imgA and temporal diff
-- It = lum_a(x,y) - lum_b(x+dx, y+dy).  Score = how well the LK solution
-- for that candidate matches the candidate itself (residual).
-- Flat regions (low determinant) fall back to SAD. Cramer guard from Gemini.
-- ---------------------------------------------------------------------------
local function build_flow_field(img_a, img_b, block_size, search_radius)
    local W  = img_a.width
    local H  = img_a.height
    local bW = m_ceil(W / block_size)
    local bH = m_ceil(H / block_size)

    local function lum_at(img, x, y)
        x = clamp(x, 0, img.width  - 1)
        y = clamp(y, 0, img.height - 1)
        local row = img.pixels[y]
        if not row then return 0 end
        local px = row[x]
        if not px then return 0 end
        return px[1] * 0.299 + px[2] * 0.587 + px[3] * 0.114
    end

    local flow_x = {}
    local flow_y = {}

    for by = 0, bH - 1 do
        local base_y = by * block_size

        for bx = 0, bW - 1 do
            local base_x = bx * block_size

            local best_score = math.huge
            local best_dx    = 0
            local best_dy    = 0

            for dy = -search_radius, search_radius, 2 do
                for dx = -search_radius, search_radius, 2 do

                    local sum_ix2  = 0.0
                    local sum_iy2  = 0.0
                    local sum_ixiy = 0.0
                    local sum_ixt  = 0.0
                    local sum_iyt  = 0.0
                    local count    = 0

                    for ky = 0, block_size - 1, 2 do
                        for kx = 0, block_size - 1, 2 do
                            local ax = base_x + kx
                            local ay = base_y + ky
                            if ax < W and ay < H then
                                local ix = lum_at(img_a, ax+1, ay)   - lum_at(img_a, ax-1, ay)
                                local iy = lum_at(img_a, ax,   ay+1) - lum_at(img_a, ax,   ay-1)
                                local it = lum_at(img_a, ax,   ay)   - lum_at(img_b, ax+dx, ay+dy)
                                sum_ix2  = sum_ix2  + ix * ix
                                sum_iy2  = sum_iy2  + iy * iy
                                sum_ixiy = sum_ixiy + ix * iy
                                sum_ixt  = sum_ixt  + ix * it
                                sum_iyt  = sum_iyt  + iy * it
                                count    = count    + 1
                            end
                        end
                    end

                    if count > 0 then
                        local det = sum_ix2 * sum_iy2 - sum_ixiy * sum_ixiy
                        local score
                        if m_abs(det) > 1e-6 then
                            local inv_det = 1.0 / det
                            local pu = (-sum_iy2  * sum_ixt + sum_ixiy * sum_iyt) * inv_det
                            local pv = ( sum_ixiy * sum_ixt - sum_ix2  * sum_iyt) * inv_det
                            local ddx = pu - dx
                            local ddy = pv - dy
                            score = ddx * ddx + ddy * ddy
                        else
                            local sad = 0.0
                            for ky = 0, block_size - 1, 2 do
                                for kx = 0, block_size - 1, 2 do
                                    local ax = base_x + kx
                                    local ay = base_y + ky
                                    if ax < W and ay < H then
                                        local diff = lum_at(img_a, ax, ay)
                                                   - lum_at(img_b, ax+dx, ay+dy)
                                        sad = sad + diff * diff
                                    end
                                end
                            end
                            score = sad / count
                        end
                        if score < best_score then
                            best_score = score
                            best_dx    = dx
                            best_dy    = dy
                        end
                    end
                end
            end

            local fidx = by * bW + bx
            flow_x[fidx] = best_dx
            flow_y[fidx] = best_dy
        end
    end

    return flow_x, flow_y, bW, bH
end

-- ---------------------------------------------------------------------------
-- FLOW LOOKUP  - bilinear interpolation over 1D flat flow tables
-- 1D layout: index = by * bW + bx  (Gemini memory-safety upgrade)
-- ---------------------------------------------------------------------------
local function get_flow_at(flow_x, flow_y, px, py, block_size, bW, bH)
    local fbx = px / block_size
    local fby = py / block_size
    local bx0 = clamp(m_floor(fbx), 0, bW - 1)
    local by0 = clamp(m_floor(fby), 0, bH - 1)
    local bx1 = m_min(bx0 + 1, bW - 1)
    local by1 = m_min(by0 + 1, bH - 1)
    local tx = fbx - m_floor(fbx)
    local ty = fby - m_floor(fby)
    local i00 = by0 * bW + bx0;  local i10 = by0 * bW + bx1
    local i01 = by1 * bW + bx0;  local i11 = by1 * bW + bx1
    local fx00 = flow_x[i00] or 0; local fx10 = flow_x[i10] or 0
    local fx01 = flow_x[i01] or 0; local fx11 = flow_x[i11] or 0
    local fy00 = flow_y[i00] or 0; local fy10 = flow_y[i10] or 0
    local fy01 = flow_y[i01] or 0; local fy11 = flow_y[i11] or 0
    local fx = lerp(lerp(fx00, fx10, tx), lerp(fx01, fx11, tx), ty)
    local fy = lerp(lerp(fy00, fy10, tx), lerp(fy01, fy11, tx), ty)
    return fx, fy
end

-- ---------------------------------------------------------------------------
-- AUDIO ENGINE  (proven from ReactionDiffusion_v1)
-- ---------------------------------------------------------------------------
local function open_audio_dialog()
    local ps_cmd = 'powershell -command "'
        .. "Add-Type -AssemblyName System.Windows.Forms;"
        .. "$f = New-Object System.Windows.Forms.OpenFileDialog;"
        .. "$f.Title = 'Select Audio File';"
        .. "$f.Filter = 'Audio Files|*.wav;*.mp3|WAV|*.wav|MP3|*.mp3|All Files|*.*';"
        .. "if($f.ShowDialog() -eq 'OK'){$f.FileName}"
        .. '"'
    local h = io.popen(ps_cmd)
    if h then
        local path = h:read("*l"); h:close()
        if path and path ~= "" then return path end
    end
    return nil
end

local function read_u16_le(buf, pos)
    local b1, b2 = s_byte(buf, pos, pos + 1)
    if not b1 or not b2 then return 0 end
    return b1 + b2 * 256
end

local function read_u32_le(buf, pos)
    local b1, b2, b3, b4 = s_byte(buf, pos, pos + 3)
    if not b1 or not b4 then return 0 end
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function read_i16_le(buf, pos)
    local v = read_u16_le(buf, pos)
    if v >= 32768 then v = v - 65536 end
    return v
end

local function read_i24_le(buf, pos)
    local b1, b2, b3 = s_byte(buf, pos, pos + 2)
    if not b1 or not b3 then return 0 end
    local v = b1 + b2 * 256 + b3 * 65536
    if v >= 8388608 then v = v - 16777216 end
    return v
end

local function parse_wav(filepath, max_samples)
    local f = io.open(filepath, "rb")
    if not f then return nil, "Cannot open: " .. filepath end
    local riff_hdr = f:read(12)
    if not riff_hdr or #riff_hdr < 12 then f:close(); return nil, "File too small" end
    if riff_hdr:sub(1, 4) ~= "RIFF" then f:close(); return nil, "Not RIFF" end
    if riff_hdr:sub(9, 12) ~= "WAVE" then f:close(); return nil, "Not WAVE" end
    local audio_format, num_channels, sample_rate, bits_per_sample = 0, 0, 0, 0
    local data_size = 0
    local found_fmt, found_data = false, false
    for _ = 1, 64 do
        local chunk_hdr = f:read(8)
        if not chunk_hdr or #chunk_hdr < 8 then break end
        local cid = chunk_hdr:sub(1, 4)
        local csz = read_u32_le(chunk_hdr, 5)
        if cid == "fmt " then
            local fb = f:read(csz)
            if not fb or #fb < 16 then f:close(); return nil, "fmt truncated" end
            audio_format    = read_u16_le(fb, 1)
            num_channels    = read_u16_le(fb, 3)
            sample_rate     = read_u32_le(fb, 5)
            bits_per_sample = read_u16_le(fb, 15)
            found_fmt = true
            if csz % 2 == 1 then f:read(1) end
        elseif cid == "data" then
            data_size = csz; found_data = true; break
        else
            local skip = csz + (csz % 2)
            if skip > 0 then f:read(skip) end
        end
    end
    if not found_fmt  then f:close(); return nil, "No fmt chunk" end
    if not found_data then f:close(); return nil, "No data chunk" end
    if audio_format ~= 1 then f:close(); return nil, "Only PCM WAV (format=1)" end
    if bits_per_sample ~= 16 and bits_per_sample ~= 24 then
        f:close(); return nil, "Only 16/24-bit PCM"
    end
    local bps        = bits_per_sample / 8
    local frame_size = bps * num_channels
    local total_af   = m_floor(data_size / frame_size)
    local frames_rd  = total_af
    if max_samples and max_samples > 0 and max_samples < total_af then
        frames_rd = max_samples
    end
    local raw = f:read(frames_rd * frame_size)
    f:close()
    if not raw then return nil, "Failed to read sample data" end
    local samples = {}
    local inv16 = 1.0 / 32768.0
    local inv24 = 1.0 / 8388608.0
    if bits_per_sample == 16 then
        if num_channels == 1 then
            for i = 0, frames_rd - 1 do
                samples[i + 1] = read_i16_le(raw, i * 2 + 1) * inv16
            end
        else
            for i = 0, frames_rd - 1 do
                local pos = i * frame_size + 1; local sum = 0
                for ch = 0, num_channels - 1 do sum = sum + read_i16_le(raw, pos + ch * 2) end
                samples[i + 1] = (sum / num_channels) * inv16
            end
        end
    else
        if num_channels == 1 then
            for i = 0, frames_rd - 1 do
                samples[i + 1] = read_i24_le(raw, i * 3 + 1) * inv24
            end
        else
            for i = 0, frames_rd - 1 do
                local pos = i * frame_size + 1; local sum = 0
                for ch = 0, num_channels - 1 do sum = sum + read_i24_le(raw, pos + ch * 3) end
                samples[i + 1] = (sum / num_channels) * inv24
            end
        end
    end
    return { samples = samples, sample_rate = sample_rate,
             channels = num_channels, bits = bits_per_sample, total = frames_rd }, nil
end

local function convert_mp3_to_wav(mp3_path, wav_path)
    ensure_temp_dir()
    local cmd = 'ffmpeg -y -i "' .. mp3_path
        .. '" -acodec pcm_s16le -ar 44100 -ac 1 "'
        .. wav_path .. '" >NUL 2>&1'
    os.execute(cmd)
    local check = io.open(wav_path, "rb")
    if check then check:close(); return true end
    return false
end

local function make_hann_window(n)
    local w = {}
    local inv = 1.0 / (n - 1)
    for i = 0, n - 1 do
        w[i + 1] = 0.5 * (1.0 - m_cos(2.0 * m_pi * i * inv))
    end
    return w
end

local function fft_inplace(re, im, n)
    local j = 0
    for i = 1, n - 1 do
        local b = n / 2
        while j >= b do j = j - b; b = b / 2 end
        j = j + b
        if i < j then
            re[i+1], re[j+1] = re[j+1], re[i+1]
            im[i+1], im[j+1] = im[j+1], im[i+1]
        end
    end
    local len = 2
    while len <= n do
        local half = len / 2
        local ang  = -2.0 * m_pi / len
        local wr = m_cos(ang); local wi = m_sin(ang)
        for i = 0, n - 1, len do
            local cr = 1.0; local ci = 0.0
            for k = 0, half - 1 do
                local ur = re[i+k+1];       local ui = im[i+k+1]
                local vr = re[i+k+half+1] * cr - im[i+k+half+1] * ci
                local vi = re[i+k+half+1] * ci + im[i+k+half+1] * cr
                re[i+k+1]      = ur + vr;   im[i+k+1]      = ui + vi
                re[i+k+half+1] = ur - vr;   im[i+k+half+1] = ui - vi
                local nr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = nr
            end
        end
        len = len * 2
    end
end

local function fft_broadband(samples, start_idx, fft_size, window)
    local re = {}; local im = {}
    local total = #samples
    for i = 1, fft_size do
        local si = start_idx + i - 1
        re[i] = (si >= 1 and si <= total) and (samples[si] * window[i]) or 0.0
        im[i] = 0.0
    end
    fft_inplace(re, im, fft_size)
    local half = fft_size / 2
    local inv  = 2.0 / fft_size
    local bass = 0.0; local mids = 0.0; local highs = 0.0
    local bass_bins = m_floor(half * 0.08)
    local mids_bins = m_floor(half * 0.35)
    for i = 1, half do
        local r = re[i]; local v = im[i]
        local mag = m_sqrt(r * r + v * v) * inv
        if i <= bass_bins then
            if mag > bass then bass = mag end
        elseif i <= mids_bins then
            if mag > mids then mids = mag end
        else
            if mag > highs then highs = mag end
        end
    end
    return bass, mids, highs
end

-- ---------------------------------------------------------------------------
-- GUI
-- ---------------------------------------------------------------------------
local MODE_AUDIO = 1
local MODE_LFO   = 2
local DIV_LABELS = { "Quarter Note", "8th Note", "16th Note" }
local DIV_VALUES = { 1, 2, 4 }
local BLK_LABELS = { "4 px (ultra / v.slow)", "8 px (rich / slow)", "16 px (balanced)", "32 px (fast / coarse)" }
local BLK_VALUES = { 4, 8, 16, 32 }
local SRC_LABELS = { "8 px (tight)", "16 px (medium)", "24 px (loose)" }
local SRC_VALUES = { 8, 16, 24 }

GUI_SetCaption("Image Warp-Morph v2")

local h_load_audio = GUI_AddControl("Button", "Load Audio File")
local h_audio_path = GUI_AddControl("Text",   "Audio")
GUI_SetSettings(h_audio_path, 0, "No audio loaded")

local h_load_a = GUI_AddControl("Button", "Load Image A  (amplitude HIGH)")
local h_path_a = GUI_AddControl("Text",   "Image A")
GUI_SetSettings(h_path_a, 0, "No image loaded")

local h_load_b = GUI_AddControl("Button", "Load Image B  (silence / hold)")
local h_path_b = GUI_AddControl("Text",   "Image B")
GUI_SetSettings(h_path_b, 0, "No image loaded")

GUI_AddControl("Line")

local h_mode = GUI_AddControl("Combobox", "Drive Mode")
GUI_SetList(h_mode, 0, "Audio Reactive")
GUI_SetList(h_mode, 1, "LFO Clock")
GUI_SetSettings(h_mode, 0, "Audio Reactive")

GUI_AddControl("Line")

local h_intensity  = GUI_AddControl("Scroller", "Audio Sensitivity",   100, 10, 400)
local h_attack     = GUI_AddControl("Scroller", "Attack Speed",         80, 10, 100)
local h_release    = GUI_AddControl("Scroller", "Release Speed",        92, 50, 100)
local h_threshold  = GUI_AddControl("Scroller", "Hold Threshold (imgB holds below)", 15, 0, 60)

GUI_AddControl("Line")

local h_bpm = GUI_AddControl("Scroller", "BPM",  120, 40, 240)
local h_div = GUI_AddControl("Combobox", "LFO Division")
for i, d in ipairs(DIV_LABELS) do GUI_SetList(h_div, i - 1, d) end
GUI_SetSettings(h_div, 0, DIV_LABELS[1])

GUI_AddControl("Line")

local h_blk = GUI_AddControl("Combobox", "Flow Block Size")
for i, b in ipairs(BLK_LABELS) do GUI_SetList(h_blk, i - 1, b) end
GUI_SetSettings(h_blk, 0, BLK_LABELS[3])

local h_src = GUI_AddControl("Combobox", "Search Radius")
for i, s in ipairs(SRC_LABELS) do GUI_SetList(h_src, i - 1, s) end
GUI_SetSettings(h_src, 0, SRC_LABELS[1])

local h_edge_w = GUI_AddControl("Scroller", "Edge Snap Weight",  50, 0, 100)
local h_warp_s = GUI_AddControl("Scroller", "Warp Strength",     80, 0, 100)

GUI_AddControl("Line")

local h_zoom_en    = GUI_AddControl("Check",    "Zoom Bump on Peak",  0)
local h_zoom_amt   = GUI_AddControl("Scroller", "Zoom Amount %",     12,  1, 40)
local h_zoom_decay = GUI_AddControl("Scroller", "Zoom Decay Speed",  88, 60, 100)

GUI_AddControl("Line")

local h_render = GUI_AddControl("Button", ">> Render to Animation <<")
local h_info   = GUI_AddControl("Button", "Info")

GUI_OpenPanel()

local audio_data  = nil
local img_a       = nil
local img_b       = nil
local flow_x_tbl  = nil
local flow_y_tbl  = nil
local flow_bW     = 0
local flow_bH     = 0
local flow_blk    = 16
local edge_a      = nil
local edge_b      = nil

local mode_val    = MODE_AUDIO
local intensity   = 100
local attack_val  = 80
local release_val = 92
local threshold_v = 15
local bpm_val     = 120
local div_idx     = 0
local blk_idx     = 1
local src_idx     = 0
local edge_w      = 50
local warp_s      = 80
local zoom_en     = 0
local zoom_amt    = 12
local zoom_decay  = 88

local function read_all_gui()
    intensity,   _ = GUI_GetSettings(h_intensity)
    attack_val,  _ = GUI_GetSettings(h_attack)
    release_val, _ = GUI_GetSettings(h_release)
    threshold_v, _ = GUI_GetSettings(h_threshold)
    bpm_val,     _ = GUI_GetSettings(h_bpm)
    edge_w,      _ = GUI_GetSettings(h_edge_w)
    warp_s,      _ = GUI_GetSettings(h_warp_s)
    zoom_en,     _ = GUI_GetSettings(h_zoom_en)
    zoom_amt,    _ = GUI_GetSettings(h_zoom_amt)
    zoom_decay,  _ = GUI_GetSettings(h_zoom_decay)
end

local function do_load_audio()
    local path = open_audio_dialog()
    if not path then return end
    local ext = string.lower(string.match(path, "%.(%w+)$") or "")
    local wav_path = path; local is_temp = false
    if ext == "mp3" then
        ensure_temp_dir()
        local tmp = TEMP_DIR .. "\\morph_audio_" .. os.time() .. ".wav"
        if not convert_mp3_to_wav(path, tmp) then
            Dog_MessageBox("MP3 conversion failed.", "Ensure ffmpeg.exe is on PATH.")
            return
        end
        wav_path = tmp; is_temp = true
    end
    local adata, err = parse_wav(wav_path, 0)
    if is_temp then os.remove(wav_path) end
    if not adata then Dog_MessageBox("Audio load failed:", err or "?"); return end
    audio_data = adata
    local fname = string.match(path, "([^\\]+)$") or path
    GUI_SetSettings(h_audio_path, 0, fname)
    Dog_MessageBox("Audio Loaded!",
        string.format("%.2fs  |  %d Hz  |  %d-bit  |  %dch",
            adata.total / adata.sample_rate, adata.sample_rate,
            adata.bits, adata.channels))
end

local function try_build_flow()
    if not img_a or not img_b then return end
    local blk = BLK_VALUES[blk_idx + 1] or 16
    local src = SRC_VALUES[src_idx + 1] or 8
    Dog_MessageBox("Building flow field...",
        "Block: " .. blk .. "px   Search: " .. src .. "px",
        "This may take a few seconds.")
    local t0 = os.clock()
    edge_a = build_sobel_map(img_a)
    edge_b = build_sobel_map(img_b)
    flow_x_tbl, flow_y_tbl, flow_bW, flow_bH =
        build_flow_field(img_a, img_b, blk, src)
    flow_blk = blk
    local elapsed = os.clock() - t0
    Dog_MessageBox("Flow field ready!",
        string.format("%.2fs build time", elapsed),
        "Blocks: " .. flow_bW .. " x " .. flow_bH)
end

local function do_load_image(slot)
    local title = (slot == "A") and "Image A (HIGH amplitude)" or "Image B (HOLD / silence)"
    local path = BMP.open_file_dialog(title)
    if not path then return end
    local spr, err = BMP.load_any(path)
    if not spr then Dog_MessageBox("Image load failed:", err or "?"); return end
    local fname = string.match(path, "([^\\]+)$") or path
    if slot == "A" then
        img_a = spr
        GUI_SetSettings(h_path_a, 0, fname .. "  (" .. spr.width .. "x" .. spr.height .. ")")
    else
        img_b = spr
        GUI_SetSettings(h_path_b, 0, fname .. "  (" .. spr.width .. "x" .. spr.height .. ")")
    end
    Dog_MessageBox("Image " .. slot .. " loaded:", fname,
        spr.width .. " x " .. spr.height .. "  (" .. (spr.bpp or "?") .. "-bit)")
    flow_x_tbl = nil
    try_build_flow()
end

-- ---------------------------------------------------------------------------
-- RENDER
-- ---------------------------------------------------------------------------
local function do_render()
    if not img_a then Dog_MessageBox("Image A not loaded!"); return end
    if not img_b then Dog_MessageBox("Image B not loaded!"); return end
    if mode_val == MODE_AUDIO and not audio_data then
        Dog_MessageBox("Audio not loaded!", "Load audio or switch to LFO mode.")
        return
    end
    local total_frames = Dog_GetTotalFrames()
    if total_frames <= 0 then Dog_MessageBox("No animation timeline!"); return end

    if not flow_x_tbl then
        try_build_flow()
        if not flow_x_tbl then Dog_MessageBox("Flow field failed to build."); return end
    end

    read_all_gui()

    local fft_size = 2048
    local hann_win = make_hann_window(fft_size)
    local hop_size = 1
    if audio_data then
        hop_size = m_max(1, m_floor(audio_data.total / total_frames))
    end

    local sensitivity  = intensity * 0.01
    local attack_k     = 1.0 - (attack_val  * 0.01)
    local release_k    = release_val * 0.01
    local hold_thresh  = threshold_v * 0.01
    local edge_weight  = edge_w  * 0.01
    local warp_strength = warp_s * 0.01
    local zoom_amount  = zoom_amt   * 0.01
    local zoom_decay_k = zoom_decay * 0.01

    local bpm          = m_max(1, bpm_val)
    local division     = DIV_VALUES[div_idx + 1] or 1
    local fps_hint     = 30
    local lfo_period   = m_max(1, m_floor((60.0 / bpm / division) * fps_hint))

    local peak_history = {}
    for i = 1, 8 do peak_history[i] = 0.0001 end

    local envelope   = 0.0
    local prev_env   = 0.0
    local zoom_scale = 1.0

    local iW = img_a.width
    local iH = img_a.height

    Dog_SaveUndo()

    for frame = 0, total_frames - 1 do
        Dog_GotoFrame(frame)

        local raw_morph = 0.0

        if mode_val == MODE_AUDIO then
            local start_s = frame * hop_size + 1
            local bass, mids, highs = fft_broadband(
                audio_data.samples, start_s, fft_size, hann_win)
            local raw_amp = m_max(bass, mids * 0.7, highs * 0.4) * sensitivity
            for b = 1, 8 do
                if peak_history[b] < raw_amp then peak_history[b] = raw_amp
                else peak_history[b] = peak_history[b] * 0.97 + raw_amp * 0.03 end
            end
            local norm   = m_max(peak_history[1], 0.0001)
            local normed = clamp(raw_amp / norm, 0, 1)
            if normed > envelope then
                envelope = envelope * attack_k + normed * (1.0 - attack_k)
            else
                envelope = envelope * release_k + normed * (1.0 - release_k)
            end
            raw_morph = clamp(envelope, 0, 1)
        else
            local phase = (frame % lfo_period) / lfo_period
            raw_morph = 0.5 + 0.5 * m_sin(phase * 2.0 * m_pi - m_pi * 0.5)
        end

        local morph_t
        if raw_morph < hold_thresh then
            morph_t = 0.0
        else
            morph_t = (raw_morph - hold_thresh) / (1.0 - hold_thresh)
        end
        morph_t = clamp(morph_t, 0, 1)

        local shaped_t = smoothstep(morph_t)

        if zoom_en == 1 then
            local is_peak = (morph_t > 0.85 and prev_env < 0.85)
            if is_peak then
                zoom_scale = 1.0 + zoom_amount
            else
                zoom_scale = 1.0 + (zoom_scale - 1.0) * zoom_decay_k
            end
            if zoom_scale < 1.0001 then zoom_scale = 1.0 end
        end
        prev_env = morph_t

        local cx = width  * 0.5
        local cy = height * 0.5

        local PURE_THRESH = 0.018

        for py = 0, height - 1 do
            for px = 0, width - 1 do

                local sx, sy
                if zoom_scale > 1.0001 then
                    sx = cx + (px - cx) / zoom_scale
                    sy = cy + (py - cy) / zoom_scale
                else
                    sx = px; sy = py
                end

                local nx = sx / (width  - 1)
                local ny = sy / (height - 1)

                local r, g, b

                if shaped_t < PURE_THRESH then
                    r, g, b = img_sample(img_b, nx, ny)

                elseif shaped_t > (1.0 - PURE_THRESH) then
                    r, g, b = img_sample(img_a, nx, ny)

                else
                    local fdx, fdy = get_flow_at(
                        flow_x_tbl, flow_y_tbl,
                        nx * (iW - 1), ny * (iH - 1),
                        flow_blk, flow_bW, flow_bH)

                    local inv_iW = 1.0 / (iW - 1)
                    local inv_iH = 1.0 / (iH - 1)

                    local ea = edge_a and (edge_a[m_floor(clamp(ny*(iH-1), 0, iH-1)) * iW
                                              + m_floor(clamp(nx*(iW-1), 0, iW-1))]) or 0
                    local eb = edge_b and (edge_b[m_floor(clamp(ny*(iH-1), 0, iH-1)) * iW
                                              + m_floor(clamp(nx*(iW-1), 0, iW-1))]) or 0
                    local edge_factor = m_max(ea, eb)

                    local edge_t  = clamp(shaped_t + edge_factor * edge_weight * shaped_t, 0, 1)
                    local blend_t = lerp(shaped_t, edge_t, edge_weight)

                    local warp_t_a = blend_t * warp_strength
                    local warp_t_b = (1.0 - blend_t) * warp_strength

                    local ax = nx + fdx * warp_t_a * inv_iW
                    local ay = ny + fdy * warp_t_a * inv_iH
                    local bx = nx - fdx * warp_t_b * inv_iW
                    local by = ny - fdy * warp_t_b * inv_iH

                    local ra, ga, ba = img_sample(img_a, ax, ay)
                    local rb, gb, bb = img_sample(img_b, bx, by)

                    local function contrast_blend(c1, c2, t)
                        local base = c1 + (c2 - c1) * t
                        local curve = base * base * (3.0 - 2.0 * base)
                        return lerp(base, curve, 0.5)
                    end

                    r = clamp(contrast_blend(rb, ra, blend_t), 0, 1)
                    g = clamp(contrast_blend(gb, ga, blend_t), 0, 1)
                    b = clamp(contrast_blend(bb, ba, blend_t), 0, 1)
                end

                set_rgb(px, py, r, g, b)
            end
            if py % 32 == 0 then
                progress((frame + py / height) / total_frames)
            end
        end

        Dog_Refresh()
        if Dog_CheckQuit and Dog_CheckQuit() then break end
    end

    progress(0)
    Dog_GotoFrame(0)
    local mode_str = (mode_val == MODE_AUDIO) and "Audio Reactive"
        or ("LFO  " .. bpm_val .. "BPM  " .. DIV_LABELS[div_idx + 1])
    Dog_MessageBox("Render Complete!",
        "Frames: " .. total_frames,
        "Mode: " .. mode_str,
        "Flow block: " .. (BLK_VALUES[blk_idx + 1] or 16) .. "px",
        "Zoom: " .. (zoom_en == 1 and "ON " .. zoom_amt .. "%" or "OFF"))
end

-- ---------------------------------------------------------------------------
-- EVENT LOOP
-- ---------------------------------------------------------------------------
repeat
    idx, retval, retstr = GUI_WaitOnEvent()

    if idx == h_load_audio then
        do_load_audio()
    elseif idx == h_load_a then
        do_load_image("A")
    elseif idx == h_load_b then
        do_load_image("B")
    elseif idx == h_mode then
        mode_val = retval + 1
        if mode_val < 1 then mode_val = 1 end
        if mode_val > 2 then mode_val = 2 end
    elseif idx == h_intensity  then intensity,   _ = GUI_GetSettings(h_intensity)
    elseif idx == h_attack     then attack_val,  _ = GUI_GetSettings(h_attack)
    elseif idx == h_release    then release_val, _ = GUI_GetSettings(h_release)
    elseif idx == h_threshold  then threshold_v, _ = GUI_GetSettings(h_threshold)
    elseif idx == h_bpm        then bpm_val,     _ = GUI_GetSettings(h_bpm)
    elseif idx == h_edge_w     then edge_w,      _ = GUI_GetSettings(h_edge_w)
    elseif idx == h_warp_s     then warp_s,      _ = GUI_GetSettings(h_warp_s)
    elseif idx == h_zoom_en    then zoom_en,     _ = GUI_GetSettings(h_zoom_en)
    elseif idx == h_zoom_amt   then zoom_amt,    _ = GUI_GetSettings(h_zoom_amt)
    elseif idx == h_zoom_decay then zoom_decay,  _ = GUI_GetSettings(h_zoom_decay)

    elseif idx == h_div then
        div_idx = retval
        if div_idx < 0 then div_idx = 0 end
        if div_idx > 2 then div_idx = 2 end

    elseif idx == h_blk then
        blk_idx = retval
        if blk_idx < 0 then blk_idx = 0 end
        if blk_idx > 3 then blk_idx = 3 end
        flow_x_tbl = nil

    elseif idx == h_src then
        src_idx = retval
        if src_idx < 0 then src_idx = 0 end
        if src_idx > 2 then src_idx = 2 end
        flow_x_tbl = nil

    elseif idx == h_info then
        local af = flow_x_tbl and (flow_bW .. "x" .. flow_bH .. " blocks") or "NOT BUILT"
        Dog_MessageBox("Warp-Morph v2",
            "Img A: " .. (img_a and (img_a.width .. "x" .. img_a.height) or "none"),
            "Img B: " .. (img_b and (img_b.width .. "x" .. img_b.height) or "none"),
            "Flow field: " .. af,
            "Audio: " .. (audio_data and
                string.format("%.2fs  %dHz", audio_data.total / audio_data.sample_rate,
                    audio_data.sample_rate) or "none"),
            "Mode: " .. (mode_val == MODE_AUDIO and "Audio" or "LFO"),
            "Canvas: " .. width .. "x" .. height .. "  Frames: " .. Dog_GetTotalFrames())

    elseif idx == h_render then
        read_all_gui()
        do_render()
    end

until idx < 0

GUI_ClosePanel()

if idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
