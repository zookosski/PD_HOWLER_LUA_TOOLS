-- Pan_CL v2 - Keyframe Animation
-- Start → Middle → End frame control for X and Y
-- Perfect for scrolling backgrounds and credits

function store_canvas(use_selection)
    local r_data = {}
    local g_data = {}
    local b_data = {}
    
    local x0 = use_selection and bound_x0 or 0
    local x1 = use_selection and bound_x1 or (width - 1)
    local y0 = use_selection and bound_y0 or 0
    local y1 = use_selection and bound_y1 or (height - 1)
    
    for y = y0, y1 do
        for x = x0, x1 do
            local r, g, b = get_rgb(x, y)
            table.insert(r_data, r)
            table.insert(g_data, g)
            table.insert(b_data, b)
        end
    end
    
    return r_data, g_data, b_data, x0, x1, y0, y1
end

function pan_canvas(offset_x, offset_y, wrap, canvas_r, canvas_g, canvas_b, x0, x1, y0, y1)
    local src_w = x1 - x0 + 1
    local src_h = y1 - y0 + 1
    
    for y = 0, src_h - 1 do
        for x = 0, src_w - 1 do
            local src_x = x - offset_x
            local src_y = y - offset_y
            
            local r, g, b = 0, 0, 0
            
            if wrap then
                src_x = src_x % src_w
                src_y = src_y % src_h
                if src_x < 0 then src_x = src_x + src_w end
                if src_y < 0 then src_y = src_y + src_h end
                
                r = canvas_r[src_y * src_w + src_x + 1]
                g = canvas_g[src_y * src_w + src_x + 1]
                b = canvas_b[src_y * src_w + src_x + 1]
            else
                if src_x >= 0 and src_x < src_w and src_y >= 0 and src_y < src_h then
                    r = canvas_r[src_y * src_w + src_x + 1]
                    g = canvas_g[src_y * src_w + src_x + 1]
                    b = canvas_b[src_y * src_w + src_x + 1]
                end
            end
            
            set_rgb(x0 + x, y0 + y, r, g, b)
        end
        
        if y % 20 == 0 then
            progress(y / src_h)
        end
    end
    
    progress(0)
    Dog_Refresh()
end

function interpolate_keyframes(frame, start_f, start_v, mid_f, mid_v, end_f, end_v)
    if frame <= start_f then
        return start_v
    elseif frame <= mid_f then
        local t = (frame - start_f) / (mid_f - start_f)
        return start_v + (mid_v - start_v) * t
    elseif frame <= end_f then
        local t = (frame - mid_f) / (end_f - mid_f)
        return mid_v + (end_v - mid_v) * t
    else
        return end_v
    end
end

Dog_SaveUndo()

local has_selection = (bound_x1 - bound_x0) < (width - 1) or (bound_y1 - bound_y0) < (height - 1)

GUI_SetCaption("Pan CL v2 - Keyframe Animation")

if has_selection then
    GUI_AddControl("TextLabel", "⚠️ Selection Active")
    h_use_sel = GUI_AddControl("Check", "Pan Selection Only", 1)
    GUI_AddControl("Line")
end

GUI_AddControl("TextLabel", "💡 Single Frame Mode")
h_pan_x = GUI_AddControl("Scroller", "Pan X", 0, -500, 500)
h_pan_y = GUI_AddControl("Scroller", "Pan Y", 0, -500, 500)
h_wrap = GUI_AddControl("Check", "Wrap Around", 0)

GUI_AddControl("Line")
h_animate = GUI_AddControl("Check", "Keyframe Animation Mode", 0)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "═══ X Keyframes ═══")
h_start_frame_x = GUI_AddControl("Number", "Start Frame", 0)
h_start_x = GUI_AddControl("Number", "Start X (px)", 0)
h_mid_frame_x = GUI_AddControl("Number", "Middle Frame", 15)
h_mid_x = GUI_AddControl("Number", "Middle X (px)", 250)
h_end_frame_x = GUI_AddControl("Number", "End Frame", 30)
h_end_x = GUI_AddControl("Number", "End X (px)", 0)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "═══ Y Keyframes ═══")
h_start_y = GUI_AddControl("Number", "Start Y (px)", 0)
h_mid_y = GUI_AddControl("Number", "Middle Y (px)", 0)
h_end_y = GUI_AddControl("Number", "End Y (px)", 0)

