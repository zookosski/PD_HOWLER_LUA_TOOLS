Dog_Refresh()
Dog_SaveUndo()

GUI_SetCaption("Conformal Tunnel FX v3")

GUI_AddControl("TextLabel", "=== TRANSFORM ENGINE ===")
local h_mode = GUI_AddControl("Combobox", "Mode")
GUI_SetList(h_mode, 0, "Log-Polar Tunnel")
GUI_SetList(h_mode, 1, "Mobius Spiral")
GUI_SetList(h_mode, 2, "Droste Recursion")
GUI_SetList(h_mode, 3, "Orbit Trap Aurora")
GUI_SetList(h_mode, 4, "Joukowski Wings")
GUI_SetList(h_mode, 5, "Polynomial Wiremesh")
GUI_SetList(h_mode, 6, "Complex Sine Wave")
GUI_SetList(h_mode, 7, "Bipolar Dipole")
GUI_SetSettings(h_mode, 5, "Polynomial Wiremesh")

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== GEOMETRY ===")
local h_zoom = GUI_AddControl("Scroller", "Zoom", 50, 1, 200)
local h_twist = GUI_AddControl("Scroller", "Twist / Coeff", 180, 0, 360)
local h_branches = GUI_AddControl("Scroller", "Grid/Branches x10", 60, 10, 240)
local h_iterations = GUI_AddControl("Scroller", "Depth Iters", 12, 1, 40)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== COLOR ENGINE ===")
local h_palette = GUI_AddControl("Combobox", "Palette")
GUI_SetList(h_palette, 0, "Spectral Rainbow")
GUI_SetList(h_palette, 1, "Pastel Dream")
GUI_SetList(h_palette, 2, "Neon Plasma")
GUI_SetList(h_palette, 3, "Gold Ember")
GUI_SetList(h_palette, 4, "Ice Crystal")
GUI_SetList(h_palette, 5, "Canvas Warp")
GUI_SetSettings(h_palette, 2, "Neon Plasma")

local h_saturation = GUI_AddControl("Scroller", "Saturation", 70, 0, 100)
local h_glow = GUI_AddControl("Scroller", "Glow Intensity", 40, 0, 100)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== ANIMATION ===")
local h_save_a = GUI_AddControl("Button", "Save POS A")
local h_save_b = GUI_AddControl("Button", "Save POS B")
local h_anim_speed = GUI_AddControl("Scroller", "Anim Speed", 50, 1, 200)
local h_animate = GUI_AddControl("Button", ">> Animate Frames <<")

local pos_a = nil
local pos_b = nil
local canvas_cache = nil

local function read_all_params()
    local p = {}
    p.mode, _ = GUI_GetSettings(h_mode)
    p.zoom, _ = GUI_GetSettings(h_zoom)
    p.twist, _ = GUI_GetSettings(h_twist)
    local raw_br, _ = GUI_GetSettings(h_branches)
    p.branches = raw_br / 10.0
    p.iters, _ = GUI_GetSettings(h_iterations)
    p.palette, _ = GUI_GetSettings(h_palette)
    p.sat, _ = GUI_GetSettings(h_saturation)
    p.glow, _ = GUI_GetSettings(h_glow)
    p.speed, _ = GUI_GetSettings(h_anim_speed)
    return p
end

local function lerp_params(a, b, t)
    local p = {}
    p.mode = a.mode
    p.palette = a.palette
    p.zoom = a.zoom + (b.zoom - a.zoom) * t
    p.twist = a.twist + (b.twist - a.twist) * t
    p.branches = a.branches + (b.branches - a.branches) * t
    p.iters = math.floor(a.iters + (b.iters - a.iters) * t + 0.5)
    p.sat = a.sat + (b.sat - a.sat) * t
    p.glow = a.glow + (b.glow - a.glow) * t
    p.speed = a.speed
    return p
end

