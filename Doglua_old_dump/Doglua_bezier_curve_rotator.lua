-- Radial Bézier Curve Generator for PD Howler
-- Creates multiple curves radiating from center with user controls and animation

-- Check if we have an animation
if Dog_GetTotalFrames() > 0 then
    
    -- Get user parameters using proper Dog_ValueBox syntax
    local numCurves = Dog_ValueBox("Radial Bezier", "Number of curves in radial array:", 3, 128, 6)
    if numCurves == nil then return end -- User cancelled
    
    -- Calculate max reasonable curve length (to edge of screen)
    local maxLength = math.min(width, height) / 2
    local curveLength = Dog_ValueBox("Radial Bezier", "Length of Bézier curves:", 50, maxLength, math.min(150, maxLength))
    if curveLength == nil then return end
    
    -- Animation parameters
    local totalFrames = Dog_GetTotalFrames()
    local animateLength = Dog_ValueBox("Radial Bezier", "Animate curve length? (0=No, 1=Yes):", 0, 1, 0)
    if animateLength == nil then return end
    
    local finalLength = curveLength
    if animateLength == 1 then
        finalLength = Dog_ValueBox("Radial Bezier", "Final curve length at end of animation:", 50, maxLength, math.min(250, maxLength))
        if finalLength == nil then return end
    end
    
    local animateRotation = Dog_ValueBox("Radial Bezier", "Animate rotation? (0=No, 1=Yes):", 0, 1, 0)
    if animateRotation == nil then return end
    
    local rotationSpeed = 0
    if animateRotation == 1 then
        rotationSpeed = Dog_ValueBox("Radial Bezier", "Rotation speed (degrees per frame, can be negative):", -30, 30, 3)
        if rotationSpeed == nil then return end
    end
    
    local colorChoice = Dog_ValueBox("Radial Bezier", "Color (1=Red, 2=Green, 3=Blue, 4=White, 5=Cyan, 6=Magenta, 7=Yellow):", 1, 7, 4)
    if colorChoice == nil then return end
    
    -- Use proper 0/1 range for yes/no questions
    local mirrorX = Dog_ValueBox("Radial Bezier", "Mirror on X axis? (0=No, 1=Yes):", 0, 1, 0)
    if mirrorX == nil then return end
    
    local mirrorY = Dog_ValueBox("Radial Bezier", "Mirror on Y axis? (0=No, 1=Yes):", 0, 1, 0)
    if mirrorY == nil then return end
    
    Dog_MessageBox("Creating animated radial Bézier pattern across " .. totalFrames .. " frames...")
    
    -- Save current state
    Dog_SaveUndo()
    
    -- Store original frame
    local originalFrame = Dog_GetCurrentFrame()
    
    -- Function to calculate cubic Bézier curve point
    function calculateBezierPoint(t, p0x, p0y, p1x, p1y, p2x, p2y, p3x, p3y)
        local u = 1 - t
        local tt = t * t
        local uu = u * u
        local uuu = uu * u
        local ttt = tt * t
        
        local x = uuu * p0x + 3 * uu * t * p1x + 3 * u * tt * p2x + ttt * p3x
        local y = uuu * p0y + 3 * uu * t * p1y + 3 * u * tt * p2y + ttt * p3y
        
        return x, y
    end
    
    -- Function to draw a line with thickness (from working scripts)
    function draw_thick_line(x1, y1, x2, y2, thickness, r, g, b)
        -- Calculate the line's direction vector
        local dx = x2 - x1
        local dy = y2 - y1
        local length = math.sqrt(dx*dx + dy*dy)
        
        -- Normalize the direction vector
        if length > 0 then
            dx = dx / length
            dy = dy / length
        else
            return -- Zero-length line, nothing to draw
        end
        
        -- Calculate perpendicular vector
        local px = -dy
        local py = dx
        
        -- Draw the thick line as a series of points
        for t = 0, length, 0.5 do -- Step size of 0.5 for smoother lines
            local x = x1 + t * dx
            local y = y1 + t * dy
            
            -- Draw points perpendicular to the line for thickness
            for thick = -thickness/2, thickness/2, 0.5 do
                local draw_x = math.floor(x + thick * px)
                local draw_y = math.floor(y + thick * py)
                
                -- Check if point is within canvas bounds
                if draw_x >= 0 and draw_x < width and draw_y >= 0 and draw_y < height then
                    set_rgb(draw_x, draw_y, r, g, b)
                end
            end
        end
    end
    
    -- Set curve color based on user choice
    local r, g, b = 1, 1, 1 -- Default white
    if colorChoice == 1 then r, g, b = 1, 0, 0      -- Red
    elseif colorChoice == 2 then r, g, b = 0, 1, 0  -- Green
    elseif colorChoice == 3 then r, g, b = 0, 0, 1  -- Blue
    elseif colorChoice == 4 then r, g, b = 1, 1, 1  -- White
    elseif colorChoice == 5 then r, g, b = 0, 1, 1  -- Cyan
    elseif colorChoice == 6 then r, g, b = 1, 0, 1  -- Magenta
    elseif colorChoice == 7 then r, g, b = 1, 1, 0  -- Yellow
    end
    
    -- Function to draw a single Bézier curve from center
    function drawRadialCurve(angle, length, centerX, centerY, r, g, b)
        -- Convert angle to radians
        local angleRad = angle * 0.01745329 -- PI/180
        
        -- Start point is always center
        local startX = centerX
        local startY = centerY
        
        -- End point based on angle and length
        local endX = centerX + length * math.cos(angleRad)
        local endY = centerY + length * math.sin(angleRad)
        
        -- Control points for nice curve shape
        local control1X = centerX + (length * 0.3) * math.cos(angleRad - 0.5)
        local control1Y = centerY + (length * 0.3) * math.sin(angleRad - 0.5)
        local control2X = centerX + (length * 0.7) * math.cos(angleRad + 0.3)
        local control2Y = centerY + (length * 0.7) * math.sin(angleRad + 0.3)
        
        -- Calculate curve length for adaptive sampling
        local curveLength = math.sqrt((endX - startX)^2 + (endY - startY)^2)
        
        -- Adaptive segment count: aim for one point every 1.5 pixels
        local segments = math.max(20, math.floor(curveLength / 1.5))
        
        -- Draw the curve with smooth lines between points
        local prevX, prevY = nil, nil
        for i = 0, segments do
            local t = i / segments
            local x, y = calculateBezierPoint(t, startX, startY, control1X, control1Y, control2X, control2Y, endX, endY)
            
            -- Draw line from previous point to current point
            if prevX ~= nil and prevY ~= nil then
                draw_thick_line(prevX, prevY, x, y, 2, r, g, b)
            end
            
            prevX, prevY = x, y
        end
    end
    
    -- Process each frame for animation
    for frame = 0, totalFrames - 1 do
        -- Go to current frame
        Dog_GotoFrame(frame)
        
        -- Calculate center of canvas
        local centerX = width / 2
        local centerY = height / 2
        
        -- Calculate animated parameters for this frame
        local frameProgress = frame / (totalFrames - 1) -- 0 to 1
        
        -- Interpolate curve length
        local currentLength = curveLength
        if animateLength == 1 then
            currentLength = curveLength + (finalLength - curveLength) * frameProgress
        end
        
        -- Calculate rotation offset for this frame
        local rotationOffset = 0
        if animateRotation == 1 then
            rotationOffset = frame * rotationSpeed
        end
        
        -- Clear the canvas to black
        for y = 0, height - 1 do
            for x = 0, width - 1 do
                set_rgb(x, y, 0, 0, 0)
            end
        end
        
        -- Calculate angle increment for radial array
        local angleIncrement = 360 / numCurves
        
        -- Draw primary curves with rotation offset
        for i = 0, numCurves - 1 do
            local angle = i * angleIncrement + rotationOffset
            drawRadialCurve(angle, currentLength, centerX, centerY, r, g, b)
        end
        
        -- Draw mirrored curves if requested
        if mirrorX == 1 then
            for i = 0, numCurves - 1 do
                local angle = -(i * angleIncrement) + rotationOffset -- Mirror on X axis
                drawRadialCurve(angle, currentLength, centerX, centerY, r, g, b)
            end
        end
        
        if mirrorY == 1 then
            for i = 0, numCurves - 1 do
                local angle = 180 - (i * angleIncrement) + rotationOffset -- Mirror on Y axis
                drawRadialCurve(angle, currentLength, centerX, centerY, r, g, b)
            end
        end
        
        -- If both mirrors are enabled, draw the fourth quadrant
        if mirrorX == 1 and mirrorY == 1 then
            for i = 0, numCurves - 1 do
                local angle = 180 + (i * angleIncrement) + rotationOffset -- Opposite quadrant
                drawRadialCurve(angle, currentLength, centerX, centerY, r, g, b)
            end
        end
    end
    
    -- Return to original frame
    Dog_GotoFrame(originalFrame)
    
    Dog_MessageBox("Animated radial Bézier pattern complete!")
    
else
    Dog_MessageBox("Please create an animation first!")
end
