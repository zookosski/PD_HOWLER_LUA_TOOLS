-- Sporadic Geiger-Counter Style Glitch Effects for PD Howler
-- Creates random bursts of intense glitch effects like radiation detection
-- Sample-and-hold behavior with accelerating/decelerating cycles

if Dog_GetTotalFrames() <= 0 then
    Dog_MessageBox("Please create an animation first!")
    return
end

if not (Dog_MessageBox and width and height and get_rgb and set_rgb and Dog_SaveUndo and Dog_GotoFrame and Dog_GetCurrentFrame) then
    Dog_MessageBox("Error: Essential Dogwaffle functions missing.")
    return
end

-- Get user parameters for sporadic glitch intensity
local maxRGBIntensity = Dog_ValueBox("Sporadic Glitch", "Maximum RGB shift intensity (0=Off, 15=Extreme):", 0, 15, 9)
if maxRGBIntensity == nil then return end

local maxScanlineIntensity = Dog_ValueBox("Sporadic Glitch", "Maximum Scanline intensity (0=Off, 25=Extreme):", 0, 25, 15)
if maxScanlineIntensity == nil then return end

local maxBlockIntensity = Dog_ValueBox("Sporadic Glitch", "Maximum noise overlay (0=Off, 20=Heavy static):", 0, 20, 8)
if maxBlockIntensity == nil then return end

local maxStutterIntensity = Dog_ValueBox("Sporadic Glitch", "Maximum Frame stutter (0=Off, 10=Heavy):", 0, 10, 6)
if maxStutterIntensity == nil then return end

local frameOpacityVariation = Dog_ValueBox("Sporadic Glitch", "Frame opacity variation (0=Stable, 80=Flickering):", 0, 80, 30)
if frameOpacityVariation == nil then return end

local glitchRandomSeed = Dog_ValueBox("Sporadic Glitch", "Random seed (1-1000, changes patterns):", 1, 1000, 123)
if glitchRandomSeed == nil then return end

Dog_MessageBox("Sporadic Glitch Effects - Creating Geiger-counter style random bursts across " .. Dog_GetTotalFrames() .. " frames.")

-- Save current state
Dog_SaveUndo()

-- Store original frame
local original_frame = Dog_GetCurrentFrame()

-- Initialize base random seed
math.randomseed(glitchRandomSeed)

Dog_MessageBox("Capturing canvas for sporadic glitch processing...")

-- 1. Capture the entire canvas
local canvas_pixels_rgb = {}
local source_w = width
local source_h = height
local capture_pixel_count = 0

for y = 0, source_h - 1 do
    if Dog_CheckQuit and Dog_CheckQuit() then
        Dog_MessageBox("Capture cancelled.")
        Dog_GotoFrame(original_frame)
        return
    end
    
    for x = 0, source_w - 1 do
        local r, g, b = get_rgb(x, y)
        if r ~= nil and g ~= nil and b ~= nil then
            table.insert(canvas_pixels_rgb, r)
            table.insert(canvas_pixels_rgb, g)
            table.insert(canvas_pixels_rgb, b)
            capture_pixel_count = capture_pixel_count + 1
        else
            table.insert(canvas_pixels_rgb, 0)
            table.insert(canvas_pixels_rgb, 0)
            table.insert(canvas_pixels_rgb, 0)
        end
    end
end

Dog_MessageBox("Canvas captured. Creating sporadic glitch intensity patterns...")

-- Calculate animation parameters
local total_frames = Dog_GetTotalFrames()

-- Pre-generate sporadic intensity patterns for each effect (Geiger counter style)
local rgbIntensities = {}
local scanlineIntensities = {}
local blockIntensities = {}
local stutterIntensities = {}
local frameOpacities = {}

-- Function to generate Geiger-counter style random pattern
function generateSporadicPattern(max_intensity, frame_count, seed_offset)
    local pattern = {}
    local local_seed = glitchRandomSeed + seed_offset
    math.randomseed(local_seed)
    
    for frame = 1, frame_count do
        -- Create accelerating/decelerating cycle behavior
        local cycle_position = (frame / frame_count) * 4 * math.pi -- Multiple cycles
        local cycle_intensity = math.abs(math.sin(cycle_position)) * 0.5 + 0.5 -- 0.5 to 1.0
        
        -- Sample-and-hold: random chance of activity, influenced by cycle
        local activity_chance = cycle_intensity * 0.3 -- 30% max chance at peak
        local is_active = math.random() < activity_chance
        
        if is_active then
            -- Random burst intensity (1 to max)
            local burst_intensity = math.random(1, max_intensity)
            pattern[frame] = burst_intensity
        else
            pattern[frame] = 0
        end
    end
    
    return pattern
end

-- Generate patterns for each effect type
rgbIntensities = generateSporadicPattern(maxRGBIntensity, total_frames, 100)
scanlineIntensities = generateSporadicPattern(maxScanlineIntensity, total_frames, 200)
noiseIntensities = generateSporadicPattern(maxBlockIntensity, total_frames, 300)
stutterIntensities = generateSporadicPattern(maxStutterIntensity, total_frames, 400)

-- Generate frame opacity pattern
for frame = 1, total_frames do
    math.randomseed(glitchRandomSeed + frame + 500)
    local opacity_variation = (math.random() - 0.5) * (frameOpacityVariation / 100.0)
    frameOpacities[frame] = math.max(0.2, math.min(1.0, 1.0 + opacity_variation))
end

