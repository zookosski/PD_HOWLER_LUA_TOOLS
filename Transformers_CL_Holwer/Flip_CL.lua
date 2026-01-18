-- Flip_CL - Instant Canvas Flip
-- Focused tool - does ONE thing perfectly
-- Horizontal and Vertical flipping

function flip_canvas(flip_mode, use_selection)
    local x0 = use_selection and bound_x0 or 0
    local x1 = use_selection and bound_x1 or (width - 1)
    local y0 = use_selection and bound_y0 or 0
    local y1 = use_selection and bound_y1 or (height - 1)
    
    local src_w = x1 - x0 + 1
    local src_h = y1 - y0 + 1
    
    local r_data = {}
    local g_data = {}
    local b_data = {}
    
    for y = y0, y1 do
        for x = x0, x1 do
            local r, g, b = get_rgb(x, y)
            table.insert(r_data, r)
            table.insert(g_data, g)
            table.insert(b_data, b)
        end
    end
    
    for y = 0, src_h - 1 do
        for x = 0, src_w - 1 do
            local src_x = x
            local src_y = y
            
            if flip_mode == 1 then
                src_x = src_w - 1 - x
            else
                src_y = src_h - 1 - y
            end
            
            local r = r_data[src_y * src_w + src_x + 1]
            local g = g_data[src_y * src_w + src_x + 1]
            local b = b_data[src_y * src_w + src_x + 1]
            
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

GUI_SetCaption("Flip CL - Instant Flip")

if has_selection then
    GUI_AddControl("TextLabel", "⚠️ Selection Active")
    h_use_sel = GUI_AddControl("Check", "Flip Selection Only", 1)
    GUI_AddControl("Line")
end

GUI_AddControl("TextLabel", "═══ Flip Direction ═══")
h_mode = GUI_AddControl("Combobox", "Flip Type")
GUI_SetList(h_mode, 0, "Horizontal")
GUI_SetList(h_mode, 1, "Vertical")
GUI_SetSettings(h_mode, 0, "Horizontal")

GUI_AddControl("Line")
h_animate = GUI_AddControl("Check", "Animate (flip at midpoint)", 0)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "💡 Click OK to flip instantly")

GUI_OpenPanel()

local use_selection = has_selection and 1 or 0
local mode = 1
local animate = 0

repeat
    idx, retval, retstr = GUI_WaitOnEvent()
    
    if has_selection and idx == h_use_sel then
        use_selection = GUI_GetSettings(h_use_sel)
    elseif idx == h_mode then
        local dummy, mode_str = GUI_GetSettings(h_mode)
        if mode_str:find("Horizontal") then
            mode = 1
        else
            mode = 2
        end
    elseif idx == h_animate then
        animate = GUI_GetSettings(h_animate)
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
            Dog_MessageBox("Animating Flip", 
                          "Flip occurs at frame " .. math.floor(total_frames / 2))
            
            Dog_GotoFrame(0)
            
            local flip_frame = math.floor(total_frames / 2)
            
            for frame = 0, total_frames - 1 do
                Dog_GotoFrame(frame)
                
                if frame >= flip_frame then
                    flip_canvas(mode, use_selection == 1)
                end
            end
            
            Dog_GotoFrame(0)
            Dog_MessageBox("Flip Complete!", 
                          "Flipped at frame " .. flip_frame)
        end
    else
        flip_canvas(mode, use_selection == 1)
        
        local flip_type = (mode == 1) and "Horizontal" or "Vertical"
        Dog_MessageBox("Flip Applied!", 
                      "Type: " .. flip_type)
    end
elseif idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
