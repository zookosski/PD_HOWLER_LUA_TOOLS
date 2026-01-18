function main()
    print("=== Dog Receive Canvas from ComfyUI ===")
    
    if width == nil or height == nil then
        if Dog_MessageBox then
            Dog_MessageBox("Error: No canvas available!")
        end
        return
    end
    
    local import_path = "B:\\PD HOWLER\\DOGEXCHANGE\\Dog_recieve\\Dog_rec_canvas\\result_canvas.json"
    
    local file = io.open(import_path, "r")
    if not file then
        print("No result file found at: " .. import_path)
        if Dog_MessageBox then
            Dog_MessageBox("No Result Found!\n\n" ..
                          "Looking for: result_canvas.json\n" ..
                          "in Dog_rec_canvas folder\n\n" ..
                          "Make sure ComfyUI has output the result!")
        end
        return
    end
    
    print("Reading result from: " .. import_path)
    
    local content = file:read("*all")
    file:close()
    
    local result_width = content:match('"width"%s*:%s*(%d+)')
    local result_height = content:match('"height"%s*:%s*(%d+)')
    
    if not result_width or not result_height then
        print("ERROR: Invalid JSON format!")
        if Dog_MessageBox then
            Dog_MessageBox("Error: Invalid result file format!")
        end
        return
    end
    
    result_width = tonumber(result_width)
    result_height = tonumber(result_height)
    
    print("Result dimensions: " .. result_width .. "x" .. result_height)
    print("Canvas dimensions: " .. width .. "x" .. height)
    
    if result_width ~= width or result_height ~= height then
        if Dog_MessageBox then
            local response = Dog_MessageBox("Size Mismatch!\n\n" ..
                                           "Result: " .. result_width .. "x" .. result_height .. "\n" ..
                                           "Canvas: " .. width .. "x" .. height .. "\n\n" ..
                                           "Continue anyway?\n" ..
                                           "(Will crop/pad as needed)")
        end
    end
    
    if Dog_SaveUndo then
        Dog_SaveUndo()
    end
    
    print("Parsing pixel data from JSON...")
    print("File content length: " .. string.len(content) .. " bytes")
    
    local pixel_index = 0
    local imported_pixels = 0
    local parse_errors = 0
    
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
            else
                parse_errors = parse_errors + 1
                if parse_errors < 10 then
                    print("Parse error at pixel " .. pixel_index .. ": r=" .. r .. ", g=" .. g .. ", b=" .. b)
                end
            end
        end
        
        pixel_index = pixel_index + 1
        
        if pixel_index % 10000 == 0 then
            local progress_pct = math.floor((pixel_index / (result_width * result_height)) * 100)
            print("Import progress: " .. progress_pct .. "% (" .. imported_pixels .. " pixels)")
            if progress then
                progress(pixel_index / (result_width * result_height))
            end
        end
    end
    
    print("Parsing complete!")
    print("Total pixels found: " .. pixel_index)
    print("Pixels imported: " .. imported_pixels)
    print("Parse errors: " .. parse_errors)
    print("Expected pixels: " .. (result_width * result_height))
    
    if pixel_index == 0 then
        print("ERROR: No pixels matched the pattern!")
        print("Sample of file content:")
        print(string.sub(content, 1, 1000))
    end
    
    if progress then
        progress(0)
    end
    
    if Dog_Refresh then
        Dog_Refresh()
    end
    
    print("Canvas import complete! " .. imported_pixels .. " pixels imported.")
    
    if Dog_MessageBox then
        Dog_MessageBox("Canvas Received from ComfyUI!\n\n" ..
                      "Imported: " .. imported_pixels .. " pixels\n" ..
                      "Resolution: " .. result_width .. "x" .. result_height .. "\n\n" ..
                      "Canvas updated!")
    end
end

main()
