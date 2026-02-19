-- Rolling Wheel Animator for PD Howler
-- Captures circular area and rolls it from left to right like a tire/wheel
-- Realistic rolling motion with proper rotation speed

if Dog_GetTotalFrames() <= 0 then
    Dog_MessageBox("Please create an animation first!")
    return
end

if not (Dog_MessageBox and width and height and get_rgb and set_rgb and Dog_SaveUndo and Dog_GotoFrame and Dog_GetCurrentFrame) then
    Dog_MessageBox("Error: Essential Dogwaffle functions missing.")
    return
end

-- Get user parameters
local wheelRadius = Dog_ValueBox("Rolling Wheel", "Wheel radius (pixels to capture from center):", 15, 120, 40)
if wheelRadius == nil then return end

local groundOffset = Dog_ValueBox("Rolling Wheel", "Ground clearance (pixels above bottom edge):", 0, 50, 5)
if groundOffset == nil then return end

local rollDirection = Dog_ValueBox("Rolling Wheel", "Roll direction (1=Left to Right, 2=Right to Left):", 1, 2, 1)
if rollDirection == nil then return end

local rollSpeed = Dog_ValueBox("Rolling Wheel", "Roll speed (1=Slow, 2=Normal, 3=Fast):", 1, 3, 2)
if rollSpeed == nil then return end

local backgroundChoice = Dog_ValueBox("Rolling Wheel", "Background (1=Black, 2=White, 3=Gray):", 1, 3, 1)
if backgroundChoice == nil then return end

local directionText = (rollDirection == 1) and "Left to Right" or "Right to Left"
Dog_MessageBox("Rolling Wheel - " .. (wheelRadius*2) .. "px diameter wheel rolling " .. directionText .. ", " .. groundOffset .. "px above ground.")

-- Save current state
Dog_SaveUndo()

-- Store original frame
local original_frame = Dog_GetCurrentFrame()

-- Set background color
local bgR, bgG, bgB = 0, 0, 0 -- Default black
if backgroundChoice == 2 then
    bgR, bgG, bgB = 1, 1, 1 -- White
elseif backgroundChoice == 3 then
    bgR, bgG, bgB = 0.2, 0.2, 0.2 -- Gray
end

Dog_MessageBox("Capturing circular wheel area from canvas center...")

-- 1. Capture circular area from canvas center
local wheelPixels = {}
local centerX = math.floor(width / 2)
local centerY = math.floor(height / 2)

-- Initialize wheel pixel array
for dy = -wheelRadius, wheelRadius do
    wheelPixels[dy] = {}
    for dx = -wheelRadius, wheelRadius do
        wheelPixels[dy][dx] = {r = bgR, g = bgG, b = bgB} -- Default to background
    end
end

-- Capture pixels within circle
local capturedPixels = 0
for dy = -wheelRadius, wheelRadius do
    for dx = -wheelRadius, wheelRadius do
        local distance = math.sqrt(dx*dx + dy*dy)
        if distance <= wheelRadius then
            local sourceX = centerX + dx
            local sourceY = centerY + dy
            
            if sourceX >= 0 and sourceX < width and sourceY >= 0 and sourceY < height then
                local r, g, b = get_rgb(sourceX, sourceY)
                wheelPixels[dy][dx] = {r = r or bgR, g = g or bgG, b = b or bgB}
                capturedPixels = capturedPixels + 1
            end
        end
    end
end

Dog_MessageBox("Wheel captured: " .. capturedPixels .. " pixels in " .. wheelRadius .. " pixel radius circle.")

-- Calculate animation parameters
local total_frames = Dog_GetTotalFrames()
local ground_y = height - groundOffset - wheelRadius -- Y position of wheel center
local travel_distance = width + wheelRadius * 2 -- Total distance including off-screen
local speed_multiplier = rollSpeed -- 1=slow, 2=normal, 3=fast

-- Function to rotate a point around origin
function rotatePoint(x, y, angle)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    return x * cos_a - y * sin_a, x * sin_a + y * cos_a
end

-- Function to get rotated wheel pixel
function getRotatedWheelPixel(dx, dy, angle)
    local rotX, rotY = rotatePoint(dx, dy, angle)
    local gridX = math.floor(rotX + 0.5)
    local gridY = math.floor(rotY + 0.5)
    
    if wheelPixels[gridY] and wheelPixels[gridY][gridX] then
        return wheelPixels[gridY][gridX].r, wheelPixels[gridY][gridX].g, wheelPixels[gridY][gridX].b
    else
        return bgR, bgG, bgB
    end
end

-- Function to calculate wheel position and rotation
function calculateWheelMotion(frame, total_frames, direction, speed)
    local progress = frame / total_frames
    
    -- Calculate horizontal position
    local wheel_x
    if direction == 1 then
        -- Left to Right: start off-screen left, end off-screen right
        wheel_x = -wheelRadius + progress * travel_distance
    else
        -- Right to Left: start off-screen right, end off-screen left
        wheel_x = width + wheelRadius - progress * travel_distance
    end
    
    -- Calculate rotation based on distance traveled (realistic rolling)
    local distance_traveled = progress * travel_distance
    local circumference = 2 * math.pi * wheelRadius
    local rotations = distance_traveled / circumference * speed
    local rotation_angle = -rotations * 2 * math.pi  -- Negative to make clockwise for left-to-right
    
    -- Set correct rotation direction for realistic rolling
    if direction == 1 then
        -- Left to Right: wheel should rotate clockwise (use negative angle)
        rotation_angle = rotation_angle
    else
        -- Right to Left: wheel should rotate counter-clockwise (use positive angle)
        rotation_angle = -rotation_angle
    end
    
    return math.floor(wheel_x + 0.5), rotation_angle
end

-- 2. Generate rolling wheel animation
for frame = 0, total_frames - 1 do
    if Dog_CheckQuit and Dog_CheckQuit() then
        Dog_MessageBox("Animation cancelled.")
        Dog_GotoFrame(original_frame)
        return
    end
    
    -- Go to current frame
    Dog_GotoFrame(frame)
    
    -- Calculate wheel position and rotation for this frame
    local wheelX, rotationAngle = calculateWheelMotion(frame, total_frames, rollDirection, speed_multiplier)
    local wheelY = ground_y
    
    -- Clear canvas with background
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            set_rgb(x, y, bgR, bgG, bgB)
        end
    end
    
    -- Draw rotating rolling wheel
    for dy = -wheelRadius, wheelRadius do
        for dx = -wheelRadius, wheelRadius do
            local distance = math.sqrt(dx*dx + dy*dy)
            if distance <= wheelRadius then
                -- Get rotated pixel from wheel
                local r, g, b = getRotatedWheelPixel(dx, dy, rotationAngle)
                
                -- Calculate screen position
                local screenX = wheelX + dx
                local screenY = wheelY + dy
                
                -- Draw pixel if within screen bounds
                if screenX >= 0 and screenX < width and screenY >= 0 and screenY < height then
                    set_rgb(screenX, screenY, r, g, b)
                end
            end
        end
    end
end

-- Return to original frame
Dog_GotoFrame(original_frame)

local speedNames = {"Slow", "Normal", "Fast"}
local speedName = speedNames[rollSpeed] or "Unknown"
Dog_MessageBox("Rolling wheel animation complete! " .. directionText .. " motion at " .. speedName .. " speed, " .. groundOffset .. "px ground clearance.")
