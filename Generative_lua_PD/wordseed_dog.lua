local total = Dog_GetTotalFrames()
if total <= 0 then
    Dog_MessageBox("No animation!", "Create a timeline first")
    return
end

Dog_SaveUndo()

GUI_SetCaption("Word Coil")
h_thick   = GUI_AddControl("Scroller", "Line Thickness",   2,  0,  9)
h_coilr   = GUI_AddControl("Scroller", "Coil Radius",     15,  0, 79)
h_spd     = GUI_AddControl("Scroller", "Speed",            5,  0, 19)
GUI_AddControl("Line")
h_single  = GUI_AddControl("Check",    "Single Color",     0,  0,  1)
h_color   = GUI_AddControl("Colorbox", "",    hex("FF4400"),  0,  0)
h_hue     = GUI_AddControl("Scroller", "Hue Shift (multi)",0,  0, 360)
GUI_AddControl("Line")
h_synced  = GUI_AddControl("Check",    "Synced Turns",     0,  0,  1)
h_glow    = GUI_AddControl("Check",    "Glow",             0,  0,  1)
h_nodes   = GUI_AddControl("Check",    "Show Nodes",       1,  0,  1)
GUI_AddControl("Line")
h_seed    = GUI_AddControl("Text",     "Word Seed (space separated)")

GUI_OpenPanel()

thickness_raw = 2
coil_r_raw    = 15
spd_raw       = 5
single_color  = 0
pick_color    = hex("FF4400")
hue_shift     = 0
synced        = 0
do_glow       = 0
do_nodes      = 1
seed_str      = ""

repeat
    idx, retval, retstr = GUI_WaitOnEvent()
    thickness_raw, dummy = GUI_GetSettings(h_thick)
    coil_r_raw,   dummy  = GUI_GetSettings(h_coilr)
    spd_raw,      dummy  = GUI_GetSettings(h_spd)
    single_color, dummy  = GUI_GetSettings(h_single)
    pick_color,   dummy  = GUI_GetSettings(h_color)
    hue_shift,    dummy  = GUI_GetSettings(h_hue)
    synced,       dummy  = GUI_GetSettings(h_synced)
    do_glow,      dummy  = GUI_GetSettings(h_glow)
    do_nodes,     dummy  = GUI_GetSettings(h_nodes)
    dummy, seed_str      = GUI_GetSettings(h_seed)
until idx < 0

GUI_ClosePanel()

if idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
    return
end

if not seed_str then seed_str = "" end
thickness = math.floor(thickness_raw) + 1
coil_r    = math.floor(coil_r_raw)   + 5
speed     = math.floor(spd_raw)      + 1

function word_to_raw_sum(word)
    local sum = 0
    for i = 1, #word do
        local b = word:sub(i,i):lower():byte()
        if b >= 97 and b <= 122 then
            sum = sum + (b - 96)
        end
    end
    if sum == 0 then sum = 13 end
    return sum
end

