-- PD Howler Mandala Generator - 15 Degree Radial Mirror
-- Creates a 24-segment mandala from canvas content
-- NOW WITH BLACK BACKGROUND OPTION!

-- Check essential functions exist
if width == nil or height == nil or get_rgb == nil or set_rgb == nil then
    print("Error: Essential PD Howler functions not available")
    return
end

-- Get user parameters
local radius_percent = 80
local center_x_offset = 0
local center_y_offset = 0
local clear_outside = 1  -- NEW: 1=black outside, 0=keep original
local blend_mode = 1  -- 1=replace, 2=multiply, 3=screen, 4=overlay

if Dog_ValueBox then
    local result = Dog_ValueBox("Mandala Radius", "Radius % of canvas:", 10, 100, radius_percent)
    if result == nil then return end
    radius_percent = result
    
    result = Dog_ValueBox("Center X Offset", "X offset from center:", -200, 200, center_x_offset)
    if result == nil then return end
    center_x_offset = result
    
    result = Dog_ValueBox("Center Y Offset", "Y offset from center:", -200, 200, center_y_offset)
    if result == nil then return end
    center_y_offset = result
    
    -- NEW PARAMETER: Clear Outside
    result = Dog_ValueBox("Clear Outside", "1=Black outside 0=Keep original:", 0, 1, clear_outside)
    if result == nil then return end
    clear_outside = result
    
    result = Dog_ValueBox("Blend Mode", "1=Replace 2=Multiply 3=Screen:", 1, 3, blend_mode)
    if result == nil then return end
    blend_mode = result
end

-- Save undo state
if Dog_SaveUndo then Dog_SaveUndo() end

-- Calculate center and radius
local center_x = (width / 2) + center_x_offset
local center_y = (height / 2) + center_y_offset
local max_radius = math.min(center_x, center_y, width - center_x, height - center_y)
local radius = (max_radius * radius_percent) / 100

-- Store original canvas data
local original_data = {}
for y = 0, height - 1 do
    original_data[y] = {}
    for x = 0, width - 1 do
        local r, g, b = get_rgb(x, y)
        original_data[y][x] = {r, g, b}
    end
    if progress then progress(y / height * 0.3) end
end

-- Function to get pixel with boundary checking
local function get_safe_pixel(x, y)
    if x >= 0 and x < width and y >= 0 and y < height then
        return original_data[y][x][1], original_data[y][x][2], original_data[y][x][3]
    else
        return 0, 0, 0  -- Black for out-of-bounds
    end
end

-- Function to blend colors based on mode
local function blend_colors(r1, g1, b1, r2, g2, b2, mode)
    if mode == 1 then  -- Replace
        return r2, g2, b2
    elseif mode == 2 then  -- Multiply
        return r1 * r2, g1 * g2, b1 * b2
    elseif mode == 3 then  -- Screen
        return 1 - (1 - r1) * (1 - r2), 1 - (1 - g1) * (1 - g2), 1 - (1 - b1) * (1 - b2)
    else  -- Default to replace
        return r2, g2, b2
    end
end

-- Function to rotate point around center
local function rotate_point(x, y, cx, cy, angle_rad)
    local dx = x - cx
    local dy = y - cy
    local cos_a = math.cos(angle_rad)
    local sin_a = math.sin(angle_rad)
    local new_x = dx * cos_a - dy * sin_a + cx
    local new_y = dx * sin_a + dy * cos_a + cy
    return new_x, new_y
end

-- Create mandala by applying 15-degree segments
local segment_angle = math.rad(15)  -- 15 degrees in radians
local num_segments = 24  -- 360 / 15 = 24 segments

-- Process each pixel
for y = 0, height - 1 do
    for x = 0, width - 1 do
        local dx = x - center_x
        local dy = y - center_y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance <= radius then
            -- Calculate angle of current pixel
            local current_angle = math.atan2(dy, dx)
            if current_angle < 0 then
                current_angle = current_angle + 2 * math.pi
            end
            
            -- Find which 15-degree segment this pixel belongs to
            local segment = math.floor(current_angle / segment_angle)
            
            -- Calculate the "canonical" angle within the first 15-degree segment
            local canonical_angle = current_angle - (segment * segment_angle)
            
            -- For mirroring effect, we can either:
            -- 1. Map to first segment (0-15 degrees)
            -- 2. Mirror alternate segments
            
            -- Create alternating mirror pattern
            local mirror_angle
            if segment % 2 == 0 then
                mirror_angle = canonical_angle  -- Use as-is for even segments
            else
                mirror_angle = segment_angle - canonical_angle  -- Mirror for odd segments
            end
            
            -- Calculate source pixel position
            local source_x = center_x + distance * math.cos(mirror_angle)
            local source_y = center_y + distance * math.sin(mirror_angle)
            
            -- Get source pixel color (with interpolation for smoother results)
            local sx1 = math.floor(source_x)
            local sy1 = math.floor(source_y)
            local sx2 = sx1 + 1
            local sy2 = sy1 + 1
            local fx = source_x - sx1
            local fy = source_y - sy1
            
            -- Bilinear interpolation
            local r1, g1, b1 = get_safe_pixel(sx1, sy1)
            local r2, g2, b2 = get_safe_pixel(sx2, sy1)
            local r3, g3, b3 = get_safe_pixel(sx1, sy2)
            local r4, g4, b4 = get_safe_pixel(sx2, sy2)
            
            -- Interpolate top and bottom
            local rt = r1 * (1 - fx) + r2 * fx
            local gt = g1 * (1 - fx) + g2 * fx
            local bt = b1 * (1 - fx) + b2 * fx
            
            local rb = r3 * (1 - fx) + r4 * fx
            local gb = g3 * (1 - fx) + g4 * fx
            local bb = b3 * (1 - fx) + b4 * fx
            
            -- Final interpolation
            local final_r = rt * (1 - fy) + rb * fy
            local final_g = gt * (1 - fy) + gb * fy
            local final_b = bt * (1 - fy) + bb * fy
            
            -- Get current pixel for blending
            local current_r, current_g, current_b = get_rgb(x, y)
            
            -- Apply blending
            local blended_r, blended_g, blended_b = blend_colors(
                current_r, current_g, current_b,
                final_r, final_g, final_b,
                blend_mode
            )
            
            -- Clamp values
            blended_r = math.max(0, math.min(1, blended_r))
            blended_g = math.max(0, math.min(1, blended_g))
            blended_b = math.max(0, math.min(1, blended_b))
            
            set_rgb(x, y, blended_r, blended_g, blended_b)
        else
            -- NEW: Handle pixels outside the mandala radius
            if clear_outside == 1 then
                -- Set to black for clean mandala on black background
                set_rgb(x, y, 0, 0, 0)
            end
            -- If clear_outside == 0, leave original pixel unchanged
        end
    end
    
    -- Update progress
    if progress then 
        progress(0.3 + (y / height * 0.7))
    end
end

-- Refresh display
if Dog_Refresh then Dog_Refresh() end

-- Show completion message
if Dog_MessageBox then
    local bg_mode = clear_outside == 1 and "black background" or "original background"
    Dog_MessageBox("Mandala complete! " .. num_segments .. " segments, " .. radius_percent .. "% radius, " .. bg_mode)
else
    print("Mandala generation complete!")
end
