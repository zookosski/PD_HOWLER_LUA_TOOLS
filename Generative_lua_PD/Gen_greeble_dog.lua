Dog_Refresh()
Dog_SaveUndo()

local mfloor = math.floor
local mrand  = math.random
local mmax   = math.max
local mmin   = math.min
local msqrt  = math.sqrt

local W = bound_x1 - bound_x0
local H = bound_y1 - bound_y0
local sz = W * H

-- -------------------------------------------------------
-- BLEND MODES  (all operate on 0..1 floats)
-- -------------------------------------------------------
local blend_fns = {}

blend_fns[0] = function(b, s) return mmax(b, s) end                                   -- lighten
blend_fns[1] = function(b, s) return b * s end                                         -- multiply
blend_fns[2] = function(b, s) local v = b + s; return v > 1 and 1 or v end            -- add / lighter
blend_fns[3] = function(b, s) return 1 - (1-b)*(1-s) end                              -- screen
blend_fns[4] = function(b, s) return mmin(b, s) end                                   -- darken
blend_fns[5] = function(b, s)                                                          -- overlay
    if b < 0.5 then return 2*b*s else return 1 - 2*(1-b)*(1-s) end
end
blend_fns[6] = function(b, s)                                                          -- hard-light
    if s < 0.5 then return 2*b*s else return 1 - 2*(1-b)*(1-s) end
end
blend_fns[7] = function(b, s)                                                          -- color-burn
    if s <= 0 then return 0 end
    local v = 1 - (1-b)/s; return v < 0 and 0 or v
end
blend_fns[8] = function(b, s)                                                          -- color-dodge
    if s >= 1 then return 1 end
    local v = b/(1-s); return v > 1 and 1 or v
end
blend_fns[9] = function(b, s)                                                          -- difference
    local v = b - s; return v < 0 and -v or v
end
blend_fns[10] = function(b, s) return b + s - 2*b*s end                               -- exclusion
blend_fns[11] = function(b, s)                                                         -- soft-light
    if s < 0.5 then
        return b - (1 - 2*s)*b*(1-b)
    else
        local d = b < 0.25 and ((16*b - 12)*b + 4)*b or msqrt(b)
        return b + (2*s - 1)*(d - b)
    end
end
local N_BLEND = 12

local function blend_pixel(buf, i, val, alpha, mode)
    local b   = buf[i]
    local blended = blend_fns[mode](b, val)
    buf[i] = b + alpha * (blended - b)
end

-- -------------------------------------------------------
-- LAYER DRAW FUNCTIONS
-- -------------------------------------------------------

local function draw_rect(buf, br_lo, br_hi, alpha, scale_pct, post_steps)
    local sc   = scale_pct / 100.0
    local br   = (mrand(br_lo, br_hi)) / 255.0
    if post_steps >= 2 then
        br = mfloor(br * post_steps) / (post_steps - 1)
    end
    local rw = mrand(mfloor(W * 0.03 * sc), mfloor(W * 0.45 * sc))
    local rh = mrand(mfloor(H * 0.03 * sc), mfloor(H * 0.45 * sc))
    if rw < 2 then rw = 2 end
    if rh < 2 then rh = 2 end
    local rx = mrand(0, mmax(0, W - rw))
    local ry = mrand(0, mmax(0, H - rh))
    local x1 = mmin(rx + rw - 1, W - 1)
    local y1 = mmin(ry + rh - 1, H - 1)
    local mode = mrand(0, N_BLEND - 1)
    for py = ry, y1 do
        local ro = py * W
        for px = rx, x1 do
            blend_pixel(buf, ro + px, br, alpha, mode)
        end
    end
end

local function draw_grid(buf, br_lo, br_hi, alpha, scale_pct, gap, post_steps)
    local sc   = scale_pct / 100.0
    local br   = (mrand(br_lo, br_hi)) / 255.0
    if post_steps >= 2 then
        br = mfloor(br * post_steps) / (post_steps - 1)
    end
    local g    = mmax(4, mfloor(gap * sc))
    local lw   = mrand(1, 2)
    local mode = mrand(0, N_BLEND - 1)
    for py = 0, H - 1 do
        local in_row = (py % g) < lw
        local ro     = py * W
        for px = 0, W - 1 do
            if in_row or (px % g) < lw then
                blend_pixel(buf, ro + px, br, alpha, mode)
            end
        end
    end
end