local function cache_canvas()
    Dog_RestoreUndo()
    Dog_GetBuffer()
    canvas_cache = {}
    for cy = 0, height - 1 do
        canvas_cache[cy] = {}
        for cx = 0, width - 1 do
            local cr, cg, cb = get_rgb(cx, cy)
            canvas_cache[cy][cx] = {cr, cg, cb}
        end
    end
end

local function sample_canvas(u, v)
    u = u % 1.0
    v = v % 1.0
    if u < 0 then u = u + 1 end
    if v < 0 then v = v + 1 end
    local sx = math.floor(u * (width - 1))
    local sy = math.floor(v * (height - 1))
    if canvas_cache and canvas_cache[sy] and canvas_cache[sy][sx] then
        return canvas_cache[sy][sx][1], canvas_cache[sy][sx][2], canvas_cache[sy][sx][3]
    end
    return 0.5, 0.5, 0.5
end

local function palette_color(t, palette_id, sat_mult)
    local r, g, b
    t = t % 1.0
    if t < 0 then t = t + 1 end

    if palette_id == 0 then
        r = 0.5 + 0.5 * math.cos(6.2832 * (t + 0.0))
        g = 0.5 + 0.5 * math.cos(6.2832 * (t + 0.333))
        b = 0.5 + 0.5 * math.cos(6.2832 * (t + 0.667))
    elseif palette_id == 1 then
        r = 0.5 + 0.4 * math.cos(6.2832 * (0.8 * t + 0.0))
        g = 0.5 + 0.4 * math.cos(6.2832 * (0.8 * t + 0.25))
        b = 0.5 + 0.4 * math.cos(6.2832 * (0.8 * t + 0.55))
    elseif palette_id == 2 then
        r = 0.5 + 0.5 * math.cos(6.2832 * (2.0 * t + 0.0))
        g = 0.5 + 0.5 * math.cos(6.2832 * (2.0 * t + 0.15))
        b = 0.5 + 0.5 * math.cos(6.2832 * (2.0 * t + 0.70))
    elseif palette_id == 3 then
        r = 0.5 + 0.5 * math.cos(6.2832 * (0.5 * t + 0.0))
        g = 0.3 + 0.3 * math.cos(6.2832 * (0.5 * t + 0.15))
        b = 0.1 + 0.1 * math.cos(6.2832 * (0.5 * t + 0.40))
    elseif palette_id == 4 then
        r = 0.3 + 0.3 * math.cos(6.2832 * (0.7 * t + 0.55))
        g = 0.5 + 0.4 * math.cos(6.2832 * (0.7 * t + 0.35))
        b = 0.6 + 0.4 * math.cos(6.2832 * (0.7 * t + 0.0))
    else
        return 0, 0, 0
    end

    local gray = (r + g + b) / 3.0
    r = gray + (r - gray) * sat_mult
    g = gray + (g - gray) * sat_mult
    b = gray + (b - gray) * sat_mult

    return math.max(0, math.min(1, r)),
           math.max(0, math.min(1, g)),
           math.max(0, math.min(1, b))
end

