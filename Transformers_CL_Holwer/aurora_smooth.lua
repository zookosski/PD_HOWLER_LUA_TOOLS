local totalFrames = Dog_GetTotalFrames()

if totalFrames <= 0 then
    Dog_MessageBox("Please create an animation first!")
    return
end

Dog_SaveUndo()

GUI_SetCaption("Aurora Borealis - Smooth")
GUI_AddControl("TextLabel", "Aurora Settings")
local h_columns = GUI_AddControl("Scroller", "Light Columns", 8, 4, 20)
local h_waveSpeed = GUI_AddControl("Scroller", "Wave Speed", 50, 10, 100)
local h_waveAmp = GUI_AddControl("Scroller", "Wave Amplitude", 50, 10, 100)
local h_intensity = GUI_AddControl("Scroller", "Glow Intensity", 70, 30, 100)
GUI_AddControl("Line")
GUI_AddControl("TextLabel", "Color Palette")
local h_palette = GUI_AddControl("Combobox", "Aurora Colors")
GUI_SetList(h_palette, 0, "Classic Green")
GUI_SetList(h_palette, 1, "Blue-Purple")
GUI_SetList(h_palette, 2, "Pink-Violet")
GUI_SetList(h_palette, 3, "Full Spectrum")
GUI_SetSettings(h_palette, 0, "Classic Green")
GUI_AddControl("Line")
local h_preview = GUI_AddControl("Button", "Preview Frame 15")
local h_animate = GUI_AddControl("Button", "Generate Animation")

GUI_OpenPanel()

local columns = 8
local waveSpeed = 50
local waveAmp = 50
local intensity = 70
local paletteIdx = 0

local palettes = {
    {
        {0.0, 0.3, 0.1}, {0.1, 0.6, 0.2}, {0.2, 0.9, 0.4}, 
        {0.3, 1.0, 0.6}, {0.4, 0.9, 0.7}, {0.2, 0.7, 0.5}
    },
    {
        {0.0, 0.1, 0.3}, {0.1, 0.3, 0.6}, {0.2, 0.5, 0.9},
        {0.4, 0.3, 0.8}, {0.6, 0.4, 0.9}, {0.5, 0.2, 0.7}
    },
    {
        {0.3, 0.0, 0.2}, {0.6, 0.1, 0.4}, {0.9, 0.2, 0.6},
        {0.8, 0.3, 0.8}, {0.7, 0.4, 0.9}, {0.6, 0.2, 0.7}
    },
    {
        {0.0, 0.3, 0.2}, {0.1, 0.6, 0.5}, {0.3, 0.8, 0.9},
        {0.5, 0.5, 0.9}, {0.8, 0.3, 0.7}, {0.9, 0.5, 0.5}
    }
}

local function getColorFromPalette(t, palette)
    t = math.max(0, math.min(1, t))
    local n = #palette
    local segment = t * (n - 1)
    local i1 = math.max(1, math.min(n, math.floor(segment) + 1))
    local i2 = math.max(1, math.min(n, i1 + 1))
    local blend = segment - math.floor(segment)
    
    local c1 = palette[i1]
    local c2 = palette[i2]
    
    return 
        c1[1] * (1 - blend) + c2[1] * blend,
        c1[2] * (1 - blend) + c2[2] * blend,
        c1[3] * (1 - blend) + c2[3] * blend
end

local auroraColumns = {}

local function initializeColumns()
    auroraColumns = {}
    for i = 1, columns do
        auroraColumns[i] = {
            baseX = (i / (columns + 1)) * width,
            waveFreq1 = 0.5 + math.random() * 1.5,
            waveFreq2 = 0.3 + math.random() * 1.0,
            phase1 = math.random() * math.pi * 2,
            phase2 = math.random() * math.pi * 2,
            width = 40 + math.random() * 80,
            colorOffset = (i - 1) / columns
        }
    end
end

local function renderFrame(frameNum)
    local t = frameNum / 60.0
    local palette = palettes[paletteIdx + 1]
    local speedMult = waveSpeed / 50
    local ampMult = waveAmp / 50
    local intensityMult = intensity / 70
    
    for y = 0, height - 1 do
        local yNorm = y / height
        
        for x = 0, width - 1 do
            local r, g, b = 0, 0, 0
            
            for i = 1, #auroraColumns do
                local col = auroraColumns[i]
                
                local wave1 = math.sin(yNorm * col.waveFreq1 * math.pi * 2 + t * speedMult + col.phase1) * ampMult * 60
                local wave2 = math.sin(yNorm * col.waveFreq2 * math.pi * 2 + t * speedMult * 0.7 + col.phase2) * ampMult * 40
                
                local columnX = col.baseX + wave1 + wave2
                
                local dist = math.abs(x - columnX)
                
                if dist < col.width then
                    local falloff = 1 - (dist / col.width)
                    falloff = falloff * falloff
                    
                    local verticalFade = math.sin(yNorm * math.pi)
                    
                    local colorT = (col.colorOffset + yNorm * 0.3) % 1.0
                    local cr, cg, cb = getColorFromPalette(colorT, palette)
                    
                    local strength = falloff * verticalFade * intensityMult
                    
                    r = r + cr * strength
                    g = g + cg * strength
                    b = b + cb * strength
                end
            end
            
            r = math.min(1, r)
            g = math.min(1, g)
            b = math.min(1, b)
            
            set_rgb(x, y, r, g, b)
        end
        
        if y % 20 == 0 then
            progress((frameNum * height + y) / (totalFrames * height))
        end
    end
end

initializeColumns()

repeat
    idx, retval, retstr = GUI_WaitOnEvent()
    
    if idx == h_columns then
        columns = GUI_GetSettings(h_columns)
        initializeColumns()
    elseif idx == h_waveSpeed then
        waveSpeed = GUI_GetSettings(h_waveSpeed)
    elseif idx == h_waveAmp then
        waveAmp = GUI_GetSettings(h_waveAmp)
    elseif idx == h_intensity then
        intensity = GUI_GetSettings(h_intensity)
    elseif idx == h_palette then
        paletteIdx = GUI_GetSettings(h_palette)
    elseif idx == h_preview then
        renderFrame(15)
        Dog_Refresh()
        flush()
    elseif idx == h_animate then
        for frame = 0, totalFrames - 1 do
            Dog_GotoFrame(frame)
            renderFrame(frame)
            Dog_Refresh()
        end
        
        progress(0)
        Dog_MessageBox("Aurora animation complete!")
        break
    end
    
until idx < 0

GUI_ClosePanel()

if idx == -2 then
    Dog_RestoreUndo()
    Dog_GetBuffer()
    Dog_Refresh()
end
