function main()
    print("=== Dog Send Animation to ComfyUI ===")
    
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
    
    local total_frames = Dog_GetTotalFrames()
    local base_path = "B:\\PD HOWLER\\DOGEXCHANGE\\Dog_send\\Dog_send_anim_buffer\\"
    
    print("Animation: " .. total_frames .. " frames at " .. width .. "x" .. height)
    
    if Dog_SaveUndo then
        Dog_SaveUndo()
    end
    
    local current_frame = Dog_GetCurrentFrame and Dog_GetCurrentFrame() or 0
    
    for frame = 0, total_frames - 1 do
        if Dog_CheckQuit and Dog_CheckQuit() then
            print("Export cancelled by user")
            if Dog_MessageBox then
                Dog_MessageBox("Export cancelled!")
            end
            if Dog_GotoFrame then
                Dog_GotoFrame(current_frame)
            end
            return
        end
        
        if Dog_GotoFrame then
            Dog_GotoFrame(frame)
        end
        
        local frame_filename = string.format("frame_%04d.json", frame)
        local frame_path = base_path .. frame_filename
        
        local file = io.open(frame_path, "w")
        if not file then
            print("ERROR: Cannot create file: " .. frame_filename)
            if Dog_MessageBox then
                Dog_MessageBox("Error: Cannot write frame " .. frame .. "!")
            end
            return
        end
        
        file:write('{"frame":' .. frame .. ',')
        file:write('"width":' .. width .. ',')
        file:write('"height":' .. height .. ',')
        file:write('"format":"rgb_normalized",')
        file:write('"pixels":[')
        
        local exported_pixels = 0
        local total_pixels = width * height
        
        for y = 0, height - 1 do
            for x = 0, width - 1 do
                local r, g, b = get_rgb(x, y)
                
                if r and g and b then
                    file:write('[' .. r .. ',' .. g .. ',' .. b .. ']')
                    exported_pixels = exported_pixels + 1
                else
                    file:write('[0.0,0.0,0.0]')
                end
                
                if exported_pixels < total_pixels then
                    file:write(',')
                end
            end
        end
        
        file:write(']}')
        file:close()
        
        local frame_progress = frame / total_frames
        print("Frame " .. frame .. "/" .. (total_frames - 1) .. " exported (" .. 
              math.floor(frame_progress * 100) .. "%)")
        
        if progress then
            progress(frame_progress)
        end
    end
    
    if Dog_GotoFrame then
        Dog_GotoFrame(current_frame)
    end
    
    if progress then
        progress(0)
    end
    
    print("Animation export complete! " .. total_frames .. " frames exported.")
    
    if Dog_MessageBox then
        Dog_MessageBox("Animation Sent to ComfyUI!\n\n" ..
                      "Frames: " .. total_frames .. "\n" ..
                      "Resolution: " .. width .. "x" .. height .. "\n\n" ..
                      "Location: Dog_send_anim_buffer/\n\n" ..
                      "Now switch to ComfyUI and process!")
    end
end

main()
