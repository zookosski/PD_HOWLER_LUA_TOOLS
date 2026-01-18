-- Rotate_CL v2 - Keyframe Animation
-- Start → Middle (Peak) → End frame control
-- Professional motion graphics workflow

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

function sample_bilinear(data, w, h, x, y)
    if x < 0 or x >= w or y < 0 or y >= h then
        return 0
    end
    
    local x0 = math.floor(x)
    local y0 = math.floor(y)
    local x1 = math.min(x0 + 1, w - 1)
    local y1 = math.min(y0 + 1, h - 1)
    
    local fx = x - x0
    local fy = y - y0
    
    local v00 = data[y0 * w + x0 + 1] or 0
    local v10 = data[y0 * w + x1 + 1] or 0
    local v01 = data[y1 * w + x0 + 1] or 0
    local v11 = data[y1 * w + x1 + 1] or 0
    
    local v0 = v00 * (1 - fx) + v10 * fx
    local v1 = v01 * (1 - fx) + v11 * fx
    
    return v0 * (1 - fy) + v1 * fy
end

function rotate_canvas(angle_deg, canvas_r, canvas_g, canvas_b, x0, x1, y0, y1)
    local src_w = x1 - x0 + 1
    local src_h = y1 - y0 + 1
    local cx = src_w / 2
    local cy = src_h / 2
    
    local angle = math.rad(angle_deg)
    local cos_a = math.cos(-angle)
    local sin_a = math.sin(-angle)
    
    for y = 0, src_h - 1 do
        for x = 0, src_w - 1 do
            local dx = x - cx
            local dy = y - cy
            
            local src_x = dx * cos_a - dy * sin_a + cx
            local src_y = dx * sin_a + dy * cos_a + cy
            
            local r = sample_bilinear(canvas_r, src_w, src_h, src_x, src_y)
            local g = sample_bilinear(canvas_g, src_w, src_h, src_x, src_y)
            local b = sample_bilinear(canvas_b, src_w, src_h, src_x, src_y)
            
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

GUI_SetCaption("Rotate CL v2 - Keyframe Animation")

if has_selection then
    GUI_AddControl("TextLabel", "⚠️ Selection Active")
    h_use_sel = GUI_AddControl("Check", "Rotate Selection Only", 1)
    GUI_AddControl("Line")
end

GUI_AddControl("TextLabel", "💡 Single Frame Mode")
h_angle = GUI_AddControl("Scroller", "Quick Adjust", 0, -180, 180)
h_angle_manual = GUI_AddControl("Number", "Precise Angle (°)", 0)

GUI_AddControl("Line")
h_animate = GUI_AddControl("Check", "Keyframe Animation Mode", 0)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "═══ Keyframe Animation ═══")
GUI_AddControl("TextLabel", "💡 Start → Peak → End")

h_start_frame = GUI_AddControl("Number", "Start Frame", 0)
h_start_angle = GUI_AddControl("Number", "Start Angle (°)", 0)

GUI_AddControl("TextLabel", "")
h_mid_frame = GUI_AddControl("Number", "Middle Frame (Peak)", 15)
h_mid_angle = GUI_AddControl("Number", "Middle Angle (°)", 180)

GUI_AddControl("TextLabel", "")
h_end_frame = GUI_AddControl("Number", "End Frame", 30)
h_end_angle = GUI_AddControl("Number", "End Angle (°)", 0)

GUI_OpenPanel()

local use_selection = has_selection and 1 or 0
local angle = 0
local animate = 0

local start_frame = 0
local start_angle = 0
local mid_frame = 15
local mid_angle = 180
local end_frame = 30
local end_angle = 0

local canvas_r, canvas_g, canvas_b, x0, x1, y0, y1

repeat
    idx, retval, retstr = GUI_WaitOnEvent()
    
    if has_selection and idx == h_use_sel then
        use_selection = GUI_GetSettings(h_use_sel)
        canvas_r, canvas_g, canvas_b, x0, x1, y0, y1 = store_canvas(use_selection == 1)
    elseif idx == h_angle then
        angle = GUI_GetSettings(h_angle)
        GUI_SetSettings(h_angle_manual, angle)
    elseif idx == h_angle_manual then
        angle = GUI_GetSettings(h_angle_manual)
        if angle >= -180 and angle <= 180 then
            GUI_SetSettings(h_angle, angle)
        end
    elseif idx == h_animate then
        animate = GUI_GetSettings(h_animate)
    elseif idx == h_start_frame then
        start_frame = GUI_GetSettings(h_start_frame)
    elseif idx == h_start_angle then
        start_angle = GUI_GetSettings(h_start_angle)
    elseif idx == h_mid_frame then
        mid_frame = GUI_GetSettings(h_mid_frame)
    elseif idx == h_mid_angle then
        mid_angle = GUI_GetSettings(h_mid_angle)
    elseif idx == h_end_frame then
        end_frame = GUI_GetSettings(h_end_frame)
    elseif idx == h_end_angle then
        end_angle = GUI_GetSettings(h_end_angle)
    end
    
    if idx > 0 and idx ~= h_animate and animate == 0 then
        if not canvas_r then
            canvas_r, canvas_g, canvas_b, x0, x1, y0, y1 = store_canvas(use_selection == 1)
        end
        
        rotate_canvas(angle, canvas_r, canvas_g, canvas_b, x0, x1, y0, y1)
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
                          "Start: Frame " .. start_frame .. " = " .. start_angle .. "°",
                          "Peak: Frame " .. mid_frame .. " = " .. mid_angle .. "°",
                          "End: Frame " .. end_frame .. " = " .. end_angle .. "°")
            
            Dog_GotoFrame(0)
            
            for frame = 0, total_frames - 1 do
                Dog_GotoFrame(frame)
                
                local frame_angle = interpolate_keyframes(frame, 
                    start_frame, start_angle,
                    mid_frame, mid_angle,
                    end_frame, end_angle)
                
                local fr, fg, fb, fx0, fx1, fy0, fy1 = store_canvas(use_selection == 1)
                rotate_canvas(frame_angle, fr, fg, fb, fx0, fx1, fy0, fy1)
            end
            
            Dog_GotoFrame(0)
            Dog_MessageBox("Keyframe Complete!")
        end
    else
        Dog_MessageBox("Rotation Applied!", 
                      "Angle: " .. angle .. "°")
    end
elseif idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
