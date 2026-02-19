-- Canvas Rotation Animator for PD Howler
-- Captures current canvas and creates seamless 360° rotation animation
-- Based on proven canvas capture techniques from pad sequencer

if Dog_GetTotalFrames() <= 0 then
    Dog_MessageBox("Please create an animation first!")
    return
end

if not (Dog_MessageBox and width and height and get_rgb and set_rgb and Dog_SaveUndo and Dog_GotoFrame and Dog_GetCurrentFrame) then
    Dog_MessageBox("Error: Essential Dogwaffle functions missing.")
    return
end

-- Get user parameters
local rotationSpeed = Dog_ValueBox("Rotation Animator", "Rotation speed (1=One full rotation, 2=Two rotations, etc.):", 1, 5, 1)
if rotationSpeed == nil then return end

local backgroundChoice = Dog_ValueBox("Rotation Animator", "Background (1=Black, 2=White, 3=Gray):", 1, 3, 1)
if backgroundChoice == nil then return end

local interpolation = Dog_ValueBox("Rotation Animator", "Quality (1=Fast/Pixelated, 2=Smooth/Interpolated):", 1, 2, 1)
if interpolation == nil then return end

Dog_MessageBox("Rotation Animator - Capturing canvas and creating " .. rotationSpeed .. " rotation(s) across " .. Dog_GetTotalFrames() .. " frames.")

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

-- 1. Capture the entire current canvas (using same technique as pad sequencer)
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
            -- Fallback for any missing pixels
            table.insert(canvas_pixels_rgb, 0)
            table.insert(canvas_pixels_rgb, 0)
            table.insert(canvas_pixels_rgb, 0)
        end
    end
end

if capture_pixel_count ~= (source_w * source_h) then
    Dog_MessageBox("Warning: Pixel capture count (" .. capture_pixel_count .. ") does not match expected (" .. (source_w * source_h) .. "). Results may be incorrect.")
end

Dog_MessageBox("Canvas captured. " .. capture_pixel_count .. " pixels stored. Creating rotation animation...")

-- Calculate rotation parameters
local total_frames = Dog_GetTotalFrames()
local centerX = source_w / 2
local centerY = source_h / 2

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

-- Function to rotate a point around center
function rotatePoint(x, y, centerX, centerY, angle)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    
    -- Translate to origin
    local tx = x - centerX
    local ty = y - centerY
    
    -- Rotate
    local rx = tx * cos_a - ty * sin_a
    local ry = tx * sin_a + ty * cos_a
    
    -- Translate back
    return rx + centerX, ry + centerY
end

-- Function to get rotated pixel with optional interpolation
function getRotatedPixel(srcX, srcY)
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

-- 2. Generate rotation animation
for frame = 0, total_frames - 1 do
    if Dog_CheckQuit and Dog_CheckQuit() then
        Dog_MessageBox("Animation cancelled.")
        Dog_GotoFrame(original_frame)
        return
    end
    
    -- Go to current frame
    Dog_GotoFrame(frame)
    
    -- Calculate rotation angle for this frame
    local frame_progress = frame / total_frames
    local angle = frame_progress * 2 * math.pi * rotationSpeed -- radians
    
    -- Clear canvas with background
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            set_rgb(x, y, bgR, bgG, bgB)
        end
    end
    
    -- Render rotated canvas
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            -- Find source pixel by rotating destination point backwards
            local srcX, srcY = rotatePoint(x, y, centerX, centerY, -angle)
            
            -- Get rotated pixel color
            local r, g, b = getRotatedPixel(srcX, srcY)
            
            -- Set pixel
            set_rgb(x, y, r, g, b)
        end
    end
end

-- Return to original frame
Dog_GotoFrame(original_frame)

Dog_MessageBox("Rotation animation complete! " .. total_frames .. " frames with " .. rotationSpeed .. " rotation(s) created.")
