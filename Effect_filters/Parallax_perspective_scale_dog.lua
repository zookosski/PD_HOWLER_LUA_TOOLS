Dog_Refresh()
Dog_SaveUndo()

local W = width
local H = height

local src_r = {}
local src_g = {}
local src_b = {}
local src_h = {}

local function capture_source()
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local i = y * W + x
            local r, g, b = get_rgb(x, y)
            src_r[i] = r
            src_g[i] = g
            src_b[i] = b
            src_h[i] = r * 0.299 + g * 0.587 + b * 0.114
        end
        progress(y / H * 0.35)
    end
    progress(0)
end

local function build_height_from(hsrc)
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local i = y * W + x
            if    hsrc == 0 then src_h[i] = src_r[i]*0.299 + src_g[i]*0.587 + src_b[i]*0.114
            elseif hsrc == 1 then src_h[i] = src_r[i]
            elseif hsrc == 2 then src_h[i] = src_g[i]
            elseif hsrc == 3 then src_h[i] = src_b[i]
            else
                local mx = math.max(src_r[i], src_g[i], src_b[i])
                local mn = math.min(src_r[i], src_g[i], src_b[i])
                src_h[i] = 1 - (mx - mn)
            end
        end
    end
end

local function lerp(a, b, t)    return a + (b - a) * t end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function sample_channel(fx, fy, ch)
    local edge_m  = math.min(W, H) * 0.04
    local out_x   = math.max(0, -fx)       + math.max(0, fx - (W - 1))
    local out_y   = math.max(0, -fy)       + math.max(0, fy - (H - 1))
    local out_d   = math.sqrt(out_x*out_x + out_y*out_y)
    local fade    = clamp(out_d / edge_m, 0, 1)
    fade          = fade * fade

    local ix = clamp(math.floor(fx + 0.5), 0, W - 1)
    local iy = clamp(math.floor(fy + 0.5), 0, H - 1)
    local i  = iy * W + ix

    local val
    if    ch == 0 then val = src_r[i]
    elseif ch == 1 then val = src_g[i]
    else               val = src_b[i]
    end

    local lum = src_r[i]*0.299 + src_g[i]*0.587 + src_b[i]*0.114
    return lerp(val, lum, fade)
end

local function get_h_safe(x, y)
    x = clamp(x, 0, W - 1)
    y = clamp(y, 0, H - 1)
    return src_h[y * W + x]
end

