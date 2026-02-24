-- ============================================================
-- HOWLER / TEXT BEAT SYNC v3
-- text_beat_sync_v3.lua
--
-- CONFIRMED DogLua API only:
--   get_rgb(x,y)         → r,g,b  (0.0–1.0 lowercase globals)
--   set_rgb(x,y,r,g,b)   → write pixel (0.0–1.0 lowercase globals)
--   flush()              → push buffer to canvas (confirmed alias)
--   Dog_GotoFrame(n)     → seek to animation frame
--   Dog_GetBuffer()      → read canvas into buffer
--   Dog_ShellExe(cmd)    → blocking shell command
--   Dog_Refresh()        → refresh Howler UI
--   Dog_SaveUndo()       → save undo point
--   Dog_MessageBox(t,m)  → modal dialog
--   io.open / io.popen   → file & pipe I/O (confirmed)
--   os.remove(path)      → delete file (confirmed)
--   os.clock()           → timer (confirmed)
--
-- NOT USED (unconfirmed / nil in DogLua):
--   Dog_SetBuffer    → use flush() instead
--   Dog_GetWidth     → canvas size comes from params file
--   Dog_GetHeight    → canvas size comes from params file
--   Dog_GetTotalFrames → total_frames exported from HTML tool
--   Dog_ValueBox     → not confirmed, replaced with params-driven flow
-- ============================================================

local CONVERT_EXE = '"C:\\Program Files (x86)\\Howler\\convert.exe"'
local TEMP_DIR    = os.getenv("TEMP") or "C:\\Temp"

Dog_Refresh()
Dog_SaveUndo()

-- ============================================================
-- FILE DIALOG via PowerShell (confirmed io.popen pattern)
-- ============================================================
local function open_file_dialog()
    local ps = 'powershell -command "'
        .. 'Add-Type -AssemblyName System.Windows.Forms;'
        .. '$f=New-Object System.Windows.Forms.OpenFileDialog;'
        .. "$f.Title='Select Text Beat Params';"
        .. "$f.Filter='Text Files|*.txt|All Files|*.*';"
        .. "if($f.ShowDialog()-eq [System.Windows.Forms.DialogResult]::OK){$f.FileName}"
        .. '"'
    local h = io.popen(ps)
    if not h then return nil end
    local path = h:read("*l")
    h:close()
    if path and path:match("%S") then
        return path:match("^%s*(.-)%s*$")
    end
    return nil
end

-- ============================================================
-- FLAT KEY=VALUE PARAMS PARSER
-- ============================================================
local function parse_params(path)
    local f = io.open(path, "r")
    if not f then return nil, "Cannot open: " .. tostring(path) end
    local p = {}
    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            local k, v = line:match("^([^=]+)=(.*)$")
            if k and v then p[k:match("^%s*(.-)%s*$")] = v:match("^%s*(.-)%s*$") end
        end
    end
    f:close()
    return p
end

local function pnum(p, k, d) local v=p[k]; return v and tonumber(v) or d end
local function pstr(p, k, d) local v=p[k]; return (v and v~="") and v or (d or "") end

-- ============================================================
-- BUILD STEP TABLE
-- ============================================================
local function build_steps(p, n)
    local sm = {}
    for i = 0, n-1 do
        if pnum(p, "step_"..i.."_active", 0) == 1 then
            sm[i] = {
                index     = i,
                text      = pstr(p, "step_"..i.."_text",      "?"),
                font_file = pstr(p, "step_"..i.."_font_file",  ""),
                size      = pnum(p, "step_"..i.."_size",       120),
                x         = pnum(p, "step_"..i.."_x",          50),
                y         = pnum(p, "step_"..i.."_y",          50),
                align     = pstr(p, "step_"..i.."_align",       "center"),
                attack    = pnum(p, "step_"..i.."_attack",      0),
                decay     = pnum(p, "step_"..i.."_decay",       80),
                release   = pnum(p, "step_"..i.."_release",     20),
                velocity  = pnum(p, "step_"..i.."_velocity",    100),
                bmp_path  = nil,
                bmp       = nil,
            }
        end
    end
    return sm