local function draw_cols(buf, br_lo, br_hi, alpha, scale_pct, gap, post_steps)
    local sc   = scale_pct / 100.0
    local g    = mmax(4, mfloor(gap * sc))
    local mode = mrand(0, N_BLEND - 1)
    local px   = 0
    while px < W do
        local br = (mrand(br_lo, br_hi)) / 255.0
        if post_steps >= 2 then
            br = mfloor(br * post_steps) / (post_steps - 1)
        end
        local cw = mrand(mfloor(g * 0.5), mfloor(g * 1.5))
        if cw < 2 then cw = 2 end
        local ex = mmin(px + cw - 1, W - 1)
        for py = 0, H - 1 do
            local ro = py * W
            for cpx = px, ex do
                blend_pixel(buf, ro + cpx, br, alpha, mode)
            end
        end
        px = px + cw + mrand(0, mfloor(g * 0.4))
    end
end

local function draw_rows(buf, br_lo, br_hi, alpha, scale_pct, gap, post_steps)
    local sc   = scale_pct / 100.0
    local g    = mmax(4, mfloor(gap * sc))
    local mode = mrand(0, N_BLEND - 1)
    local py   = 0
    while py < H do
        local br = (mrand(br_lo, br_hi)) / 255.0
        if post_steps >= 2 then
            br = mfloor(br * post_steps) / (post_steps - 1)
        end
        local rh = mrand(mfloor(g * 0.5), mfloor(g * 1.5))
        if rh < 2 then rh = 2 end
        local ey = mmin(py + rh - 1, H - 1)
        local ro = py * W
        for row = py, ey do
            local row_off = row * W
            for px = 0, W - 1 do
                blend_pixel(buf, row_off + px, br, alpha, mode)
            end
        end
        py = py + rh + mrand(0, mfloor(g * 0.4))
    end
end

local function draw_line(buf, br_lo, br_hi, alpha, w_lo, w_hi, post_steps)
    local br = (mrand(br_lo, br_hi)) / 255.0
    if post_steps >= 2 then
        br = mfloor(br * post_steps) / (post_steps - 1)
    end
    local lw    = mrand(w_lo, w_hi)
    local mode  = mrand(0, N_BLEND - 1)
    local horiz = mrand(0, 1)
    if horiz == 1 then
        local seg_w = mrand(mfloor(W * 0.1), W)
        local seg_x = mrand(0, mmax(0, W - seg_w))
        local py    = mrand(0, H - 1)
        local y0    = mmax(0, py - mfloor(lw / 2))
        local y1    = mmin(H - 1, py + mfloor(lw / 2))
        for row = y0, y1 do
            local ro = row * W
            for px = seg_x, mmin(seg_x + seg_w - 1, W - 1) do
                blend_pixel(buf, ro + px, br, alpha, mode)
            end
        end
    else
        local seg_h = mrand(mfloor(H * 0.1), H)
        local seg_y = mrand(0, mmax(0, H - seg_h))
        local cpx   = mrand(0, W - 1)
        local x0    = mmax(0, cpx - mfloor(lw / 2))
        local x1    = mmin(W - 1, cpx + mfloor(lw / 2))
        for py = seg_y, mmin(seg_y + seg_h - 1, H - 1) do
            local ro = py * W
            for px = x0, x1 do
                blend_pixel(buf, ro + px, br, alpha, mode)
            end
        end
    end
end

-- -------------------------------------------------------
-- MAIN RENDER
-- -------------------------------------------------------

