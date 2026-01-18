function main()
    print("=== Dog Receive Animation from ComfyUI ===")
    
    if width == nil or height == nil then
        if Dog_MessageBox then
            Dog_MessageBox("Error: No canvas available!")
        end
        return
    end
    
    if Dog_GetTotalFrames == nil or Dog_GetTotalFrames() <= 0 then
        if Dog_MessageBox then
            Dog_MessageBox("Error: No animation timeline!\n\nPlease create an animation first.")
        end
        return
    end
    
    local base_path = "B:\\PD HOWLER\\DOGEXCHANGE\\Dog_recieve\\Dog_rec_anim_buffer\\"
    
    local frame_count = 0
    local test_path = base_path .. string.format("result_%04d.json", frame_count)
    local test_file = io.open(test_path, "r")
    
    while test_file do
        test_file:close()
        frame_count = frame_count + 1
        test_path = base_path .. string.format("result_%04d.json", frame_count)
        test_file = io.open(test_path, "r")
    end
    
    if frame_count == 0 then
        print("No result frames found!")
        if Dog_MessageBox then
            Dog_MessageBox("No Results Found!\n\n" ..
                          "Looking for: result_0000.json, result_0001.json...\n" ..
                          "in Dog_rec_anim_buffer folder\n\n" ..
                          "Make sure ComfyUI has output the frames!")
        end
        return
    end
    
    print("Found " .. frame_count .. " result frames")
    
    local timeline_frames = Dog_GetTotalFrames()
    
    if frame_count ~= timeline_frames then
        if Dog_MessageBox then
            Dog_MessageBox("Frame Count Mismatch!\n\n" ..
                          "Found: " .. frame_count .. " result frames\n" ..
                          "Timeline: " .. timeline_frames .. " frames\n\n" ..
                          "Continuing with available frames...")
        end
    end
    
    if Dog_SaveUndo then
        Dog_SaveUndo()
    end
    
    local current_frame = Dog_GetCurrentFrame and Dog_GetCurrentFrame() or 0
    local max_frames = math.min(frame_count, timeline_frames)
    
    for frame = 0, max_frames - 1 do
        if Dog_CheckQuit and Dog_CheckQuit() then
            print("Import cancelled by user")
            if Dog_MessageBox then
                Dog_MessageBox("Import cancelled!")
            end
            if Dog_GotoFrame then
                Dog_GotoFrame(current_frame)
            end
            return
        end
        
        if Dog_GotoFrame then
            Dog_GotoFrame(frame)
        end
        
        local frame_filename = string.format("result_%04d.json", frame)
        local frame_path = base_path .. frame_filename
        
        local file = io.open(frame_path, "r")
        if not file then
            print("WARNING: Cannot read " .. frame_filename)
            goto continue
        end
        
        local content = file:read("*all")
        file:close()
        
        local result_width = content:match('"width"%s*:%s*(%d+)')
        local result_height = content:match('"height"%s*:%s*(%d+)')
        
        if not result_width or not result_height then
            print("ERROR: Invalid JSON in frame " .. frame)
            goto continue
        end
        
        result_width = tonumber(result_width)
        result_height = tonumber(result_height)
        
        local pixels_section = content:match('"pixels"%s*:%s*%[(.-)%]')
        
        if not pixels_section then
            print("ERROR: No pixel data in frame " .. frame)
            goto continue
        end
        
        local pixel_index = 0
        local imported_pixels = 0
        
        for r, g, b in content:gmatch("%[%s*([%d%.eE%-%+]+)%s*,%s*([%d%.eE%-%+]+)%s*,%s*([%d%.eE%-%+]+)%s*%]") do
            local y = math.floor(pixel_index / result_width)
            local x = pixel_index % result_width
            
            if x < width and y < height then
                local r_val = tonumber(r)
                local g_val = tonumber(g)
                local b_val = tonumber(b)
                
                if r_val and g_val and b_val then
                    set_rgb(x, y, r_val, g_val, b_val)
                    imported_pixels = imported_pixels + 1
                end
            end
            
            pixel_index = pixel_index + 1
        end
        
        print("Frame " .. frame .. " imported: " .. imported_pixels .. " pixels")
        
        local frame_progress = frame / max_frames
        if progress then
            progress(frame_progress)
        end
        
        ::continue::
    end
    
    if Dog_GotoFrame then
        Dog_GotoFrame(current_frame)
    end
    
    if Dog_Refresh then
        Dog_Refresh()
    end
    
    if progress then
        progress(0)
    end
    
    print("Animation import complete! " .. max_frames .. " frames imported.")
    
    if Dog_MessageBox then
        Dog_MessageBox("Animation Received from ComfyUI!\n\n" ..
                      "Imported: " .. max_frames .. " frames\n" ..
                      "Resolution: " .. width .. "x" .. height .. "\n\n" ..
                      "Animation updated!")
    end
end

main()
