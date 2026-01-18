-- Flip_CL v2 - Keyframe Timing
-- Specify frame numbers for flip timing
-- Perfect for reveal effects and transitions

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

GUI_SetCaption("Flip CL v2 - Keyframe Timing")

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
h_animate = GUI_AddControl("Check", "Keyframe Timing Mode", 0)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "═══ Flip Timing ═══")
GUI_AddControl("TextLabel", "💡 Flip occurs AT these frames")

h_flip1_frame = GUI_AddControl("Number", "First Flip Frame", 15)
h_flip1_enable = GUI_AddControl("Check", "Enable First Flip", 1)

GUI_AddControl("TextLabel", "")
h_flip2_frame = GUI_AddControl("Number", "Second Flip Frame", 30)
h_flip2_enable = GUI_AddControl("Check", "Enable Second Flip", 0)

GUI_AddControl("TextLabel", "")
h_flip3_frame = GUI_AddControl("Number", "Third Flip Frame", 45)
h_flip3_enable = GUI_AddControl("Check", "Enable Third Flip", 0)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "💡 Example: Flip at 15, 30 = flip-flop")

GUI_OpenPanel()

local use_selection = has_selection and 1 or 0
local mode = 1
local animate = 0

local flip1_frame = 15
local flip1_enable = 1
local flip2_frame = 30
local flip2_enable = 0
local flip3_frame = 45
local flip3_enable = 0

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
    elseif idx == h_flip1_frame then
        flip1_frame = GUI_GetSettings(h_flip1_frame)
    elseif idx == h_flip1_enable then
        flip1_enable = GUI_GetSettings(h_flip1_enable)
    elseif idx == h_flip2_frame then
        flip2_frame = GUI_GetSettings(h_flip2_frame)
    elseif idx == h_flip2_enable then
        flip2_enable = GUI_GetSettings(h_flip2_enable)
    elseif idx == h_flip3_frame then
        flip3_frame = GUI_GetSettings(h_flip3_frame)
    elseif idx == h_flip3_enable then
        flip3_enable = GUI_GetSettings(h_flip3_enable)
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
            local flip_points = {}
            if flip1_enable == 1 then
                table.insert(flip_points, flip1_frame)
            end
            if flip2_enable == 1 then
                table.insert(flip_points, flip2_frame)
            end
            if flip3_enable == 1 then
                table.insert(flip_points, flip3_frame)
            end
            
            if #flip_points == 0 then
                Dog_MessageBox("No Flip Points Enabled", 
                              "Enable at least one flip point!")
                Dog_RestoreUndo()
                Dog_GetBuffer()
                Dog_Refresh()
            else
                table.sort(flip_points)
                
                local flip_msg = "Flips at: "
                for i, frame in ipairs(flip_points) do
                    flip_msg = flip_msg .. frame
                    if i < #flip_points then
                        flip_msg = flip_msg .. ", "
                    end
                end
                
                Dog_MessageBox("Keyframe Timing", flip_msg)
                
                Dog_GotoFrame(0)
                
                local flip_count = 0
                
                for frame = 0, total_frames - 1 do
                    Dog_GotoFrame(frame)
                    
                    for _, flip_frame in ipairs(flip_points) do
                        if frame >= flip_frame and flip_count < #flip_points then
                            if frame == flip_frame or (flip_count == 0 and frame == 0) then
                                flip_canvas(mode, use_selection == 1)
                                flip_count = flip_count + 1
                                break
                            end
                        end
                    end
                end
                
                Dog_GotoFrame(0)
                Dog_MessageBox("Flip Timing Complete!", 
                              "Applied " .. flip_count .. " flip" .. (flip_count > 1 and "s" or ""))
            end
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