local function render_frame(params, tilt_t)
    local tilt_x      = params.tilt_x * tilt_t
    local tilt_y      = params.tilt_y * tilt_t
    local persp       = params.persp_str / 100
    local vp_x        = (params.vp_x / 100) * W
    local vp_y        = (params.vp_y / 100) * H
    local lat_scale   = (params.lat_str / 100) * math.min(W, H) * (0.08 + params.speed_mul * 0.055)
    local chroma_str  = params.chroma_str / 100
    local do_popout   = params.do_popout
    local lift        = (params.lift_scale / 100) * math.min(W, H) * 0.10
    local invert_h    = params.invert_h

    local rad_x   = tilt_x * math.pi / 180
    local rad_y   = tilt_y * math.pi / 180
    local view_dx = math.sin(rad_x)
    local view_dy = math.sin(rad_y)

    local spec_str   = params.spec_str / 100
    local light_dx   = params.light_dx
    local light_dy   = params.light_dy
    local light_dz   = 0.6
    local lmag       = math.sqrt(light_dx*light_dx + light_dy*light_dy + light_dz*light_dz)
    light_dx = light_dx / lmag
    light_dy = light_dy / lmag
    light_dz = light_dz / lmag

    local out_r = {}
    local out_g = {}
    local out_b = {}

    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local h_val = get_h_safe(x, y)
            if invert_h == 1 then h_val = 1 - h_val end

            local dx = x - vp_x
            local dy = y - vp_y

            local persp_depth  = (dx * view_dx + dy * view_dy) / math.max(1, math.sqrt(dx*dx + dy*dy))
            local depth_signed = h_val * 2 - 1
            local scale_fac    = 1 + depth_signed * persp * math.abs(view_dx + view_dy) * 0.5
            scale_fac          = clamp(scale_fac, 0.3, 3.0)

            local base_sx = vp_x + dx / scale_fac
            local base_sy = vp_y + dy / scale_fac

            local lat_dx = view_dx * (h_val - 0.5) * lat_scale
            local lat_dy = view_dy * (h_val - 0.5) * lat_scale

            if do_popout == 1 then
                local pop_disp = h_val * lift
                lat_dx = lat_dx - view_dx * pop_disp
                lat_dy = lat_dy - view_dy * pop_disp
            end

            local sx = base_sx + lat_dx
            local sy = base_sy + lat_dy

            local edge_dist = math.sqrt(
                (math.max(0, math.abs(dx) - W * 0.4))^2 +
                (math.max(0, math.abs(dy) - H * 0.4))^2
            )
            local ca = chroma_str * clamp(edge_dist / (math.min(W, H) * 0.2), 0, 1)
            local ca_scale_r = 1 + ca * 0.012
            local ca_scale_b = 1 - ca * 0.012

            local sx_r = vp_x + (sx - vp_x) * ca_scale_r
            local sy_r = vp_y + (sy - vp_y) * ca_scale_r
            local sx_b = vp_x + (sx - vp_x) * ca_scale_b
            local sy_b = vp_y + (sy - vp_y) * ca_scale_b

            local r = sample_channel(sx_r, sy_r, 0)
            local g = sample_channel(sx,   sy,   1)
            local b = sample_channel(sx_b, sy_b, 2)

            if do_popout == 1 and spec_str > 0 then
                local gx_n = (get_h_safe(x+1, y) - get_h_safe(x-1, y)) * 0.5
                local gy_n = (get_h_safe(x, y+1) - get_h_safe(x, y-1)) * 0.5
                local gz_n = 0.25
                local nm   = math.sqrt(gx_n*gx_n + gy_n*gy_n + gz_n*gz_n)
                if nm > 0.0001 then gx_n=gx_n/nm; gy_n=gy_n/nm; gz_n=gz_n/nm end
                if invert_h == 1 then gx_n=-gx_n; gy_n=-gy_n end
                local ndotl = clamp(gx_n*light_dx + gy_n*light_dy + gz_n*light_dz, 0, 1)
                local spec  = ndotl * ndotl * ndotl * ndotl * spec_str
                r = clamp(r + spec, 0, 1)
                g = clamp(g + spec, 0, 1)
                b = clamp(b + spec, 0, 1)
            end

            local oi = y * W + x
            out_r[oi] = clamp(r, 0, 1)
            out_g[oi] = clamp(g, 0, 1)
            out_b[oi] = clamp(b, 0, 1)
        end
        progress(y / H)
    end

    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local oi = y * W + x
            set_rgb(x, y, out_r[oi], out_g[oi], out_b[oi])
        end
    end

    progress(0)
    Dog_Refresh()
end

local light_dirs = {
    [0]={ -0.7,-0.7 }, [1]={ 0.0,-1.0 }, [2]={ 0.7,-0.7 },
    [3]={ -1.0, 0.0 },                    [4]={ 1.0, 0.0 },
    [5]={ -0.7, 0.7 }, [6]={ 0.0, 1.0 }, [7]={ 0.7, 0.7 },
}

GUI_SetCaption("Perspective Scale  v1")

