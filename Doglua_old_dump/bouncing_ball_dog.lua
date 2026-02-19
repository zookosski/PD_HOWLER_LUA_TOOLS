-- Bouncing Ball Animator for PD Howler
-- Captures circular area from canvas center and creates bouncing ball with rotation
-- Realistic bounce physics with energy decay

if Dog_GetTotalFrames() <= 0 then
    Dog_MessageBox("Please create an animation first!")
    return
end

if not (Dog_MessageBox and width and height and get_rgb and set_rgb and Dog_SaveUndo and Dog_GotoFrame and Dog_GetCurrentFrame) then
    Dog_MessageBox("Error: Essential Dogwaffle functions missing.")
    return
end

-- Get user parameters
local ballRadius = Dog_ValueBox("Bouncing Ball", "Ball radius (pixels to capture from center):", 10, 100, 30)
if ballRadius == nil then return end

local rotationDegrees = Dog_ValueBox("Bouncing Ball", "Total rotation (1440=4 spins, 3600=10 spins, 7200=20 spins):", 720, 7200, 1800)
if rotationDegrees == nil then return end

local numBounces = Dog_ValueBox("Bouncing Ball", "Number of bounces (3=few bounces, 15=many bounces, 25=high oscillation):", 3, 25, 8)
if numBounces == nil then return end

local energyDecay = Dog_ValueBox("Bouncing Ball", "Energy decay per bounce (40=high loss/quick settle, 85=low loss/long bouncing):", 40, 90, 75)
if energyDecay == nil then return end

local backgroundChoice = Dog_ValueBox("Bouncing Ball", "Background (1=Black, 2=White, 3=Gray):", 1, 3, 1)
if backgroundChoice == nil then return end

Dog_MessageBox("Bouncing Ball - Capturing " .. (ballRadius*2) .. "px diameter circle, " .. rotationDegrees .. "° rotation, " .. numBounces .. " bounces.")

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

Dog_MessageBox("Capturing circular ball area from canvas center...")

-- 1. Capture circular area from canvas center
local ballPixels = {}
local centerX = math.floor(width / 2)
local centerY = math.floor(height / 2)
local ballSize = ballRadius * 2 + 1

-- Initialize ball pixel array
for dy = -ballRadius, ballRadius do
    ballPixels[dy] = {}
    for dx = -ballRadius, ballRadius do
        ballPixels[dy][dx] = {r = bgR, g = bgG, b = bgB} -- Default to background
    end
end

-- Capture pixels within circle
local capturedPixels = 0
for dy = -ballRadius, ballRadius do
    for dx = -ballRadius, ballRadius do
        local distance = math.sqrt(dx*dx + dy*dy)
        if distance <= ballRadius then
            local sourceX = centerX + dx
            local sourceY = centerY + dy
            
            if sourceX >= 0 and sourceX < width and sourceY >= 0 and sourceY < height then
                local r, g, b = get_rgb(sourceX, sourceY)
                ballPixels[dy][dx] = {r = r or bgR, g = g or bgG, b = b or bgB}
                capturedPixels = capturedPixels + 1
            end
        end
    end
end

Dog_MessageBox("Ball captured: " .. capturedPixels .. " pixels in " .. ballRadius .. " pixel radius circle.")

-- Calculate animation parameters
local total_frames = Dog_GetTotalFrames()
local decay_factor = energyDecay / 100.0

-- Function to rotate a point around origin
function rotatePoint(x, y, angle)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    return x * cos_a - y * sin_a, x * sin_a + y * cos_a
end

-- Function to get rotated ball pixel
function getRotatedBallPixel(dx, dy, angle)
    local rotX, rotY = rotatePoint(dx, dy, angle)
    local gridX = math.floor(rotX + 0.5)
    local gridY = math.floor(rotY + 0.5)
    
    if ballPixels[gridY] and ballPixels[gridY][gridX] then
        return ballPixels[gridY][gridX].r, ballPixels[gridY][gridX].g, ballPixels[gridY][gridX].b
    else
        return bgR, bgG, bgB
    end
end

-- Function to calculate bounce position with realistic physics
function calculateBouncePosition(frame, total_frames, num_bounces, decay_factor)
    local progress = frame / total_frames
    local bounce_period = 1.0 / num_bounces
    local current_bounce = math.floor(progress / bounce_period)
    local bounce_progress = (progress % bounce_period) / bounce_period
    
    -- Calculate height reduction for this bounce
    local height_multiplier = math.pow(decay_factor, current_bounce)
    
    -- Physics: parabolic motion (gravity simulation)
    -- y = initial_height - 0.5 * g * t^2 (simplified)
    local gravity_curve = 4 * bounce_progress * (1 - bounce_progress) -- Parabolic curve 0 to 1 to 0
    local bounce_height = height_multiplier * gravity_curve
    
    -- Map to screen coordinates (0 = top, 1 = bottom)
    local drop_distance = height - ballRadius * 2
    local ball_y = ballRadius + (1 - bounce_height) * drop_distance
    
    return math.floor(ball_y + 0.5)
end

-- 2. Generate bouncing ball animation
for frame = 0, total_frames - 1 do
    if Dog_CheckQuit and Dog_CheckQuit() then
        Dog_MessageBox("Animation cancelled.")
        Dog_GotoFrame(original_frame)
        return
    end
    
    -- Go to current frame
    Dog_GotoFrame(frame)
    
    -- Calculate ball position and rotation for this frame
    local ballY = calculateBouncePosition(frame, total_frames, numBounces, decay_factor)
    local ballX = centerX -- Keep centered horizontally
    
    -- Calculate rotation angle
    local rotation_progress = frame / total_frames
    local rotation_angle = rotation_progress * (rotationDegrees * math.pi / 180) -- Convert to radians
    
    -- Clear canvas with background
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            set_rgb(x, y, bgR, bgG, bgB)
        end
    end
    
    -- Draw rotated bouncing ball
    for dy = -ballRadius, ballRadius do
        for dx = -ballRadius, ballRadius do
            local distance = math.sqrt(dx*dx + dy*dy)
            if distance <= ballRadius then
                -- Get rotated pixel from ball
                local r, g, b = getRotatedBallPixel(dx, dy, rotation_angle)
                
                -- Calculate screen position
                local screenX = ballX + dx
                local screenY = ballY + dy
                
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

Dog_MessageBox("Bouncing ball animation complete! " .. numBounces .. " bounces with " .. rotationDegrees .. "° rotation and " .. (100-energyDecay) .. "% energy loss per bounce.")