local function render(seed, iters, bg,
                      rect_on, rect_blo, rect_bhi, rect_alpha, rect_sc,
                      grid_on, grid_blo, grid_bhi, grid_alpha, grid_sc, grid_gap,
                      cols_on, cols_blo, cols_bhi, cols_alpha, cols_sc, cols_gap,
                      rows_on, rows_blo, rows_bhi, rows_alpha, rows_sc, rows_gap,
                      lin_on,  lin_blo,  lin_bhi,  lin_alpha,  lin_wlo, lin_whi,
                      post_steps)

    math.randomseed(seed * 7919)

    local buf = {}
    local bg_f = bg / 255.0
    for i = 0, sz - 1 do buf[i] = bg_f end

    local enabled = {}
    if rect_on > 0 then enabled[#enabled+1] = "rect" end
    if grid_on > 0 then enabled[#enabled+1] = "grid" end
    if cols_on > 0 then enabled[#enabled+1] = "cols" end
    if rows_on > 0 then enabled[#enabled+1] = "rows" end
    if lin_on  > 0 then enabled[#enabled+1] = "line" end
    local n_en = #enabled

    if n_en == 0 then
        for py = 0, H - 1 do
            local wy = bound_y0 + py
            local ro = py * W
            for px = 0, W - 1 do
                set_rgb(bound_x0 + px, wy, bg_f, bg_f, bg_f)
            end
        end
        Dog_Refresh()
        return
    end

    local ra = rect_alpha / 100.0
    local ga = grid_alpha / 100.0
    local ca = cols_alpha / 100.0
    local rwa= rows_alpha / 100.0
    local la = lin_alpha  / 100.0

    for iter = 1, iters do
        local layer = enabled[mrand(1, n_en)]
        if layer == "rect" then
            draw_rect(buf, rect_blo, rect_bhi, ra, rect_sc, post_steps)
        elseif layer == "grid" then
            draw_grid(buf, grid_blo, grid_bhi, ga, grid_sc, grid_gap, post_steps)
        elseif layer == "cols" then
            draw_cols(buf, cols_blo, cols_bhi, ca, cols_sc, cols_gap, post_steps)
        elseif layer == "rows" then
            draw_rows(buf, rows_blo, rows_bhi, rwa, rows_sc, rows_gap, post_steps)
        else
            draw_line(buf, lin_blo, lin_bhi, la, lin_wlo, lin_whi, post_steps)
        end
        if iter % 50 == 0 then progress(iter / iters * 0.85) end
    end

    for py = 0, H - 1 do
        local ro = py * W
        local wy = bound_y0 + py
        for px = 0, W - 1 do
            local v = buf[ro + px]
            if v < 0.0 then v = 0.0 end
            if v > 1.0 then v = 1.0 end
            set_rgb(bound_x0 + px, wy, v, v, v)
        end
        if py % 64 == 0 then progress(0.85 + py / H * 0.15) end
    end

    progress(0)
    Dog_Refresh()
end

-- -------------------------------------------------------
-- READ ALL SETTINGS
-- -------------------------------------------------------

local function update_canvas(hs)
    local seed,_    = GUI_GetSettings(hs.seed)
    local iters,_   = GUI_GetSettings(hs.iters)
    local bg,_      = GUI_GetSettings(hs.bg)
    local rect_on,_ = GUI_GetSettings(hs.rect_on)
    local rblo,_    = GUI_GetSettings(hs.rect_blo)
    local rbhi,_    = GUI_GetSettings(hs.rect_bhi)
    local ralf,_    = GUI_GetSettings(hs.rect_alpha)
    local rsc,_     = GUI_GetSettings(hs.rect_sc)
    local grid_on,_ = GUI_GetSettings(hs.grid_on)
    local gblo,_    = GUI_GetSettings(hs.grid_blo)
    local gbhi,_    = GUI_GetSettings(hs.grid_bhi)
    local galf,_    = GUI_GetSettings(hs.grid_alpha)
    local gsc,_     = GUI_GetSettings(hs.grid_sc)
    local ggap,_    = GUI_GetSettings(hs.grid_gap)
    local cols_on,_ = GUI_GetSettings(hs.cols_on)
    local cblo,_    = GUI_GetSettings(hs.cols_blo)
    local cbhi,_    = GUI_GetSettings(hs.cols_bhi)
    local calf,_    = GUI_GetSettings(hs.cols_alpha)
    local csc,_     = GUI_GetSettings(hs.cols_sc)
    local cgap,_    = GUI_GetSettings(hs.cols_gap)
    local rows_on,_ = GUI_GetSettings(hs.rows_on)
    local wblo,_    = GUI_GetSettings(hs.rows_blo)
    local wbhi,_    = GUI_GetSettings(hs.rows_bhi)
    local walf,_    = GUI_GetSettings(hs.rows_alpha)
    local wsc,_     = GUI_GetSettings(hs.rows_sc)
    local wgap,_    = GUI_GetSettings(hs.rows_gap)
    local lin_on,_  = GUI_GetSettings(hs.lin_on)
    local lblo,_    = GUI_GetSettings(hs.lin_blo)
    local lbhi,_    = GUI_GetSettings(hs.lin_bhi)
    local lalf,_    = GUI_GetSettings(hs.lin_alpha)
    local lwlo,_    = GUI_GetSettings(hs.lin_wlo)
    local lwhi,_    = GUI_GetSettings(hs.lin_whi)
    local post,_    = GUI_GetSettings(hs.post)

    GUI_SetCaption("Greeble v6  |  iters=" .. iters .. "  seed=" .. seed ..
                   "  rect=" .. rect_on .. "  grid=" .. grid_on ..
                   "  cols=" .. cols_on .. "  rows=" .. rows_on .. "  lines=" .. lin_on)

    render(seed, iters, bg,
           rect_on, rblo, rbhi, ralf, rsc,
           grid_on, gblo, gbhi, galf, gsc, ggap,
           cols_on, cblo, cbhi, calf, csc, cgap,
           rows_on, wblo, wbhi, walf, wsc, wgap,
           lin_on,  lblo, lbhi, lalf, lwlo, lwhi,
           post)
end

-- -------------------------------------------------------
-- GUI  — 11 scrollers + combos stay under panel limit
-- by splitting heavy params across Combos for on/off
-- -------------------------------------------------------

GUI_SetCaption("Greeble v6  |  DisplacementX algorithm")

local hs = {}

hs.seed     = GUI_AddControl("Scroller", "Seed",               1,   1, 9999)
hs.iters    = GUI_AddControl("Scroller", "Iterations",       400,  10, 2000)
hs.bg       = GUI_AddControl("Scroller", "Background",        20,   0,  120)
hs.post     = GUI_AddControl("Scroller", "Posterize Steps",    6,   0,   16)
GUI_AddControl("Line")
hs.rect_on  = GUI_AddControl("Scroller", "Rect ON  (0=off)",   1,   0,    1)
hs.rect_blo = GUI_AddControl("Scroller", "Rect Br Lo",        40,   0,  255)
hs.rect_bhi = GUI_AddControl("Scroller", "Rect Br Hi",       220,   0,  255)
hs.rect_alpha= GUI_AddControl("Scroller","Rect Alpha %",      80,   1,  100)
hs.rect_sc  = GUI_AddControl("Scroller", "Rect Scale %",     100,  20,  200)
GUI_AddControl("Line")
hs.grid_on  = GUI_AddControl("Scroller", "Grid ON  (0=off)",   1,   0,    1)
hs.grid_blo = GUI_AddControl("Scroller", "Grid Br Lo",        80,   0,  255)
hs.grid_bhi = GUI_AddControl("Scroller", "Grid Br Hi",       240,   0,  255)
hs.grid_alpha= GUI_AddControl("Scroller","Grid Alpha %",      90,   1,  100)
hs.grid_sc  = GUI_AddControl("Scroller", "Grid Scale %",     100,  20,  200)
hs.grid_gap = GUI_AddControl("Scroller", "Grid Gap px",       60,  10,  400)
GUI_AddControl("Line")
hs.cols_on  = GUI_AddControl("Scroller", "Cols ON  (0=off)",   1,   0,    1)
hs.cols_blo = GUI_AddControl("Scroller", "Cols Br Lo",        30,   0,  255)
hs.cols_bhi = GUI_AddControl("Scroller", "Cols Br Hi",       200,   0,  255)
hs.cols_alpha= GUI_AddControl("Scroller","Cols Alpha %",      85,   1,  100)
hs.cols_sc  = GUI_AddControl("Scroller", "Cols Scale %",     100,  20,  200)
hs.cols_gap = GUI_AddControl("Scroller", "Cols Gap px",       80,  10,  400)
GUI_AddControl("Line")
hs.rows_on  = GUI_AddControl("Scroller", "Rows ON  (0=off)",   1,   0,    1)
hs.rows_blo = GUI_AddControl("Scroller", "Rows Br Lo",        30,   0,  255)
hs.rows_bhi = GUI_AddControl("Scroller", "Rows Br Hi",       200,   0,  255)
hs.rows_alpha= GUI_AddControl("Scroller","Rows Alpha %",      85,   1,  100)
hs.rows_sc  = GUI_AddControl("Scroller", "Rows Scale %",     100,  20,  200)
hs.rows_gap = GUI_AddControl("Scroller", "Rows Gap px",       80,  10,  400)
GUI_AddControl("Line")
hs.lin_on   = GUI_AddControl("Scroller", "Lines ON  (0=off)",  1,   0,    1)
hs.lin_blo  = GUI_AddControl("Scroller", "Lines Br Lo",      120,   0,  255)
hs.lin_bhi  = GUI_AddControl("Scroller", "Lines Br Hi",      255,   0,  255)
hs.lin_alpha= GUI_AddControl("Scroller", "Lines Alpha %",     90,   1,  100)
hs.lin_wlo  = GUI_AddControl("Scroller", "Lines W Lo",         1,   1,   20)
hs.lin_whi  = GUI_AddControl("Scroller", "Lines W Hi",         4,   1,   20)

GUI_OpenPanel()

update_canvas(hs)

repeat
    local idx, retval, retstr = GUI_WaitOnEvent()
    if idx > 0 then
        update_canvas(hs)
    end
until idx < 0

GUI_ClosePanel()

if idx == -1 then
    update_canvas(hs)
elseif idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