GUI_AddControl("TextLabel", "=== Camera Tilt ===")
local h_tiltx   = GUI_AddControl("Scroller", "Tilt X",  20, -60, 60)
local h_lx      = GUI_AddControl("TextLabel", "  >> Tilt X: 20")
local h_tilty   = GUI_AddControl("Scroller", "Tilt Y", -15, -60, 60)
local h_ly      = GUI_AddControl("TextLabel", "  >> Tilt Y: -15")

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== Perspective ===")
local h_persp   = GUI_AddControl("Scroller", "Perspective Strength", 40, 0, 100)
local h_lpersp  = GUI_AddControl("TextLabel", "  >> Perspective: 40")
local h_latstr  = GUI_AddControl("Scroller", "Lateral Shift",        35, 0, 100)
local h_llat    = GUI_AddControl("TextLabel", "  >> Lateral: 35")
local h_spdmul  = GUI_AddControl("Scroller", "Speed Multiplier",      3, 1,  10)
local h_lspd    = GUI_AddControl("TextLabel", "  >> Speed Mul: 3")

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== Vanishing Point ===")
local h_vpx     = GUI_AddControl("Scroller", "VP Horizontal %", 50, 0, 100)
local h_lvpx    = GUI_AddControl("TextLabel", "  >> VP X: 50%  (50=centre)")
local h_vpy     = GUI_AddControl("Scroller", "VP Vertical %",   50, 0, 100)
local h_lvpy    = GUI_AddControl("TextLabel", "  >> VP Y: 50%  (50=centre)")

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== Chromatic Aberration ===")
local h_chroma  = GUI_AddControl("Scroller", "Chroma Strength", 30, 0, 100)
local h_lchroma = GUI_AddControl("TextLabel", "  >> Chroma: 30  (0=off)")

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== Height Source ===")
local h_hsrc    = GUI_AddControl("Combobox", "Height From")
GUI_SetList(h_hsrc, 0, "Luminance")
GUI_SetList(h_hsrc, 1, "Red")
GUI_SetList(h_hsrc, 2, "Green")
GUI_SetList(h_hsrc, 3, "Blue")
GUI_SetList(h_hsrc, 4, "Saturation (inv)")
GUI_SetSettings(h_hsrc, 0, "Luminance")
local h_invh    = GUI_AddControl("Check", "Invert Height", 0)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== Pop-Out Composite ===")
local h_popout  = GUI_AddControl("Check", "Combine with Pop-Out Relief", 1)
local h_lift    = GUI_AddControl("Scroller", "Lift Scale",    35, 1, 100)
local h_llift   = GUI_AddControl("TextLabel", "  >> Lift: 35  (active when Pop-Out on)")
local h_spec    = GUI_AddControl("Scroller", "Specular",      45, 0, 100)
local h_lspec   = GUI_AddControl("TextLabel", "  >> Specular: 45")
local h_ldir    = GUI_AddControl("Combobox", "Light Direction")
GUI_SetList(h_ldir, 0, "Top Left")
GUI_SetList(h_ldir, 1, "Top")
GUI_SetList(h_ldir, 2, "Top Right")
GUI_SetList(h_ldir, 3, "Left")
GUI_SetList(h_ldir, 4, "Right")
GUI_SetList(h_ldir, 5, "Bottom Left")
GUI_SetList(h_ldir, 6, "Bottom")
GUI_SetList(h_ldir, 7, "Bottom Right")
GUI_SetSettings(h_ldir, 0, "Top Left")

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "=== Animation ===")
local h_adir    = GUI_AddControl("Combobox", "Anim Mode")
GUI_SetList(h_adir, 0, "Push In   (flat to full)")
GUI_SetList(h_adir, 1, "Pull Out  (full to flat)")
GUI_SetList(h_adir, 2, "Breathe   (0 > full > 0)")
GUI_SetList(h_adir, 3, "Orbit     (tilt A to B)")
GUI_SetSettings(h_adir, 0, "Push In   (flat to full)")
local h_etx     = GUI_AddControl("Scroller", "Orbit End Tilt X", -20, -60, 60)
local h_ety     = GUI_AddControl("Scroller", "Orbit End Tilt Y",  20, -60, 60)
local h_lanim   = GUI_AddControl("TextLabel", "  End tilt: Orbit mode only")

GUI_AddControl("Line")
local h_preview = GUI_AddControl("Button", "Preview")
local h_anim    = GUI_AddControl("Button", "Render Animation")