local function render_frame(p, time_offset)
    local TWO_PI = 6.283185307
    local PI = 3.141592654
    local cxp = width * 0.5
    local cyp = height * 0.5
    local sc = math.min(width, height) * 0.5
    local zoom = p.zoom / 50.0
    local twist_rad = p.twist * PI / 180.0
    local sat = p.sat / 100.0
    local glow = p.glow / 100.0
    local mode = p.mode
    local branches = p.branches
    local iters = p.iters
    local palette_id = p.palette
    local use_canvas = (palette_id == 5)

    for py = 0, height - 1 do
        for px = 0, width - 1 do
            local zx = (px - cxp) / sc * (1.0 / zoom)
            local zy = (py - cyp) / sc * (1.0 / zoom)

            local rx, ry
            if mode == 1 or mode == 5 or mode == 6 or mode == 7 then
                -- Bypass initial rotation for modes that handle twist internally
                rx = zx
                ry = zy
            else
                local cos_tw = math.cos(twist_rad + time_offset * 0.3)
                local sin_tw = math.sin(twist_rad + time_offset * 0.3)
                rx = zx * cos_tw - zy * sin_tw
                ry = zx * sin_tw + zy * cos_tw
            end

            local r, g, b = 0, 0, 0

            if mode == 0 then
                local radius = math.sqrt(rx * rx + ry * ry)
                local angle = math.atan2(ry, rx)
                if radius < 0.0001 then radius = 0.0001 end

                local log_r = math.log(radius)
                local u = angle / TWO_PI + 0.5
                local v = log_r * 0.5 + time_offset * 0.1

                local kaleid_angle = angle
                if branches > 1 then
                    local sector = TWO_PI / branches
                    kaleid_angle = (angle % sector) / sector
                end

                local t = (kaleid_angle / TWO_PI + v * 0.5) % 1.0

                if use_canvas then
                    r, g, b = sample_canvas(u, v)
                else
                    r, g, b = palette_color(t, palette_id, sat)
                end

                local depth_fade = 1.0 / (1.0 + math.abs(log_r) * 0.3)
                local ring_mod = 0.7 + 0.3 * math.cos(log_r * branches + time_offset)
                r = r * depth_fade * ring_mod
                g = g * depth_fade * ring_mod
                b = b * depth_fade * ring_mod

            elseif mode == 1 then
                local theta = twist_rad + time_offset * 0.4
                local cos_t = math.cos(theta)
                local sin_t = math.sin(theta)
                local expansion = 0.05 + (p.zoom - 1) * 0.002

                local a_r = cos_t * (1.0 + expansion)
                local a_i = sin_t * (1.0 + expansion)
                local b_r = 0.6 * math.sin(time_offset * 0.15 + 0.8)
                local b_i = 0.4 * math.cos(time_offset * 0.12 + 1.2)
                local c_r = -0.15 * math.sin(time_offset * 0.1 + 2.0)
                local c_i = 0.15 * math.cos(time_offset * 0.08)
                local d_r = cos_t * (1.0 - expansion)
                local d_i = -sin_t * (1.0 - expansion)

                local trap_min = 1e10
                local trap_angle = 0
                local color_accum = 0
                local sum_weight = 0
                local col_r, col_g, col_b = 0, 0, 0
                local mx, my = zx, zy
                local orbit_radius = 4.0

                for i = 1, iters do
                    local dr = c_r * mx - c_i * my + d_r
                    local di = c_r * my + c_i * mx + d_i
                    local denom_sq = dr * dr + di * di
                    if denom_sq < 0.001 then denom_sq = 0.001 end

                    local nr = a_r * mx - a_i * my + b_r
                    local ni = a_r * my + a_i * mx + b_i
                    mx = (nr * dr + ni * di) / denom_sq
                    my = (ni * dr - nr * di) / denom_sq

                    local mag = math.sqrt(mx * mx + my * my)
                    if mag > orbit_radius then
                        mx = mx / mag * orbit_radius
                        my = my / mag * orbit_radius
                    end

                    local orbit_d = mag
                    local w = 1.0 / (1.0 + i * 0.3)
                    local ct = (math.atan2(my, mx) / TWO_PI + orbit_d * 0.2 + i * 0.07) % 1.0

                    if use_canvas then
                        local cu = (math.atan2(my, mx) / TWO_PI + 0.5) % 1.0
                        local cv = (orbit_d * 0.25) % 1.0
                        local sr, sg, sb = sample_canvas(cu, cv)
                        col_r = col_r + sr * w
                        col_g = col_g + sg * w
                        col_b = col_b + sb * w
                    else
                        local pr, pg, pb = palette_color(ct, palette_id, sat)
                        col_r = col_r + pr * w
                        col_g = col_g + pg * w
                        col_b = col_b + pb * w
                    end
                    sum_weight = sum_weight + w

                    if orbit_d < trap_min then
                        trap_min = orbit_d
                    end
                end

                if sum_weight > 0 then
                    r = col_r / sum_weight
                    g = col_g / sum_weight
                    b = col_b / sum_weight
                end
                local edge = math.exp(-trap_min * 2.0)
                r = r * (0.4 + 0.6 * edge)
                g = g * (0.4 + 0.6 * edge)
                b = b * (0.4 + 0.6 * edge)

            elseif mode == 2 then
                local radius = math.sqrt(rx * rx + ry * ry)
                local angle = math.atan2(ry, rx)
                if radius < 0.0001 then radius = 0.0001 end

                local log_r = math.log(radius)
                local scale_factor = TWO_PI / math.log(branches + 1.5)

                local u = angle * scale_factor / TWO_PI
                local v = log_r * scale_factor / TWO_PI + time_offset * 0.05

                local ring = math.cos(v * PI * branches) * 0.5 + 0.5
                local spoke = math.cos(u * PI * branches) * 0.5 + 0.5

                local t = (u + v + ring * 0.3) % 1.0

                if use_canvas then
                    r, g, b = sample_canvas(u % 1, v % 1)
                    r = r * (0.5 + ring * 0.5)
                    g = g * (0.5 + ring * 0.5)
                    b = b * (0.5 + ring * 0.5)
                else
                    r, g, b = palette_color(t, palette_id, sat)
                end

                local depth = 1.0 / (1.0 + math.abs(log_r) * 0.2)
                local structure = 0.3 + 0.7 * (ring * 0.5 + spoke * 0.5)
                r = r * depth * structure
                g = g * depth * structure
                b = b * depth * structure

            elseif mode == 3 then
                local trap_circle = 1e10
                local trap_line_x = 1e10
                local trap_line_y = 1e10
                local trap_cross = 1e10
                local mx, my = rx, ry

                for i = 1, iters do
                    local angle = math.atan2(my, mx)
                    if branches > 1 then
                        local sector = TWO_PI / branches
                        angle = ((angle % sector) + sector) % sector
                        local rad = math.sqrt(mx * mx + my * my)
                        mx = rad * math.cos(angle)
                        my = rad * math.sin(angle)
                    end

                    local new_x = mx * mx - my * my + rx * 0.7 + math.sin(time_offset * 0.1) * 0.3
                    local new_y = 2.0 * mx * my + ry * 0.7 + math.cos(time_offset * 0.13) * 0.3
                    mx = new_x
                    my = new_y

                    local dist_c = math.abs(math.sqrt(mx * mx + my * my) - 1.0)
                    if dist_c < trap_circle then trap_circle = dist_c end
                    local dist_lx = math.abs(my)
                    if dist_lx < trap_line_x then trap_line_x = dist_lx end
                    local dist_ly = math.abs(mx)
                    if dist_ly < trap_line_y then trap_line_y = dist_ly end
                    local dist_cr = math.min(math.abs(mx - my), math.abs(mx + my)) * 0.7071
                    if dist_cr < trap_cross then trap_cross = dist_cr end

                    if mx * mx + my * my > 100 then break end
                end

                local d1 = math.exp(-trap_circle * 4.0)
                local d2 = math.exp(-trap_line_x * 6.0)
                local d3 = math.exp(-trap_line_y * 6.0)
                local d4 = math.exp(-trap_cross * 5.0)

                if use_canvas then
                    local cu = (d1 + d4 * 0.5) % 1.0
                    local cv = (d2 + d3 * 0.5) % 1.0
                    r, g, b = sample_canvas(cu, cv)
                else
                    local r1, g1, b1 = palette_color(0.0 + time_offset * 0.02, palette_id, sat)
                    local r2, g2, b2 = palette_color(0.33 + time_offset * 0.02, palette_id, sat)
                    local r3, g3, b3 = palette_color(0.55 + time_offset * 0.02, palette_id, sat)
                    local r4, g4, b4 = palette_color(0.78 + time_offset * 0.02, palette_id, sat)
                    r = r1 * d1 + r2 * d2 + r3 * d3 + r4 * d4
                    g = g1 * d1 + g2 * d2 + g3 * d3 + g4 * d4
                    b = b1 * d1 + b2 * d2 + b3 * d3 + b4 * d4
                end

            elseif mode == 4 then
                local zr = rx
                local zi = ry
                local rad_sq = zr * zr + zi * zi
                if rad_sq < 0.0001 then rad_sq = 0.0001 end
                local inv_r = zr / rad_sq
                local inv_i = -zi / rad_sq

                local strength = 0.5 + 0.3 * math.sin(time_offset * 0.2)
                local jr = zr + inv_r * strength
                local ji = zi + inv_i * strength

                local angle = math.atan2(ji, jr)
                local radius = math.sqrt(jr * jr + ji * ji)

                if branches > 1 then
                    local sector = TWO_PI / branches
                    angle = ((angle % sector) + sector) % sector
                end

                local t = (angle / TWO_PI + math.log(radius + 1) * 0.3 + time_offset * 0.05) % 1.0

                if use_canvas then
                    r, g, b = sample_canvas((angle / TWO_PI) % 1, (radius * 0.15) % 1)
                else
                    r, g, b = palette_color(t, palette_id, sat)
                end

                local edge = math.abs(math.sin(radius * 3.0 + time_offset))
                local flow = 0.6 + 0.4 * math.cos(angle * branches + time_offset * 0.5)
                r = r * (0.3 + 0.7 * edge) * flow
                g = g * (0.3 + 0.7 * edge) * flow
                b = b * (0.3 + 0.7 * edge) * flow

            elseif mode == 5 then 
                -- NEW: Polynomial Wiremesh f(z) = z^3 + p*z 
                -- This directly recreates the mathematical visual from the video
                -- Scale twist slider to the polynomial coefficient p (from -4 to 4)
                local p_val = ((p.twist / 360.0) * 8.0 - 4.0) + math.sin(time_offset * 0.5) * 1.0
                
                -- z^3 = (x+iy)^3 = x^3 - 3xy^2 + i(3x^2y - y^3)
                local u = (rx*rx*rx - 3.0*rx*ry*ry) + p_val * rx
                local v = (3.0*rx*rx*ry - ry*ry*ry) + p_val * ry

                -- Procedurally generate the "wiremesh" grid
                local grid_scale = branches * 0.5
                local gu = math.abs((u * grid_scale) % 1.0 - 0.5) * 2.0
                local gv = math.abs((v * grid_scale) % 1.0 - 0.5) * 2.0
                
                -- Distance to nearest grid line
                local dist = math.min(1.0 - gu, 1.0 - gv)
                -- Exponential decay creates the glowing anti-aliased line thickness
                local line_intensity = math.exp(-dist * 15.0)

                if use_canvas then
                    local cr, cg, cb = sample_canvas((u * 0.1) % 1, (v * 0.1) % 1)
                    r = cr * line_intensity + cr * 0.1
                    g = cg * line_intensity + cg * 0.1
                    b = cb * line_intensity + cb * 0.1
                else
                    local pr, pg, pb = palette_color(math.sqrt(u*u + v*v)*0.2 - time_offset * 0.1, palette_id, sat)
                    r = pr * line_intensity
                    g = pg * line_intensity
                    b = pb * line_intensity
                end

            elseif mode == 6 then
                -- NEW: Complex Sine Wave f(z) = sin(z)
                -- sin(x + iy) = sin(x)cosh(y) + i cos(x)sinh(y)
                local freq = 1.0 + (branches / 30.0)
                local sx = rx * freq + twist_rad
                local sy = ry * freq

                -- Manual cosh/sinh calculation for strict Lua compatibility
                local exp_y = math.exp(sy)
                local exp_neg_y = math.exp(-sy)
                local cosh_y = (exp_y + exp_neg_y) * 0.5
                local sinh_y = (exp_y - exp_neg_y) * 0.5

                local u = math.sin(sx) * cosh_y
                local v = math.cos(sx) * sinh_y

                local t = (math.atan2(v, u) / TWO_PI + math.log(math.sqrt(u*u + v*v) + 1.0) * 0.5 - time_offset * 0.2) % 1.0

                if use_canvas then
                    r, g, b = sample_canvas(u % 1.0, v % 1.0)
                else
                    r, g, b = palette_color(t, palette_id, sat)
                end

                -- Add a slight structural shading to enhance the draping effect
                local shading = 1.0 / (1.0 + math.abs(v) * 0.1)
                r = r * shading; g = g * shading; b = b * shading

            elseif mode == 7 then
                -- NEW: Bipolar Dipole f(z) = (z - a) / (z + a)
                -- Creates intersecting looped geometries stretching between two poles
                local ax = math.cos(time_offset * 0.3) * (p.twist / 180.0)
                local ay = math.sin(time_offset * 0.3) * (p.twist / 180.0)

                -- z - a
                local nx = rx - ax
                local ny = ry - ay
                -- z + a
                local dx = rx + ax
                local dy = ry + ay

                local denom_sq = dx*dx + dy*dy
                if denom_sq < 0.0001 then denom_sq = 0.0001 end

                -- Complex division: N / D = N * conj(D) / |D|^2
                local u = (nx * dx + ny * dy) / denom_sq
                local v = (ny * dx - nx * dy) / denom_sq

                local t = (math.atan2(v, u) / TWO_PI * (branches/10.0) + math.log(math.sqrt(u*u + v*v) + 0.1) - time_offset * 0.3) % 1.0

                if use_canvas then
                    r, g, b = sample_canvas((u * 0.5) % 1.0, (v * 0.5) % 1.0)
                else
                    r, g, b = palette_color(t, palette_id, sat)
                end
            end

            if glow > 0 then
                local lum = (r + g + b) / 3.0
                local boost = lum * lum * glow * 1.5
                r = r + boost * 0.3
                g = g + boost * 0.2
                b = b + boost * 0.35
            end

            r = math.max(0, math.min(1, r))
            g = math.max(0, math.min(1, g))
            b = math.max(0, math.min(1, b))
            set_rgb(px, py, r, g, b)
        end
        if py % 8 == 0 then progress(py / height) end
    end
    progress(0)
    Dog_Refresh()
