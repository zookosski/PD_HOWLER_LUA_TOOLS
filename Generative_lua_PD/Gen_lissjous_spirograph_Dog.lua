local hw   = math.floor(width  / 2)
local hh   = math.floor(height / 2)
local PI   = math.pi
local sin  = math.sin
local cos  = math.cos
local abs  = math.abs
local pow  = math.pow or function(a,b) return a^b end
local floor= math.floor
local sqrt = math.sqrt

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

local function superformula_r(theta, m, n1, n2, n3, a, b)
    local t1 = abs(cos(m * theta / 4.0) / a)
    local t2 = abs(sin(m * theta / 4.0) / b)
    local val = t1^n2 + t2^n3
    if val == 0 then return 0 end
    return val^(-1.0 / n1)
end

local function hypotrochoid(t, R, r, d)
    local x = (R - r) * cos(t) + d * cos((R - r) / r * t)
    local y = (R - r) * sin(t) - d * sin((R - r) / r * t)
    return x, y
end

local function epitrochoid(t, R, r, d)
    local x = (R + r) * cos(t) - d * cos((R + r) / r * t)
    local y = (R + r) * sin(t) - d * sin((R + r) / r * t)
    return x, y
end

local function color_lerp(cr, cg, cb, cr2, cg2, cb2, mix)
    return cr + (cr2 - cr) * mix,
           cg + (cg2 - cg) * mix,
           cb + (cb2 - cb) * mix
end

local function render(big_r, little_r, pen_d, epi_mode,
                       sup_m, sup_n1, sup_n2, sup_n3,
                       scale, rings, ring_twist, folds,
                       thick, col1, col2, use_super, steps_mult)

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            set_rgb(x, y, 0, 0, 0)
        end
    end

    local cr,  cg,  cb  = decimal2rgb(col1)
    local cr2, cg2, cb2 = decimal2rgb(col2)

    local R_f   = big_r    / 100.0
    local r_f   = little_r / 100.0
    local d_f   = pen_d    / 100.0
    local sc    = scale    / 100.0
    local nfold = floor(folds)
    local twist_step = ring_twist * PI / 180.0

    local ratio = r_f > 0 and (R_f / r_f) or 1
    local steps = floor(800 * steps_mult * math.max(1, ratio / 3))
    if steps > 6000 then steps = 6000 end

    local angle_step = 2 * PI / nfold

    for ring = 1, floor(rings) do
        local ring_sc  = sc * (1.0 - (ring - 1) * (0.85 / floor(rings)))
        local twist_r  = (ring - 1) * twist_step
        local mix      = floor(rings) > 1 and (ring - 1) / (floor(rings) - 1) or 0
        local ur, ug, ub = color_lerp(cr, cg, cb, cr2, cg2, cb2, mix)

        local rw = hw * ring_sc
        local rh = hh * ring_sc

        for k = 0, nfold - 1 do
            local base_ang = k * angle_step + twist_r

            for i = 0, steps do
                local t = i / steps * 2 * PI * math.max(little_r, 1)

                local px, py
                if epi_mode == 0 then
                    px, py = hypotrochoid(t, R_f, r_f, d_f)
                else
                    px, py = epitrochoid(t, R_f, r_f, d_f)
                end

                if use_super == 1 then
                    local theta  = math.atan2(py, px)
                    local rad    = sqrt(px*px + py*py)
                    local sr     = superformula_r(theta, sup_m, sup_n1, sup_n2, sup_n3, 1, 1)
                    local sf_max = superformula_r(0,     sup_m, sup_n1, sup_n2, sup_n3, 1, 1)
                    if sf_max > 0 then
                        local warp = sr / sf_max
                        px = px * warp
                        py = py * warp
                    end
                end

                local ca = cos(base_ang)
                local sa = sin(base_ang)
                local rx = px * ca - py * sa
                local ry = px * sa + py * ca

                local sx = floor(hw + rx * rw)
                local sy = floor(hh - ry * rh)
                plot_dot(sx, sy, ur, ug, ub, thick)
            end
        end
    end

    Dog_Refresh()
end

Dog_Refresh()
Dog_SaveUndo()