-- Function to get pixel from captured data
function getCapturedPixel(x, y)
    if x < 0 or x >= source_w or y < 0 or y >= source_h then
        return 0, 0, 0
    end
    
    local data_index = (y * source_w + x) * 3 + 1
    if data_index + 2 <= #canvas_pixels_rgb then
        return canvas_pixels_rgb[data_index], canvas_pixels_rgb[data_index + 1], canvas_pixels_rgb[data_index + 2]
    else
        return 0, 0, 0
    end
end

-- Function to apply sporadic RGB channel shift
function applySporadicRGBGlitch(x, y, intensity)
    if intensity == 0 then
        return getCapturedPixel(x, y)
    end
    
    -- Dramatic RGB separation
    local shift_r_x = math.floor((math.sin(y * 0.05) * intensity * 2))
    local shift_g_x = 0
    local shift_b_x = math.floor((math.cos(y * 0.05) * intensity * -2))
    
    local r, _, _ = getCapturedPixel(x + shift_r_x, y)
    local _, g, _ = getCapturedPixel(x + shift_g_x, y)
    local _, _, b = getCapturedPixel(x + shift_b_x, y)
    
    return r, g, b
end

-- Function to apply sporadic scanline displacement
function applySporadicScanlineGlitch(x, y, intensity)
    if intensity == 0 then return x, y end
    
    -- More dramatic and frequent scanline shifts
    local line_hash = (y * 31 + intensity * 7) % 10
    if line_hash < 3 then -- 30% of lines affected when active
        local displacement = math.floor((math.sin(y * 0.1 + intensity) * intensity * 3))
        return x + displacement, y
    end
    
    return x, y
end

-- Function to check sporadic block corruption
function shouldSporadicallyCorruptBlock(x, y, intensity)
    if intensity == 0 then return false end
    
    local block_size = 16 -- Larger blocks for more dramatic effect
    local block_x = math.floor(x / block_size)
    local block_y = math.floor(y / block_size)
    local block_hash = (block_x * 23 + block_y * 41 + intensity * 13) % 100
    
    return (block_hash / 100.0) < (intensity / 25.0) -- More selective corruption
end

-- Function to generate smooth full-frame noise overlay
function generateSmoothNoise(x, y, intensity, frame)
    if intensity == 0 then return 0, 0, 0 end
    
    -- Create smooth animated noise using sine/cosine combinations
    local noise_factor = intensity / 20.0
    local time_factor = frame * 0.1
    
    -- Multiple frequency noise for natural randomness
    local noise1 = math.sin(x * 0.1 + time_factor) * math.cos(y * 0.1 + time_factor)
    local noise2 = math.sin(x * 0.05 + time_factor * 1.3) * math.cos(y * 0.08 + time_factor * 0.7)
    local noise3 = math.sin(x * 0.2 + time_factor * 0.5) * math.cos(y * 0.15 + time_factor * 1.1)
    
    -- Combine noises for more natural pattern
    local combined_noise = (noise1 + noise2 * 0.5 + noise3 * 0.3) / 1.8
    
    -- Scale to appropriate range
    local noise_amount = combined_noise * noise_factor
    
    return noise_amount, noise_amount, noise_amount
end

-- Stutter frame tracking
local stutter_source_frame = 0

-- 2. Generate sporadic glitched animation
for frame = 0, total_frames - 1 do
    if Dog_CheckQuit and Dog_CheckQuit() then
        Dog_MessageBox("Animation cancelled.")
        Dog_GotoFrame(original_frame)
        return
    end
    
    -- Go to current frame
    Dog_GotoFrame(frame)
    
    -- Get sporadic intensities for this frame
    local frame_index = frame + 1 -- Lua arrays start at 1
    local current_rgb_intensity = rgbIntensities[frame_index] or 0
    local current_scanline_intensity = scanlineIntensities[frame_index] or 0
    local current_noise_intensity = noiseIntensities[frame_index] or 0
    local current_stutter_intensity = stutterIntensities[frame_index] or 0
    local current_opacity = frameOpacities[frame_index] or 1.0
    
    -- Handle frame stuttering
    local source_frame = frame
    if current_stutter_intensity > 0 then
        -- Stutter: jump back or freeze
        if math.random() < 0.5 then
            stutter_source_frame = math.max(0, frame - math.random(1, current_stutter_intensity))
        end
        source_frame = stutter_source_frame
    else
        stutter_source_frame = frame
    end
    
    -- Reset random for this frame's effects
    math.randomseed(glitchRandomSeed + source_frame * 17)
    
    -- Apply sporadic glitch effects
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            -- Apply scanline glitch
            local glitch_x, glitch_y = applySporadicScanlineGlitch(x, y, current_scanline_intensity)
            
            -- Apply RGB channel shift
            local r, g, b = applySporadicRGBGlitch(glitch_x, glitch_y, current_rgb_intensity)
            
            -- Apply smooth animated noise overlay
            if current_noise_intensity > 0 then
                local noise_r, noise_g, noise_b = generateSmoothNoise(x, y, current_noise_intensity, frame)
                r = r + noise_r
                g = g + noise_g
                b = b + noise_b
            end
            
            -- Apply frame opacity variation
            r = r * current_opacity
            g = g * current_opacity
            b = b * current_opacity
            
            -- Clamp values
            r = math.max(0, math.min(1, r))
            g = math.max(0, math.min(1, g))
            b = math.max(0, math.min(1, b))
            
            -- Set final pixel
            set_rgb(x, y, r, g, b)
        end
    end
end

-- Return to original frame
Dog_GotoFrame(original_frame)

Dog_MessageBox("Sporadic glitch effects complete! Created Geiger-counter style random bursts with opacity flickering across " .. total_frames .. " frames.")
