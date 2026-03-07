local hw = math.floor(width / 2)
local hh = math.floor(height / 2)
local PI  = math.pi
local sin = math.sin
local cos = math.cos
local floor = math.floor
local abs   = math.abs

local function safe_set(x, y, r, g, b)
    if x >= 0 and x < width and y >= 0 and y < height then
        set_rgb(x, y, r, g, b)
    end
end

local function plot_dot(x, y, r, g, b, thick)
    local t = floor(thick)
    for dy = -t, t do
        for dx = -t, t do
            if dx*dx + dy*dy <= (t+1)*(t+1) then
                safe_set(x+dx, y+dy, r, g, b)
            end
        end
    end
end

local function stamp_nfold(ax, ay, r, g, b, thick, folds, twist_rad)
    local angle_step = 2 * PI / folds
    for k = 0, folds - 1 do
        local ang = k * angle_step + twist_rad
        local ca  = cos(ang)
        local sa  = sin(ang)
        local rx  = floor(ax * ca - ay * sa)
        local ry  = floor(ax * sa + ay * ca)
        plot_dot(hw + rx, hh - ry, r, g, b, thick)
        plot_dot(hw + rx, hh + ry, r, g, b, thick)
        plot_dot(hw - rx, hh - ry, r, g, b, thick)
        plot_dot(hw - rx, hh + ry, r, g, b, thick)
    end
end

local function draw_cubic_nfold(p0x, p0y, cp1x, cp1y, cp2x, cp2y, p1x, p1y,
                                  r, g, b, thick, steps, folds, twist_rad, organic)
    for i = 0, steps do
        local t  = i / steps
        local mt = 1.0 - t
        local bx = mt*mt*mt*p0x + 3*mt*mt*t*cp1x + 3*mt*t*t*cp2x + t*t*t*p1x
        local by = mt*mt*mt*p0y + 3*mt*mt*t*cp1y + 3*mt*t*t*cp2y + t*t*t*p1y

        if organic > 0 then
            local wobble = organic * 0.03
            bx = bx + sin(t * 11.3 + 1.7) * hw * wobble
            by = by + sin(t *  7.9 + 3.1) * hh * wobble
        end

        stamp_nfold(floor(bx), floor(by), r, g, b, thick, folds, twist_rad)
    end
end

local function lissajous_nfold(la, lb, lphase, length, r, g, b, thick, steps, folds, twist_rad, organic)
    local rw = hw * length / 100.0
    local rh = hh * length / 100.0
    local phase_rad = lphase * PI / 180.0
    for i = 0, steps do
        local t  = i / steps
        local ang = t * 2 * PI
        local bx = rw * sin(la * ang + phase_rad)
        local by = rh * sin(lb * ang)
        if organic > 0 then
            local wobble = organic * 0.03
            bx = bx + sin(t * 13.1) * rw * wobble
            by = by + sin(t *  9.7) * rh * wobble
        end
        stamp_nfold(floor(bx), floor(by), r, g, b, thick, folds, twist_rad)
    end
end

local function render(bend, curl, length, offset, thick, rings, ring_twist,
                       folds, organic, col1, col2, dual, use_liss, la, lb, lphase)
    for y = 0, height-1 do
        for x = 0, width-1 do
            set_rgb(x, y, 0, 0, 0)
        end
    end

    local cr,  cg,  cb  = decimal2rgb(col1)
    local cr2, cg2, cb2 = decimal2rgb(col2)

    local len_f  = length / 100.0
    local bend_f = bend   / 100.0
    local curl_f = curl   / 100.0
    local off_f  = offset / 100.0
    local steps  = 700
    local nfolds = floor(folds)
    local twist_step = ring_twist * PI / 180.0

    for ring = 1, floor(rings) do
        local scale    = 1.0 - (ring - 1) * (0.88 / floor(rings))
        local rw       = hw * scale
        local rh       = hh * scale
        local twist_r  = (ring - 1) * twist_step

        local mix = floor(rings) > 1 and (ring - 1) / (floor(rings) - 1) or 0
        local ur = cr  + (cr2  - cr)  * mix
        local ug = cg  + (cg2  - cg)  * mix
        local ub = cb  + (cb2  - cb)  * mix

        if use_liss == 1 then
            lissajous_nfold(la, lb, lphase, scale * 100.0, ur, ug, ub,
                            thick, steps, nfolds, twist_r, organic)
        else
            local p0x  = 0
            local p0y  = off_f * rh
            local p1x  = rw * len_f
            local p1y  = rh * len_f
            local cp1x = rw * bend_f
            local cp1y = rh * (1.0 - bend_f) * 0.5
            local cp2x = rw * len_f * (1.0 - curl_f * 0.8)
            local cp2y = rh * len_f * curl_f

            draw_cubic_nfold(p0x, p0y, cp1x, cp1y, cp2x, cp2y, p1x, p1y,
                             ur, ug, ub, thick, steps, nfolds, twist_r, organic)

            if dual == 1 then
                local dp0x  = off_f * rw
                local dp0y  = 0
                local dp1x  = rw * len_f
                local dp1y  = rh * len_f
                local dcp1x = rw * (1.0 - bend_f) * 0.5
                local dcp1y = rh * bend_f
                local dcp2x = rw * len_f * curl_f
                local dcp2y = rh * len_f * (1.0 - curl_f * 0.8)
                draw_cubic_nfold(dp0x, dp0y, dcp1x, dcp1y, dcp2x, dcp2y, dp1x, dp1y,
                                 ur, ug, ub, thick, steps, nfolds, twist_r, organic)
            end
        end
    end

    Dog_Refresh()
