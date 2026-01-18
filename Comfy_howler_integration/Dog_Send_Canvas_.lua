function main()
    print("=== Dog Send Canvas to ComfyUI ===")
    
    if width == nil or height == nil then
        if Dog_MessageBox then
            Dog_MessageBox("Error: No canvas available!")
        end
        return
    end
    
    local export_path = "B:\\PD HOWLER\\DOGEXCHANGE\\Dog_send\\Dog_send_canvas\\canvas_data.json"
    
    print("Canvas size: " .. width .. "x" .. height)
    print("Exporting to: " .. export_path)
    
    local file = io.open(export_path, "w")
    if not file then
        print("ERROR: Cannot create export file!")
        if Dog_MessageBox then
            Dog_MessageBox("Error: Cannot write to DOGEXCHANGE folder!")
        end
        return
    end
    
    file:write('{"width":' .. width .. ',')
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
        
        if y % 50 == 0 and y > 0 then
            local progress_pct = math.floor((y / height) * 100)
            print("Export progress: " .. progress_pct .. "%")
            if progress then
                progress(y / height)
            end
        end
    end
    
    file:write(']}')
    file:close()
    
    if progress then
        progress(0)
    end
    
    print("Canvas export complete! " .. exported_pixels .. " pixels exported.")
    
    if Dog_MessageBox then
        Dog_MessageBox("Canvas Sent to ComfyUI!\n\n" ..
                      "Exported: " .. width .. "x" .. height .. "\n" ..
                      "Pixels: " .. exported_pixels .. "\n\n" ..
                      "Location: Dog_send_canvas/canvas_data.json\n\n" ..
                      "Now switch to ComfyUI and process!")
    end
end

main()