end

-- ============================================================
-- RENDER TEXT → BMP via confirmed convert.exe
-- Uses BMP3 (24-bit uncompressed) for our pure-Lua BMP reader
-- ============================================================
local function render_text_to_bmp(step, fonts_dir, cw, ch, out_path)
    local gravity = "Center"
    if step.align == "left"  then gravity = "West"  end
    if step.align == "right" then gravity = "East"  end

    -- Pixel offset from canvas center
    local off_x = math.floor((step.x - 50) / 100.0 * cw)
    local off_y = math.floor((step.y - 50) / 100.0 * ch)
    local geom  = string.format("%+d%+d", off_x, off_y)

    -- Font file path (user places TTFs in fonts_dir)
    local font_arg = ""
    if step.font_file and step.font_file ~= "" then
        font_arg = '-font "' .. fonts_dir .. step.font_file .. '"'
    end

    -- Sanitize text: double-quotes → single-quotes, escape backslash
    local safe = step.text:gsub('"', "'"):gsub('\\', '\\\\')

    local cmd = CONVERT_EXE
        .. " -size "      .. cw .. "x" .. ch
        .. " xc:black"
        .. " "            .. font_arg
        .. " -pointsize " .. step.size
        .. " -fill white"
        .. " -gravity "   .. gravity
        .. " -annotate "  .. geom .. ' "' .. safe .. '"'
        .. ' BMP3:"'      .. out_path .. '"'

    -- Dog_ShellExe is blocking — waits until convert.exe finishes
    Dog_ShellExe(cmd)

    -- Verify the BMP was created and has content (>54 bytes = real BMP)
    local test = io.open(out_path, "rb")
    if test then
        local sz = test:seek("end")
        test:close()
        return sz and sz > 54
    end
    return false
end

-- ============================================================
-- PURE-LUA BMP LOADER → pixel table [y][x] = {r, g, b} (0.0–1.0)
-- Confirmed pattern from project sprite loaders
-- Handles BMP3 (24-bit uncompressed) as produced by ImageMagick
-- ============================================================
local function load_bmp(path)
    local f = io.open(path, "rb")
    if not f then return nil, "Cannot open BMP: " .. path end

    local function rd2()
        local b = f:read(2); if not b or #b<2 then return 0 end
        return b:byte(1) + b:byte(2)*256
    end
    local function rd4()
        local b = f:read(4); if not b or #b<4 then return 0 end
        return b:byte(1) + b:byte(2)*256 + b:byte(3)*65536 + b:byte(4)*16777216
    end
    local function rd4s()
        local v = rd4(); return v >= 0x80000000 and v-0x100000000 or v
    end

    -- BMP file header: 14 bytes
    local sig = f:read(2)
    if sig ~= "BM" then f:close(); return nil, "Not BMP (sig=" .. tostring(sig) .. ")" end
    rd4()       -- file size (skip)
    rd2(); rd2()-- reserved (skip)
    local pix_off = rd4()  -- offset to pixel data

    -- DIB header
    local dib = rd4()  -- DIB header size
    local bw, bh, bpp

    if dib == 12 then
        -- BITMAPCOREHEADER (rare/old)
        bw = rd2(); bh = rd2(); rd2(); bpp = rd2()
    else
        -- BITMAPINFOHEADER (standard — what ImageMagick BMP3 produces)
        bw = rd4s(); bh = rd4s()
        rd2()       -- color planes
        bpp = rd2() -- bits per pixel
        if dib > 16 then f:read(dib - 16) end  -- skip rest of header
    end

    local flip = bh > 0   -- positive height = bottom-up row storage
    bh = math.abs(bh)

    if bpp ~= 24 then
        f:close()
        return nil, "Need 24-bit BMP, got "..bpp.."-bit. Check ImageMagick BMP3 output."
    end

    -- Row stride: 24bpp pixels padded to 4-byte boundary
    local row_stride = math.floor((bw * 3 + 3) / 4) * 4

    f:seek("set", pix_off)

    local pixels = {}
    for row = 0, bh-1 do
        local y = flip and (bh-1-row) or row
        pixels[y] = {}
        local data = f:read(row_stride)
        if not data then break end
        for x = 0, bw-1 do
            local base = x*3 + 1
            local b = data:byte(base)   or 0  -- BMP stores BGR
            local g = data:byte(base+1) or 0
            local r = data:byte(base+2) or 0
            pixels[y][x] = { r/255.0, g/255.0, b/255.0 }
        end
    end

    f:close()
    return pixels