end

Dog_Refresh()
Dog_SaveUndo()

GUI_SetCaption("Ornamental Pattern Designer v3")
GUI_AddControl("TextLabel", "--- Curve Shape ---")
local h_bend   = GUI_AddControl("Scroller", "Bend   (CP1)",  30,  0, 100)
local h_curl   = GUI_AddControl("Scroller", "Curl   (CP2)",  60,  0, 100)
local h_len    = GUI_AddControl("Scroller", "Length",        75,  5, 100)
local h_off    = GUI_AddControl("Scroller", "Offset",        20,  0, 80)
GUI_AddControl("Line")
GUI_AddControl("TextLabel", "--- Symmetry ---")
local h_folds  = GUI_AddControl("Scroller", "Folds  (N-fold rotation)", 4, 2, 12)
local h_twist  = GUI_AddControl("Scroller", "Ring twist (deg)",          0, 0, 45)
GUI_AddControl("Line")
GUI_AddControl("TextLabel", "--- Style ---")
local h_thick  = GUI_AddControl("Scroller", "Thickness",  2, 1, 6)
local h_rings  = GUI_AddControl("Scroller", "Rings",      1, 1, 7)
local h_org    = GUI_AddControl("Scroller", "Organic wobble", 0, 0, 100)
local h_dual   = GUI_AddControl("Check", "Weave (dual curve)", 0)
GUI_AddControl("Line")
GUI_AddControl("TextLabel", "--- Lissajous Mode ---")
local h_liss   = GUI_AddControl("Check", "Use Lissajous curve", 0)
local h_la     = GUI_AddControl("Scroller", "Liss A freq", 3, 1, 8)
local h_lb     = GUI_AddControl("Scroller", "Liss B freq", 2, 1, 8)
local h_lph    = GUI_AddControl("Scroller", "Liss phase",  90, 0, 180)
GUI_AddControl("Line")
local h_col1   = GUI_AddControl("Colorbox", "Color A", hex("FF4400"))
local h_col2   = GUI_AddControl("Colorbox", "Color B", hex("FFDD00"))

GUI_OpenPanel()

local bend   = 30
local curl   = 60
local length = 75
local offset = 20
local thick  = 2
local rings  = 1
local twist  = 0
local folds  = 4
local organic= 0
local dual   = 0
local liss   = 0
local la     = 3
local lb     = 2
local lph    = 90
local col1   = hex("FF4400")
local col2   = hex("FFDD00")

render(bend, curl, length, offset, thick, rings, twist, folds, organic, col1, col2, dual, liss, la, lb, lph)

repeat
    local idx, retval, retstr = GUI_WaitOnEvent()

    if idx == h_bend  then bend    = GUI_GetSettings(h_bend)  end
    if idx == h_curl  then curl    = GUI_GetSettings(h_curl)  end
    if idx == h_len   then length  = GUI_GetSettings(h_len)   end
    if idx == h_off   then offset  = GUI_GetSettings(h_off)   end
    if idx == h_folds then folds   = GUI_GetSettings(h_folds) end
    if idx == h_twist then twist   = GUI_GetSettings(h_twist) end
    if idx == h_thick then thick   = GUI_GetSettings(h_thick) end
    if idx == h_rings then rings   = GUI_GetSettings(h_rings) end
    if idx == h_org   then organic = GUI_GetSettings(h_org)   end
    if idx == h_dual  then dual    = GUI_GetSettings(h_dual)  end
    if idx == h_liss  then liss    = GUI_GetSettings(h_liss)  end
    if idx == h_la    then la      = GUI_GetSettings(h_la)    end
    if idx == h_lb    then lb      = GUI_GetSettings(h_lb)    end
    if idx == h_lph   then lph     = GUI_GetSettings(h_lph)   end
    if idx == h_col1  then col1    = GUI_GetSettings(h_col1)  end
    if idx == h_col2  then col2    = GUI_GetSettings(h_col2)  end

    if idx > -1 then
        render(bend, curl, length, offset, thick, rings, twist, folds, organic,
               col1, col2, dual, liss, la, lb, lph)
    end

until idx < 0

GUI_ClosePanel()

if idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