words = {}
for w in seed_str:gmatch("%S+") do
    words[#words + 1] = w
end

if #words == 0 then
    words = { "alpha", "bravo", "cedar", "delta" }
end

line_count = #words

raw_sums = {}
angles   = {}
coils    = {}
for i = 1, line_count do
    local s     = word_to_raw_sum(words[i])
    raw_sums[i] = s
    local deg   = s % 360
    if deg == 0 then deg = 360 end
    angles[i]   = deg
    coils[i]    = math.floor(s / 360)
end

function hsv_to_rgb(h, s, v)
    h = h % 360
    local c  = v * s
    local x  = c * (1 - math.abs((h / 60) % 2 - 1))
    local m  = v - c
    local cr, cg, cb = 0, 0, 0
    if     h < 60  then cr, cg, cb = c, x, 0
    elseif h < 120 then cr, cg, cb = x, c, 0
    elseif h < 180 then cr, cg, cb = 0, c, x
    elseif h < 240 then cr, cg, cb = 0, x, c
    elseif h < 300 then cr, cg, cb = x, 0, c
    else                cr, cg, cb = c, 0, x
    end
    return cr + m, cg + m, cb + m
end

pick_r, pick_g, pick_b = decimal2rgb(pick_color)

cx        = width  * 0.5
cy        = height * 0.5
RADIUS    = thickness * 0.5 + 0.5
SEG_STEPS = math.max(10, math.floor(total / line_count))
STEP      = speed * 0.5 + 0.5

function get_line_color(i)
    if single_color == 1 then
        return pick_r, pick_g, pick_b
    end
    local hue = ((i - 1) / line_count * 360 + hue_shift) % 360
    return hsv_to_rgb(hue, 0.9, 1.0)
end

function get_node_color(i)
    if single_color == 1 then
        local h, s, v = 0, 0, 0
        local r, g, b = pick_r, pick_g, pick_b
        local max_c = math.max(r, g, b)
        local min_c = math.min(r, g, b)
        local delta = max_c - min_c
        if delta > 0.001 then
            if max_c == r then h = 60 * (((g - b) / delta) % 6)
            elseif max_c == g then h = 60 * ((b - r) / delta + 2)
            else h = 60 * ((r - g) / delta + 4) end
        end
        local comp_hue = (h + 180) % 360
        return hsv_to_rgb(comp_hue, 0.9, 1.0)
    end
    return 1.0, 1.0, 1.0
end

function sdf_draw(ax, ay, bx, by, sr, sg, sb, rad, alpha_mul)
    local dx   = bx - ax
    local dy   = by - ay
    local len2 = dx * dx + dy * dy
    local xmin = math.floor(math.min(ax, bx) - rad)
    local xmax = math.floor(math.max(ax, bx) + rad) + 1
    local ymin = math.floor(math.min(ay, by) - rad)
    local ymax = math.floor(math.max(ay, by) + rad) + 1
    for qy = ymin, ymax do
        if qy >= 0 and qy < height then
            for qx = xmin, xmax do
                if qx >= 0 and qx < width then
                    local dist
                    if len2 < 0.0001 then
                        local ex = qx - ax
                        local ey = qy - ay
                        dist = math.sqrt(ex * ex + ey * ey)
                    else
                        local t  = ((qx - ax) * dx + (qy - ay) * dy) / len2
                        t        = math.max(0, math.min(1, t))
                        local fx = ax + t * dx - qx
                        local fy = ay + t * dy - qy
                        dist     = math.sqrt(fx * fx + fy * fy)
                    end
                    if dist < rad then
                        local alpha = math.min(1.0, (1.0 - dist / rad) * 2.5) * alpha_mul
                        local er, eg, eb = get_rgb(qx, qy)
                        set_rgb(qx, qy,
                            math.min(1, er + sr * alpha),
                            math.min(1, eg + sg * alpha),
                            math.min(1, eb + sb * alpha))
                    end
                end
            end
        end
    end
end

function draw_seg(ax, ay, bx, by, sr, sg, sb)
    if do_glow == 1 then
        sdf_draw(ax, ay, bx, by, sr, sg, sb, RADIUS * 3, 0.25)
        sdf_draw(ax, ay, bx, by, sr, sg, sb, RADIUS * 2, 0.5)
    end
    sdf_draw(ax, ay, bx, by, sr, sg, sb, RADIUS, 1.0)
end

function draw_node(nx, ny, nr, ng, nb)
    local node_rad = RADIUS * 3
    sdf_draw(nx, ny, nx, ny, nr, ng, nb, node_rad, 0.5)
end

tendril_table = {}

for i = 1, line_count do
    local lr, lg, lb = get_line_color(i)
    local nr, ng, nb = get_node_color(i)

    local pts      = {}
    local nodes    = {}
    local px       = cx
    local py       = cy
    local heading  = math.rad((i - 1) / line_count * 360 - 90)
    pts[1]         = { x = px, y = py }

    for seg = 1, line_count do
        if seg > 1 then
            local angle_idx
            if synced == 1 then
                angle_idx = seg
            else
                angle_idx = ((i - 1 + seg - 1) % line_count) + 1
            end
            local turn_sign = 1
            if angle_idx % 2 == 0 then turn_sign = -1 end
            heading = heading + turn_sign * math.rad(angles[angle_idx])
        end

        local angle_idx
        if synced == 1 then
            angle_idx = seg
        else
            angle_idx = ((i - 1 + seg - 1) % line_count) + 1
        end
        local num_coils  = coils[angle_idx]
        local perp       = heading + math.rad(90)
        local total_loops = num_coils + 0.5

        for s = 1, SEG_STEPS do
            local t       = (s - 1) / (SEG_STEPS - 1)
            local spine_x = px + math.cos(heading) * STEP * s
            local spine_y = py + math.sin(heading) * STEP * s
            local osc     = math.sin(t * 2 * math.pi * total_loops) * coil_r
            local wx      = spine_x + math.cos(perp) * osc
            local wy      = spine_y + math.sin(perp) * osc
            pts[#pts + 1] = { x = wx, y = wy }
        end

        px = px + math.cos(heading) * STEP * SEG_STEPS
        py = py + math.sin(heading) * STEP * SEG_STEPS

        nodes[#nodes + 1] = { x = px, y = py, pt_idx = #pts }
    end

    tendril_table[i] = {
        pts   = pts,
        nodes = nodes,
        lr    = lr, lg = lg, lb = lb,
        nr    = nr, ng = ng, nb = nb
    }
end

local max_pts = 0
for i = 1, #tendril_table do
    if #tendril_table[i].pts > max_pts then
        max_pts = #tendril_table[i].pts
    end
end

for frame = 0, total - 1 do
    Dog_GotoFrame(frame)

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            set_rgb(x, y, 0, 0, 0)
        end
    end

    local reveal = math.floor((frame + 1) / total * (max_pts - 1))
    if reveal < 1 then reveal = 1 end

    for i = 1, #tendril_table do
        t = tendril_table[i]
        local draw_to = math.min(reveal, #t.pts - 1)
        for s = 1, draw_to do
            draw_seg(t.pts[s].x, t.pts[s].y, t.pts[s+1].x, t.pts[s+1].y, t.lr, t.lg, t.lb)
        end

        if do_nodes == 1 then
            for n = 1, #t.nodes do
                if t.nodes[n].pt_idx <= reveal then
                    draw_node(t.nodes[n].x, t.nodes[n].y, t.nr, t.ng, t.nb)
                end
            end
        end
    end

    Dog_Refresh()
    progress(frame / total)
end

progress(0)

report = ""
for i = 1, line_count do
    report = report .. words[i] .. "=" .. angles[i] .. "deg/" .. coils[i] .. "x  "
end
Dog_MessageBox("Word Coil Complete", "Lines=" .. line_count, report)