local function read_params()
    local p = {}
    p.tilt_x,     _ = GUI_GetSettings(h_tiltx)
    p.tilt_y,     _ = GUI_GetSettings(h_tilty)
    p.persp_str,  _ = GUI_GetSettings(h_persp)
    p.lat_str,    _ = GUI_GetSettings(h_latstr)
    p.speed_mul,  _ = GUI_GetSettings(h_spdmul)
    p.vp_x,       _ = GUI_GetSettings(h_vpx)
    p.vp_y,       _ = GUI_GetSettings(h_vpy)
    p.chroma_str, _ = GUI_GetSettings(h_chroma)
    p.hsrc,       _ = GUI_GetSettings(h_hsrc)
    p.invert_h,   _ = GUI_GetSettings(h_invh)
    p.do_popout,  _ = GUI_GetSettings(h_popout)
    p.lift_scale, _ = GUI_GetSettings(h_lift)
    p.spec_str,   _ = GUI_GetSettings(h_spec)
    local ldir, _   = GUI_GetSettings(h_ldir)
    local ld        = light_dirs[ldir] or light_dirs[0]
    p.light_dx      = ld[1]
    p.light_dy      = ld[2]
    p.adir,       _ = GUI_GetSettings(h_adir)
    p.end_tx,     _ = GUI_GetSettings(h_etx)
    p.end_ty,     _ = GUI_GetSettings(h_ety)
    return p
end

local function update_labels(p)
    GUI_SetSettings(h_lx,      0, "  >> Tilt X: "       .. p.tilt_x)
    GUI_SetSettings(h_ly,      0, "  >> Tilt Y: "       .. p.tilt_y)
    GUI_SetSettings(h_lpersp,  0, "  >> Perspective: "  .. p.persp_str)
    GUI_SetSettings(h_llat,    0, "  >> Lateral: "      .. p.lat_str)
    GUI_SetSettings(h_lspd,    0, "  >> Speed Mul: "    .. p.speed_mul)
    GUI_SetSettings(h_lvpx,    0, "  >> VP X: "         .. p.vp_x .. "%  (50=centre)")
    GUI_SetSettings(h_lvpy,    0, "  >> VP Y: "         .. p.vp_y .. "%  (50=centre)")
    GUI_SetSettings(h_lchroma, 0, "  >> Chroma: "       .. p.chroma_str .. "  (0=off)")
    GUI_SetSettings(h_llift,   0, "  >> Lift: "         .. p.lift_scale .. "  (active when Pop-Out on)")
    GUI_SetSettings(h_lspec,   0, "  >> Specular: "     .. p.spec_str)
end

capture_source()
build_height_from(0)

GUI_OpenPanel()

repeat
    local idx, retval, retstr = GUI_WaitOnEvent()
    local p = read_params()
    update_labels(p)

    if idx == h_hsrc then
        build_height_from(p.hsrc)
    end

    if idx == h_preview then
        Dog_RestoreUndo()
        Dog_GetBuffer()
        render_frame(p, 1.0)
    end

    if idx == h_anim then
        local total = Dog_GetTotalFrames()
        if total <= 0 then
            Dog_MessageBox("No timeline found. Create animation frames first.")
        else
            GUI_ClosePanel()
            for frame = 0, total - 1 do
                local ft = (total > 1) and (frame / (total - 1)) or 0
                local fp = {}
                for k, v in pairs(p) do fp[k] = v end
                local tilt_t

                if     p.adir == 0 then tilt_t = ft
                elseif p.adir == 1 then tilt_t = 1.0 - ft
                elseif p.adir == 2 then tilt_t = 1.0 - math.abs(2.0 * ft - 1.0)
                else
                    fp.tilt_x = lerp(p.tilt_x, p.end_tx, ft)
                    fp.tilt_y = lerp(p.tilt_y, p.end_ty, ft)
                    tilt_t = 1.0
                end

                Dog_GotoFrame(frame)
                Dog_RestoreUndo()
                Dog_GetBuffer()
                build_height_from(fp.hsrc)
                render_frame(fp, tilt_t)
                Dog_Refresh()
                progress(frame / total)
            end
            progress(0)
            Dog_MessageBox("Done!  " .. total .. " frames rendered.")
            return
        end
    end

until idx < 0

GUI_ClosePanel()

if idx == -1 then
    local p = read_params()
    Dog_RestoreUndo()
    Dog_GetBuffer()
    build_height_from(p.hsrc)
    render_frame(p, 1.0)
    Dog_Refresh()
elseif idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