GUI_SetCaption("Spirograph + Superformula")
GUI_AddControl("TextLabel", "--- Spirograph ---")
local h_bigr  = GUI_AddControl("Scroller", "Outer R",      70,  1, 100)
local h_litr  = GUI_AddControl("Scroller", "Inner r",      30,  1,  99)
local h_pend  = GUI_AddControl("Scroller", "Pen distance", 80,  1, 150)
local h_epi   = GUI_AddControl("Check",    "Epitrochoid (vs Hypo)", 0)
GUI_AddControl("Line")
GUI_AddControl("TextLabel", "--- Superformula warp ---")
local h_sup   = GUI_AddControl("Check",    "Apply Superformula warp", 0)
local h_sm    = GUI_AddControl("Scroller", "SF  m  (petals)",  6,  1, 16)
local h_sn1   = GUI_AddControl("Scroller", "SF n1 (inflate)", 10,  1, 30)
local h_sn2   = GUI_AddControl("Scroller", "SF n2 (pinch A)",  5,  1, 20)
local h_sn3   = GUI_AddControl("Scroller", "SF n3 (pinch B)",  5,  1, 20)
GUI_AddControl("Line")
GUI_AddControl("TextLabel", "--- Symmetry & Scale ---")
local h_folds = GUI_AddControl("Scroller", "N-fold rotations", 1,  1, 12)
local h_twist = GUI_AddControl("Scroller", "Ring twist (deg)", 0,  0, 45)
local h_rings = GUI_AddControl("Scroller", "Rings",            1,  1,  7)
local h_scale = GUI_AddControl("Scroller", "Scale",           85, 10, 100)
GUI_AddControl("Line")
local h_thick = GUI_AddControl("Scroller", "Thickness",        1,  1,  5)
local h_steps = GUI_AddControl("Scroller", "Detail x10",      10,  3, 20)
GUI_AddControl("Line")
local h_col1  = GUI_AddControl("Colorbox", "Color A", hex("00CCFF"))
local h_col2  = GUI_AddControl("Colorbox", "Color B", hex("FF00AA"))

GUI_OpenPanel()

local big_r  = 70
local lit_r  = 30
local pen_d  = 80
local epi    = 0
local use_sup= 0
local sm     = 6
local sn1    = 10
local sn2    = 5
local sn3    = 5
local folds  = 1
local twist  = 0
local rings  = 1
local scale  = 85
local thick  = 1
local steps  = 10
local col1   = hex("00CCFF")
local col2   = hex("FF00AA")

render(big_r, lit_r, pen_d, epi, sm, sn1/10.0, sn2/5.0, sn3/5.0,
       scale, rings, twist, folds, thick, col1, col2, use_sup, steps/10.0)

repeat
    local idx, retval, retstr = GUI_WaitOnEvent()

    if idx == h_bigr  then big_r  = GUI_GetSettings(h_bigr)  end
    if idx == h_litr  then lit_r  = GUI_GetSettings(h_litr)  end
    if idx == h_pend  then pen_d  = GUI_GetSettings(h_pend)  end
    if idx == h_epi   then epi    = GUI_GetSettings(h_epi)   end
    if idx == h_sup   then use_sup= GUI_GetSettings(h_sup)   end
    if idx == h_sm    then sm     = GUI_GetSettings(h_sm)    end
    if idx == h_sn1   then sn1    = GUI_GetSettings(h_sn1)   end
    if idx == h_sn2   then sn2    = GUI_GetSettings(h_sn2)   end
    if idx == h_sn3   then sn3    = GUI_GetSettings(h_sn3)   end
    if idx == h_folds then folds  = GUI_GetSettings(h_folds) end
    if idx == h_twist then twist  = GUI_GetSettings(h_twist) end
    if idx == h_rings then rings  = GUI_GetSettings(h_rings) end
    if idx == h_scale then scale  = GUI_GetSettings(h_scale) end
    if idx == h_thick then thick  = GUI_GetSettings(h_thick) end
    if idx == h_steps then steps  = GUI_GetSettings(h_steps) end
    if idx == h_col1  then col1   = GUI_GetSettings(h_col1)  end
    if idx == h_col2  then col2   = GUI_GetSettings(h_col2)  end

    if idx > -1 then
        render(big_r, lit_r, pen_d, epi, sm, sn1/10.0, sn2/5.0, sn3/5.0,
               scale, rings, twist, folds, thick, col1, col2, use_sup, steps/10.0)
    end

until idx < 0

GUI_ClosePanel()

if idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
