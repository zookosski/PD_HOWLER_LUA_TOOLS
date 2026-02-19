-- PD Howler Lua Script: Animated Wave Pattern Generator
-- Creates layered wave patterns with gradient falloff and animation

-- Check if we have essential functions and timeline
if Dog_GetTotalFrames() <= 0 then
    Dog_MessageBox("Please create a timeline first!")
    return
end

if width == nil or height == nil then
    Dog_MessageBox("Error: Canvas dimensions not available")
    return
end

-- Get user parameters
local wave_height = Dog_ValueBox("Wave Height", "Wave amplitude (pixels):", 20, 200, 80)
if wave_height == nil then return end

local wave_frequency = Dog_ValueBox("Wave Frequency", "Number of wave cycles:", 1, 10, 3)
if wave_frequency == nil then return end

local wave_layers = Dog_ValueBox("Wave Layers", "Number of wave layers:", 2, 8, 4)
if wave_layers == nil then return end

local gradient_height = Dog_ValueBox("Gradient Height", "Gradient falloff height:", 50, 300, 150)
if gradient_height == nil then return end

local animate_speed = Dog_ValueBox("Animation Speed", "Animation speed (1-10):", 1, 10, 3)
if animate_speed == nil then return end

-- Save undo state and get animation info
Dog_SaveUndo()
local total_frames = Dog_GetTotalFrames()
local original_frame = Dog_GetCurrentFrame()

-- Color scheme for waves (blue gradient like in the image)
local wave_colors = {
    {0.1, 0.2, 0.6},  -- Dark blue
    {0.2, 0.4, 0.8},  -- Medium blue
    {0.3, 0.6, 0.9},  -- Light blue
    {0.4, 0.7, 1.0},  -- Lightest blue
}

-- Generate wave function
function generate_wave(x, y, frame, layer)
    local time = frame * animate_speed * 0.1
    local layer_offset = layer * 0.3
    local layer_frequency = wave_frequency * (1 + layer * 0.2)
    local layer_amplitude = wave_height * (0.8 + layer * 0.1)
    
    -- Multiple sine waves for more organic movement
    local wave1 = math.sin((x / width) * layer_frequency * 2 * math.pi + time + layer_offset)
    local wave2 = math.sin((x / width) * layer_frequency * 1.5 * math.pi + time * 1.3 + layer_offset)
    local wave3 = math.sin((x / width) * layer_frequency * 2.5 * math.pi + time * 0.7 + layer_offset)
    
    -- Combine waves for more complex pattern
    local combined_wave = (wave1 + wave2 * 0.5 + wave3 * 0.3) / 1.8
    
    -- Calculate wave height at this x position
    local wave_y = height - layer_amplitude - (combined_wave * layer_amplitude * 0.5)
    
    return wave_y
end

-- Calculate wave coverage and gradient
function calculate_wave_influence(x, y, frame)
    local max_influence = 0
    local color_r, color_g, color_b = 0, 0, 0
    
    -- Check each wave layer
    for layer = 1, wave_layers do
        local wave_y = generate_wave(x, y, frame, layer - 1)
        
        if y >= wave_y then
            -- We're below this wave layer
            local distance_below = y - wave_y
            local layer_influence = math.max(0, 1 - (distance_below / gradient_height))
            
            if layer_influence > 0 then
                -- Get color for this layer
                local color_index = ((layer - 1) % #wave_colors) + 1
                local layer_color = wave_colors[color_index]
                
                -- Blend colors based on influence
                if layer_influence > max_influence then
                    local blend_factor = layer_influence
                    color_r = color_r * (1 - blend_factor) + layer_color[1] * blend_factor
                    color_g = color_g * (1 - blend_factor) + layer_color[2] * blend_factor
                    color_b = color_b * (1 - blend_factor) + layer_color[3] * blend_factor
                    max_influence = layer_influence
                end
            end
        end
    end
    
    return max_influence, color_r, color_g, color_b
end

-- Main animation loop
Dog_MessageBox("Generating animated wave pattern...")

for frame = 0, total_frames - 1 do
    -- Check for user cancellation
    if Dog_CheckQuit and Dog_CheckQuit() then
        Dog_MessageBox("Animation cancelled.")
        Dog_GotoFrame(original_frame)
        return
    end
    
    Dog_GotoFrame(frame)
    
    -- Process each pixel
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            -- Get current pixel
            local curr_r, curr_g, curr_b = get_rgb(x, y)
            
            -- Calculate wave influence at this position
            local influence, wave_r, wave_g, wave_b = calculate_wave_influence(x, y, frame)
            
            if influence > 0 then
                -- Apply gradient falloff
                local gradient_factor = 1.0
                local distance_from_bottom = height - y
                if distance_from_bottom < gradient_height then
                    gradient_factor = distance_from_bottom / gradient_height
                end
                
                -- Apply final influence with gradient
                local final_influence = influence * gradient_factor
                
                -- Blend with existing pixel
                local final_r = curr_r * (1 - final_influence) + wave_r * final_influence
                local final_g = curr_g * (1 - final_influence) + wave_g * final_influence
                local final_b = curr_b * (1 - final_influence) + wave_b * final_influence
                
                -- Clamp values
                final_r = math.max(0, math.min(1, final_r))
                final_g = math.max(0, math.min(1, final_g))
                final_b = math.max(0, math.min(1, final_b))
                
                set_rgb(x, y, final_r, final_g, final_b)
            end
        end
        
        -- Update progress
        if progress then 
            local frame_progress = frame / total_frames
            local row_progress = y / height
            progress((frame_progress + row_progress / total_frames))
        end
    end
    
    -- Refresh display for real-time feedback
    if Dog_Refresh then
        Dog_Refresh()
    end
end

-- Return to original frame
Dog_GotoFrame(original_frame)
Dog_MessageBox("Wave animation complete! " .. total_frames .. " frames generated.")

-- Optional: Display helpful information
Dog_MessageBox("Wave Pattern Settings:\n" ..
    "Height: " .. wave_height .. " pixels\n" ..
    "Frequency: " .. wave_frequency .. " cycles\n" ..
    "Layers: " .. wave_layers .. "\n" ..
    "Gradient: " .. gradient_height .. " pixels\n" ..
    "Animation Speed: " .. animate_speed)