end

-- ============================================================
-- ENVELOPE: Attack / Sustain-in-Decay / Release
-- attack=0 → frame 0 is full brightness (no ramp-in, instant on)
-- ============================================================
local function envelope(fi, total, atk, dec, rel)
    if atk == 0 then
        -- Instant-on: full brightness from frame 0
        local d = math.max(1, math.floor(dec/100.0 * total))
        if fi < d then return 1.0 end
        local r = math.max(1, math.floor(rel/100.0 * total))
        return math.max(0.0, 1.0 - (fi-d)/r)
    end
    local a = math.max(1, math.floor(atk/100.0 * total))
    local d = math.max(1, math.floor(dec/100.0 * total))
    local r = math.max(1, math.floor(rel/100.0 * total))
    if fi < a     then return fi/a                         end
    if fi < a+d   then return 1.0                          end
    return math.max(0.0, 1.0 - (fi-a-d)/r)
end

-- ============================================================
-- MAIN
-- ============================================================

-- Step 1: Select params file
Dog_MessageBox("TEXT BEAT SYNC v3",
    "Click OK then choose your text_beat_params.txt file.\n\n"
    .. "Make sure your Howler animation has the correct\n"
    .. "number of frames BEFORE running this script.\n"
    .. "(The HTML tool shows the required frame count.)")

local params_path = open_file_dialog()
if not params_path then
    Dog_MessageBox("TEXT BEAT SYNC", "No file selected. Aborting.")
    return
end

-- Step 2: Parse params
local params, err = parse_params(params_path)
if not params then
    Dog_MessageBox("TEXT BEAT SYNC — ERROR", tostring(err))
    return
end

-- Step 3: Extract all settings
local tempo       = pnum(params, "tempo",            120)
local fps         = pnum(params, "fps",               24)
local clock_mult  = pnum(params, "clock_mult",         1)
local triplet     = pnum(params, "triplet",            0)
local frames_step = pnum(params, "frames_per_step",   12)
local total_frames= pnum(params, "total_frames",      96)
local num_steps   = pnum(params, "steps",             16)
local cw          = pnum(params, "canvas_w",        1920)
local ch          = pnum(params, "canvas_h",        1080)
local fonts_dir   = pstr(params, "fonts_dir",    "fonts\\")

-- Confirm the render plan
local ok_msg = string.format(
    "RENDER PLAN\n\n"
    .. "BPM: %d  |  FPS: %d  |  Mult: %dx%s\n"
    .. "Frames per step: %d\n"
    .. "Total frames: %d\n"
    .. "Canvas: %dx%d\n"
    .. "Fonts dir: %s\n\n"
    .. "Ensure your Howler animation has %d frames.\n"
    .. "Click OK to begin rendering.",
    tempo, fps, clock_mult, (triplet==1 and " (triplet)" or ""),
    frames_step, total_frames, cw, ch, fonts_dir, total_frames
)
Dog_MessageBox("TEXT BEAT SYNC v3 — READY", ok_msg)

-- Step 4: Build step table
local step_map = build_steps(params, num_steps)

