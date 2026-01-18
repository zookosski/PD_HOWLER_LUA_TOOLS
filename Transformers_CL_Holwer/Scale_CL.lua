-- Scale_CL - Smooth Canvas Scaling
-- Focused tool - does ONE thing perfectly
-- Real-time preview with bilinear interpolation

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

function scale_canvas(scale_pct, canvas_r, canvas_g, canvas_b, x0, x1, y0, y1)
    local src_w = x1 - x0 + 1
    local src_h = y1 - y0 + 1
    local scale = scale_pct / 100
    
    local cx = src_w / 2
    local cy = src_h / 2
    
    for y = 0, src_h - 1 do
        for x = 0, src_w - 1 do
            local dx = x - cx
            local dy = y - cy
            
            local src_x = (dx / scale) + cx
            local src_y = (dy / scale) + cy
            
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

Dog_SaveUndo()

local has_selection = (bound_x1 - bound_x0) < (width - 1) or (bound_y1 - bound_y0) < (height - 1)

GUI_SetCaption("Scale CL - From Center")

if has_selection then
    GUI_AddControl("TextLabel", "⚠️ Selection Active")
    h_use_sel = GUI_AddControl("Check", "Scale Selection Only", 1)
    GUI_AddControl("Line")
end

GUI_AddControl("TextLabel", "💡 Scaling happens from CENTER")
GUI_AddControl("TextLabel", "200% = zoom out from center equally")
GUI_AddControl("Line")

h_scale = GUI_AddControl("Scroller", "Quick Adjust", 100, 10, 500)
h_scale_manual = GUI_AddControl("Number", "Precise Scale (%)", 100)
GUI_AddControl("TextLabel", "💡 For animation: smooth zoom effect")

GUI_AddControl("Line")
h_animate = GUI_AddControl("Check", "Animate Scale", 0)

GUI_OpenPanel()

local use_selection = has_selection and 1 or 0
local scale = 100
local animate = 0

local canvas_r, canvas_g, canvas_b, x0, x1, y0, y1

repeat
    idx, retval, retstr = GUI_WaitOnEvent()
    
    if has_selection and idx == h_use_sel then
        use_selection = GUI_GetSettings(h_use_sel)
        canvas_r, canvas_g, canvas_b, x0, x1, y0, y1 = store_canvas(use_selection == 1)
    elseif idx == h_scale then
        scale = GUI_GetSettings(h_scale)
        GUI_SetSettings(h_scale_manual, scale)
    elseif idx == h_scale_manual then
        scale = GUI_GetSettings(h_scale_manual)
        if scale >= 10 and scale <= 500 then
            GUI_SetSettings(h_scale, scale)
        end
    elseif idx == h_animate then
        animate = GUI_GetSettings(h_animate)
    end
    
    if idx > 0 and idx ~= h_animate then
        if not canvas_r then
            canvas_r, canvas_g, canvas_b, x0, x1, y0, y1 = store_canvas(use_selection == 1)
        end
        
        scale_canvas(scale, canvas_r, canvas_g, canvas_b, x0, x1, y0, y1)
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
            
            Dog_MessageBox("Animating Scale", 
                          "Processing " .. total_frames .. " frames...")
            
            Dog_GotoFrame(0)
            
            for frame = 0, total_frames - 1 do
                Dog_GotoFrame(frame)
                
                local t = frame / (total_frames - 1)
                local frame_scale = 100 + (scale - 100) * t
                
                local fr, fg, fb, fx0, fx1, fy0, fy1 = store_canvas(use_selection == 1)
                scale_canvas(frame_scale, fr, fg, fb, fx0, fx1, fy0, fy1)
            end
            
            Dog_GotoFrame(0)
            Dog_MessageBox("Scale Complete!")
        end
    else
        Dog_MessageBox("Scale Applied!", 
                      "Scale: " .. scale .. "%")
    end
elseif idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
