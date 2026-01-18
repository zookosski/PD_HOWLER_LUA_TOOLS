-- Pan_CL - Smooth Canvas Panning
-- Focused tool - does ONE thing perfectly
-- Real-time preview with wrap mode option

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

Dog_SaveUndo()

local has_selection = (bound_x1 - bound_x0) < (width - 1) or (bound_y1 - bound_y0) < (height - 1)

GUI_SetCaption("Pan CL - Live Preview")

if has_selection then
    GUI_AddControl("TextLabel", "⚠️ Selection Active")
    h_use_sel = GUI_AddControl("Check", "Pan Selection Only", 1)
    GUI_AddControl("Line")
end

GUI_AddControl("TextLabel", "💡 Drag sliders for live preview")
GUI_AddControl("Line")

h_pan_x = GUI_AddControl("Scroller", "Pan X (pixels)", 0, -500, 500)
h_pan_y = GUI_AddControl("Scroller", "Pan Y (pixels)", 0, -500, 500)

GUI_AddControl("Line")
h_wrap = GUI_AddControl("Check", "Wrap Around (seamless)", 0)

GUI_AddControl("Line")
h_animate = GUI_AddControl("Check", "Animate Pan", 0)

GUI_OpenPanel()

local use_selection = has_selection and 1 or 0
local pan_x = 0
local pan_y = 0
local wrap = 0
local animate = 0

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
    end
    
    if idx > 0 and idx ~= h_animate then
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
            
            Dog_MessageBox("Animating Pan", 
                          "Processing " .. total_frames .. " frames...")
            
            Dog_GotoFrame(0)
            
            for frame = 0, total_frames - 1 do
                Dog_GotoFrame(frame)
                
                local t = frame / (total_frames - 1)
                local frame_pan_x = math.floor(pan_x * t)
                local frame_pan_y = math.floor(pan_y * t)
                
                local fr, fg, fb, fx0, fx1, fy0, fy1 = store_canvas(use_selection == 1)
                pan_canvas(frame_pan_x, frame_pan_y, wrap == 1, fr, fg, fb, fx0, fx1, fy0, fy1)
            end
            
            Dog_GotoFrame(0)
            Dog_MessageBox("Pan Complete!")
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