GUI_OpenPanel()

local use_selection = has_selection and 1 or 0
local pan_x = 0
local pan_y = 0
local wrap = 0
local animate = 0

local start_frame_x = 0
local start_x = 0
local mid_frame_x = 15
local mid_x = 250
local end_frame_x = 30
local end_x = 0

local start_y = 0
local mid_y = 0
local end_y = 0

local canvas_r, canvas_g, canvas_b, x0, x1, y0, y1

repeat
    idx, retval, retstr = GUI_WaitOnEvent()
    
    if has_selection and idx == h_use_sel then
        use_selection = GUI_GetSettings(h_use_sel)
        canvas_r, canvas_g, canvas_b, x0, x1, y0, y1 = store_canvas(use_selection == 1)
    elseif idx == h_pan_x then
        pan_x = GUI_GetSettings(h_pan_x)
    elseif idx == h_pan_y then
        pan_y = GUI_GetSettings(h_pan_y)
    elseif idx == h_wrap then
        wrap = GUI_GetSettings(h_wrap)
    elseif idx == h_animate then
        animate = GUI_GetSettings(h_animate)
    elseif idx == h_start_frame_x then
        start_frame_x = GUI_GetSettings(h_start_frame_x)
    elseif idx == h_start_x then
        start_x = GUI_GetSettings(h_start_x)
    elseif idx == h_mid_frame_x then
        mid_frame_x = GUI_GetSettings(h_mid_frame_x)
    elseif idx == h_mid_x then
        mid_x = GUI_GetSettings(h_mid_x)
    elseif idx == h_end_frame_x then
        end_frame_x = GUI_GetSettings(h_end_frame_x)
    elseif idx == h_end_x then
        end_x = GUI_GetSettings(h_end_x)
    elseif idx == h_start_y then
        start_y = GUI_GetSettings(h_start_y)
    elseif idx == h_mid_y then
        mid_y = GUI_GetSettings(h_mid_y)
    elseif idx == h_end_y then
        end_y = GUI_GetSettings(h_end_y)
    end
    
    if idx > 0 and idx ~= h_animate and animate == 0 then
        if not canvas_r then
            canvas_r, canvas_g, canvas_b, x0, x1, y0, y1 = store_canvas(use_selection == 1)
        end
        
        pan_canvas(pan_x, pan_y, wrap == 1, canvas_r, canvas_g, canvas_b, x0, x1, y0, y1)
    end
    
until idx < 0

GUI_ClosePanel()

if idx == -1 then
    if animate == 1 then
        local total_frames = Dog_GetTotalFrames()
        
        if total_frames <= 0 then
            Dog_MessageBox("Create Animation First")
            Dog_RestoreUndo()
            Dog_GetBuffer()
            Dog_Refresh()
        else
            Dog_RestoreUndo()
            Dog_GetBuffer()
            
            Dog_MessageBox("Keyframe Animation", 
                          "Animating pan with custom keyframes...")
            
            Dog_GotoFrame(0)
            
            for frame = 0, total_frames - 1 do
                Dog_GotoFrame(frame)
                
                local frame_x = interpolate_keyframes(frame,
                    start_frame_x, start_x,
                    mid_frame_x, mid_x,
                    end_frame_x, end_x)
                
                local frame_y = interpolate_keyframes(frame,
                    start_frame_x, start_y,
                    mid_frame_x, mid_y,
                    end_frame_x, end_y)
                
                local fr, fg, fb, fx0, fx1, fy0, fy1 = store_canvas(use_selection == 1)
                pan_canvas(math.floor(frame_x), math.floor(frame_y), wrap == 1, fr, fg, fb, fx0, fx1, fy0, fy1)
            end
            
            Dog_GotoFrame(0)
            Dog_MessageBox("Keyframe Complete!")
        end
    else
        Dog_MessageBox("Pan Applied!", 
                      "X: " .. pan_x .. " Y: " .. pan_y)
    end
elseif idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
