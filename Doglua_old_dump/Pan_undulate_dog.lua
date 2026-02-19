-- Canvas Sine Undulation Animator for PD Howler
-- Captures current canvas and creates sine wave movement animation
-- Based on proven canvas capture techniques

if Dog_GetTotalFrames() <= 0 then
    Dog_MessageBox("Please create an animation first!")
    return
end

if not (Dog_MessageBox and width and height and get_rgb and set_rgb and Dog_SaveUndo and Dog_GotoFrame and Dog_GetCurrentFrame) then
    Dog_MessageBox("Error: Essential Dogwaffle functions missing.")
    return
end

-- Get user parameters (using integers for UI)
local undulationAxis = Dog_ValueBox("Sine Undulation", "Undulation Axis (1=X-axis/Horizontal, 2=Y-axis/Vertical):", 1, 2, 1)
if undulationAxis == nil then return end

local leftLimitInt = Dog_ValueBox("Sine Undulation", "Left/Up limit (negative pixels, -200 to -1):", -200, -1, -50)
if leftLimitInt == nil then return end

local rightLimitInt = Dog_ValueBox("Sine Undulation", "Right/Down limit (positive pixels, 1 to 200):", 1, 200, 50)
if rightLimitInt == nil then return end

local numCycles = Dog_ValueBox("Sine Undulation", "Number of sine wave cycles (1 = one full wave, 5 = five waves):", 1, 10, 2)
if numCycles == nil then return end

local backgroundChoice = Dog_ValueBox("Sine Undulation", "Background (1=Black, 2=White, 3=Gray):", 1, 3, 1)
if backgroundChoice == nil then return end

local interpolation = Dog_ValueBox("Sine Undulation", "Quality (1=Fast/Pixelated, 2=Smooth/Interpolated):", 1, 2, 2)
if interpolation == nil then return end

local axisName = (undulationAxis == 1) and "X-axis (Horizontal)" or "Y-axis (Vertical)"
Dog_MessageBox("Sine Undulation - " .. axisName .. " movement from " .. leftLimitInt .. " to " .. rightLimitInt .. " pixels with " .. numCycles .. " cycles.")

-- Save current state
Dog_SaveUndo()

-- Store original frame
local original_frame = Dog_GetCurrentFrame()

-- Set background color based on choice
local bgR, bgG, bgB = 0, 0, 0 -- Default black
if backgroundChoice == 2 then
    bgR, bgG, bgB = 1, 1, 1 -- White
elseif backgroundChoice == 3 then
    bgR, bgG, bgB = 0.2, 0.2, 0.2 -- Gray
end

Dog_MessageBox("Capturing canvas pixels... this may take a moment for large images.")

-- 1. Capture the entire current canvas
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

if capture_pixel_count ~= (source_w * source_h) then
    Dog_MessageBox("Warning: Pixel capture count mismatch.")
end

Dog_MessageBox("Canvas captured. " .. capture_pixel_count .. " pixels stored. Creating sine undulation animation...")

-- Calculate undulation parameters
local total_frames = Dog_GetTotalFrames()
local movement_range = rightLimitInt - leftLimitInt

-- Function to get pixel from captured data with bounds checking
function getCapturedPixel(x, y)
    if x < 0 or x >= source_w or y < 0 or y >= source_h then
        return bgR, bgG, bgB
    end
    
    local data_index = (y * source_w + x) * 3 + 1
    if data_index + 2 <= #canvas_pixels_rgb then
        return canvas_pixels_rgb[data_index], canvas_pixels_rgb[data_index + 1], canvas_pixels_rgb[data_index + 2]
    else
        return bgR, bgG, bgB
    end
end

-- Function to calculate sine wave offset for current frame
function calculateSineOffset(frame, total_frames, leftLimit, rightLimit, cycles)
    local progress = frame / total_frames
    local sine_angle = progress * 2 * math.pi * cycles
    local sine_value = math.sin(sine_angle) -- -1 to +1
    
    -- Map sine value (-1 to +1) to movement range (leftLimit to rightLimit)
    local center = (leftLimit + rightLimit) / 2
    local amplitude = (rightLimit - leftLimit) / 2
    local offset = center + (sine_value * amplitude)
    
    return math.floor(offset + 0.5) -- Round to nearest integer
end

-- Function to get undulated pixel with optional interpolation
function getUndulatedPixel(srcX, srcY)
    if interpolation == 1 then
        -- Nearest neighbor (fast)
        local x = math.floor(srcX + 0.5)
        local y = math.floor(srcY + 0.5)
        return getCapturedPixel(x, y)
    else
        -- Bilinear interpolation (smooth)
        local x1 = math.floor(srcX)
        local y1 = math.floor(srcY)
        local x2 = x1 + 1
        local y2 = y1 + 1
        
        local fx = srcX - x1
        local fy = srcY - y1
        
        -- Get four corner pixels
        local r1, g1, b1 = getCapturedPixel(x1, y1)
        local r2, g2, b2 = getCapturedPixel(x2, y1)
        local r3, g3, b3 = getCapturedPixel(x1, y2)
        local r4, g4, b4 = getCapturedPixel(x2, y2)
        
        -- Bilinear interpolation
        local r = r1 * (1-fx) * (1-fy) + r2 * fx * (1-fy) + r3 * (1-fx) * fy + r4 * fx * fy
        local g = g1 * (1-fx) * (1-fy) + g2 * fx * (1-fy) + g3 * (1-fx) * fy + g4 * fx * fy
        local b = b1 * (1-fx) * (1-fy) + b2 * fx * (1-fy) + b3 * (1-fx) * fy + b4 * fx * fy
        
        return r, g, b
    end
end

-- 2. Generate sine undulation animation
for frame = 0, total_frames - 1 do
    if Dog_CheckQuit and Dog_CheckQuit() then
        Dog_MessageBox("Animation cancelled.")
        Dog_GotoFrame(original_frame)
        return
    end
    
    -- Go to current frame
    Dog_GotoFrame(frame)
    
    -- Calculate sine wave offset for this frame
    local currentOffset = calculateSineOffset(frame, total_frames, leftLimitInt, rightLimitInt, numCycles)
    
    -- Clear canvas with background
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            set_rgb(x, y, bgR, bgG, bgB)
        end
    end
    
    -- Render undulated canvas
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            -- Calculate source coordinates based on undulation axis
            local srcX, srcY
            
            if undulationAxis == 1 then
                -- X-axis undulation (horizontal movement)
                srcX = x - currentOffset
                srcY = y
            else
                -- Y-axis undulation (vertical movement)
                srcX = x
                srcY = y - currentOffset
            end
            
            -- Get undulated pixel color
            local r, g, b = getUndulatedPixel(srcX, srcY)
            
            -- Set pixel
            set_rgb(x, y, r, g, b)
        end
    end
end

-- Return to original frame
Dog_GotoFrame(original_frame)

-- Create movement description for user
local axisDescription = (undulationAxis == 1) and "horizontal" or "vertical"
Dog_MessageBox("Sine undulation complete! " .. axisDescription .. " movement from " .. leftLimitInt .. " to " .. rightLimitInt .. " pixels with " .. numCycles .. " wave cycles.")
