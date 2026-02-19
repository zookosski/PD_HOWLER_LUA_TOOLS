-- PD Howler Seamless Canvas Looper - Pure Lua Slice Method
-- Simple approach: Canvas width ÷ Total frames = Slice width
-- Each frame rotates the slice order for perfect seamless loop

-- Check basic requirements
if width == nil or height == nil then
    Dog_MessageBox("Error: No image loaded. Please load an image first.")
    return
end

if width <= 0 or height <= 0 then
    Dog_MessageBox("Error: Invalid image dimensions.")
    return
end

-- Check animation timeline
local total_frames = Dog_GetTotalFrames()
if total_frames < 2 then
    Dog_MessageBox("Please create an animation timeline with at least 2 frames before running this script.")
    return
end

-- Get pan direction
local result = Dog_ValueBox("Pan Direction", "0 = Left to Right, 1 = Right to Left:", 0, 1, 1)
if result == nil or result == -1 then return end
local pan_direction = result

-- Calculate slice width automatically
local slice_width = math.floor(width / total_frames)

-- Show what we're going to do
local direction_text = pan_direction == 1 and "Right to Left" or "Left to Right"
Dog_MessageBox("Creating seamless canvas loop with edge blending:\n" ..
               "Direction: " .. direction_text .. "\n" ..
               "Canvas: " .. width .. "x" .. height .. "\n" ..
               "Frames: " .. total_frames .. "\n" ..
               "Slice width: " .. slice_width .. " pixels\n" ..
               "Edge blur: 2 pixels for smooth transitions")

-- Save undo state
Dog_SaveUndo()

-- Store original image data (frame 0)
Dog_GotoFrame(0)

-- Create storage for original image slices with 2-pixel edge zones for blending
local original_slices = {}
local edge_blur = 2  -- 2 pixels on each side for soft blending

for slice_num = 0, total_frames - 1 do
    original_slices[slice_num] = {}
    local start_x = slice_num * slice_width
    
    -- Store this slice with extended edges for blending
    for y = 0, height - 1 do
        original_slices[slice_num][y] = {}
        
        -- Store slice plus edge zones (left edge, main slice, right edge)
        for x = -edge_blur, slice_width - 1 + edge_blur do
            local actual_x = start_x + x
            
            -- Handle wrapping at canvas edges for seamless blending
            if actual_x < 0 then
                actual_x = width + actual_x  -- Wrap from right edge
            elseif actual_x >= width then
                actual_x = actual_x - width  -- Wrap to left edge
            end
            
            local r, g, b = get_rgb(actual_x, y)
            original_slices[slice_num][y][x + edge_blur] = {r, g, b}  -- Offset index by edge_blur
        end
    end
    
    -- Progress feedback
    if progress then 
        progress((slice_num / total_frames) * 0.5) -- 50% for slicing
    end
end

-- Generate animation frames using slice rotation with edge blending
for frame_num = 0, total_frames - 1 do
    Dog_GotoFrame(frame_num)
    
    -- Clear the entire canvas
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            set_rgb(x, y, 0, 0, 0)
        end
    end
    
    -- Place rotated slices with edge blending
    for slice_position = 0, total_frames - 1 do
        local source_slice
        
        if pan_direction == 1 then
            -- Right to left: shift slices left
            source_slice = (slice_position + frame_num) % total_frames
        else
            -- Left to right: shift slices right  
            source_slice = (slice_position - frame_num + total_frames) % total_frames
        end
        
        -- Copy this slice to its position with edge blending
        local dest_x_start = slice_position * slice_width
        
        for y = 0, height - 1 do
            for x = 0, slice_width - 1 do
                local dest_x = dest_x_start + x
                if dest_x < width then
                    -- Main pixel from slice
                    local pixel = original_slices[source_slice][y][x + edge_blur]
                    local final_r, final_g, final_b = pixel[1], pixel[2], pixel[3]
                    
                    -- Apply edge blending for first 2 pixels (left edge)
                    if x < edge_blur then
                        local blend_factor = x / edge_blur  -- 0.0 to 1.0
                        local left_neighbor_slice = (source_slice - 1 + total_frames) % total_frames
                        local left_pixel = original_slices[left_neighbor_slice][y][slice_width - 1 + edge_blur]
                        
                        -- Blend with left neighbor
                        final_r = (1 - blend_factor) * left_pixel[1] + blend_factor * pixel[1]
                        final_g = (1 - blend_factor) * left_pixel[2] + blend_factor * pixel[2]
                        final_b = (1 - blend_factor) * left_pixel[3] + blend_factor * pixel[3]
                    end
                    
                    -- Apply edge blending for last 2 pixels (right edge)
                    if x >= slice_width - edge_blur then
                        local blend_factor = (slice_width - 1 - x) / edge_blur  -- 1.0 to 0.0
                        local right_neighbor_slice = (source_slice + 1) % total_frames
                        local right_pixel = original_slices[right_neighbor_slice][y][edge_blur]
                        
                        -- Blend with right neighbor
                        final_r = blend_factor * pixel[1] + (1 - blend_factor) * right_pixel[1]
                        final_g = blend_factor * pixel[2] + (1 - blend_factor) * right_pixel[2]
                        final_b = blend_factor * pixel[3] + (1 - blend_factor) * right_pixel[3]
                    end
                    
                    -- Clamp values to 0-1 range
                    final_r = math.max(0, math.min(1, final_r))
                    final_g = math.max(0, math.min(1, final_g))
                    final_b = math.max(0, math.min(1, final_b))
                    
                    set_rgb(dest_x, y, final_r, final_g, final_b)
                end
            end
        end
    end
    
    -- Refresh display to show progress
    Dog_Refresh()
    
    -- Progress feedback
    if progress then 
        progress(0.5 + ((frame_num / total_frames) * 0.5)) -- 50% for frame generation
    end
end

-- Complete - return to first frame
Dog_GotoFrame(0)
Dog_MessageBox("Seamless slice-based loop with edge blending complete!\n" ..
               "Created " .. total_frames .. " frames with " .. slice_width .. "-pixel slices.\n" ..
               "2-pixel edge blur zones eliminate hard seaming.\n" ..
               "Use playback controls to see the ultra-smooth seamless animation!")