end

repeat
    idx, retval, retstr = GUI_WaitOnEvent()

    if idx == h_save_a then
        pos_a = read_all_params()
        Dog_MessageBox("POS A saved!", "Zoom:" .. pos_a.zoom, "Twist:" .. pos_a.twist, "Branches:" .. string.format("%.1f", pos_a.branches))

    elseif idx == h_save_b then
        pos_b = read_all_params()
        Dog_MessageBox("POS B saved!", "Zoom:" .. pos_b.zoom, "Twist:" .. pos_b.twist, "Branches:" .. string.format("%.1f", pos_b.branches))

    elseif idx == h_animate then
        local total = Dog_GetTotalFrames()
        if total <= 0 then
            Dog_MessageBox("No animation timeline!", "Create frames first via", "Animation > New Animation")
        elseif pos_a == nil or pos_b == nil then
            Dog_MessageBox("Save POS A and POS B first!", "Set sliders to start state > Save POS A", "Set sliders to end state > Save POS B")
        else
            local spd, _ = GUI_GetSettings(h_anim_speed)
            local use_cv = (pos_a.palette == 5)
            if use_cv and canvas_cache == nil then
                cache_canvas()
            end
            for frame = 0, total - 1 do
                Dog_GotoFrame(frame)
                local t = frame / (total - 1)
                local interp = lerp_params(pos_a, pos_b, t)
                local time_val = t * 6.283185307 * (spd / 50.0)
                render_frame(interp, time_val)
                progress(frame / total)
            end
            progress(0)
            Dog_MessageBox("Animation complete!", total .. " frames rendered", "POS A -> POS B interpolated")
        end

    elseif idx > 0 then
        local p = read_all_params()
        if p.palette == 5 and canvas_cache == nil then
            cache_canvas()
        end
        render_frame(p, 0)
    end

until idx < 0

GUI_ClosePanel()

if idx == -1 then
    Dog_MessageBox("Conformal Tunnel applied!")
elseif idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