local active_count = 0
for _ in pairs(step_map) do active_count = active_count + 1 end

if active_count == 0 then
    Dog_MessageBox("TEXT BEAT SYNC", "No active steps found. Nothing to render.")
    return
end

-- Step 5: Pre-render all text BMPs to disk
-- Dog_ShellExe is blocking so each convert.exe call completes before next
local bmp_paths = {}

for si, step in pairs(step_map) do
    local out_path = TEMP_DIR .. "\\tbs_step_" .. si .. ".bmp"
    bmp_paths[si]  = out_path
    step.bmp_path  = out_path

    local ok = render_text_to_bmp(step, fonts_dir, cw, ch, out_path)
    if not ok then
        Dog_MessageBox(
            "TEXT BEAT SYNC — WARNING",
            string.format(
                'Step %d: convert.exe may have failed.\n'
                .. 'Text: "%s"\n'
                .. 'Font: %s\n'
                .. 'Check fonts_dir and font filename.',
                si+1, step.text, step.font_file
            )
        )
    end
end

-- Step 6: FRAME LOOP — step-outer, frame-inner for memory efficiency
-- (one BMP pixel table in RAM at a time, ~6–12MB peak for 1080p)

-- Build frame → step index lookup table
local frame_to_step = {}
for frame = 0, total_frames-1 do
    frame_to_step[frame] = math.floor(frame / frames_step) % num_steps
end

local steps_done = 0

for si = 0, num_steps-1 do
    local step = step_map[si]
    if step then
        -- Load this step's BMP into pixel table
        local bmp, bmp_err = load_bmp(step.bmp_path)

        if not bmp then
            Dog_MessageBox(
                "TEXT BEAT SYNC — BMP LOAD ERROR",
                "Step " .. (si+1) .. ": " .. tostring(bmp_err)
            )
        else
            step.bmp = bmp

            -- Process every frame that maps to this step index
            for frame = 0, total_frames-1 do
                if frame_to_step[frame] == si then
                    local fi    = frame % frames_step
                    local env_v = envelope(fi, frames_step, step.attack, step.decay, step.release)
                    local alpha = env_v * (step.velocity / 100.0)

                    -- Seek frame and read canvas into buffer
                    Dog_GotoFrame(frame)
                    Dog_GetBuffer()

                    if alpha > 0.002 then
                        -- Additive blend: white text adds luminance to canvas
                        -- Using confirmed lowercase get_rgb / set_rgb (0.0–1.0)
                        for y = 0, ch-1 do
                            local row = step.bmp[y]
                            if row then
                                for x = 0, cw-1 do
                                    local px = row[x]
                                    -- White BMP: R=G=B, use R channel as luminance mask
                                    if px and px[1] > 0.008 then
                                        local cr, cg, cb = get_rgb(x, y)
                                        local add = px[1] * alpha
                                        set_rgb(x, y,
                                            math.min(1.0, cr + add),
                                            math.min(1.0, cg + add),
                                            math.min(1.0, cb + add))
                                    end
                                end
                            end
                        end
                    end

                    -- Push buffer to canvas — confirmed DogLua call
                    flush()
                end
            end

            -- Free BMP memory before loading next step
            step.bmp = nil
        end

        steps_done = steps_done + 1
    end
end

-- Step 7: Clean up temp BMPs
for _, path in pairs(bmp_paths) do
    os.remove(path)
end

-- Step 8: Done
Dog_Refresh()
Dog_MessageBox(
    "TEXT BEAT SYNC v3 — COMPLETE",
    string.format(
        "Render finished!\n\n"
        .. "%d frames processed\n"
        .. "%d active steps rendered\n\n"
        .. "Tempo: %d BPM  |  FPS: %d  |  Mult: %dx\n"
        .. "Frames per step: %d  |  Total: %d",
        total_frames, active_count,
        tempo, fps, clock_mult,
        frames_step, total_frames
    )
)
