-- Smoke_Clean_Light - Frame-by-frame processing (no pre-allocation)

local total_frames = Dog_GetTotalFrames()
if total_frames <= 0 then
    Dog_MessageBox("No Animation Timeline!", "Create animation first")
    return
end

function idx(x, y)
    if x < 0 then x = 0 elseif x >= width then x = width - 1 end
    if y < 0 then y = 0 elseif y >= height then y = height - 1 end
    return y * width + x
end

function create_buffer()
    local b = {}
    for i = 0, width * height - 1 do
        b[i] = 0.0
    end
    return b
end

local density_A = create_buffer()
local density_B = create_buffer()
local vel_x_A = create_buffer()
local vel_x_B = create_buffer()
local vel_y_A = create_buffer()
local vel_y_B = create_buffer()

function swap(a, b)
    return b, a
end

function advect(src, dst, u, v, dt)
    for y = 1, height - 2 do
        for x = 1, width - 2 do
            local i = idx(x, y)
            
            local back_x = x - u[i] * dt
            local back_y = y - v[i] * dt
            
            if back_x < 0.5 then back_x = 0.5 end
            if back_x > width - 1.5 then back_x = width - 1.5 end
            
            if back_y < 0 then
                dst[i] = 0
            elseif back_y >= height then
                back_y = height - 1.5
            else
                if back_y < 0.5 then back_y = 0.5 end
                if back_y > height - 1.5 then back_y = height - 1.5 end
                
                local x0 = math.floor(back_x)
                local x1 = x0 + 1
                local y0 = math.floor(back_y)
                local y1 = y0 + 1
                
                local sx = back_x - x0
                local sy = back_y - y0
                
                local i00 = idx(x0, y0)
                local i10 = idx(x1, y0)
                local i01 = idx(x0, y1)
                local i11 = idx(x1, y1)
                
                dst[i] = (1 - sx) * ((1 - sy) * src[i00] + sy * src[i01]) +
                         sx * ((1 - sy) * src[i10] + sy * src[i11])
            end
        end
    end
end

function diffuse(src, dst, diff_rate, iterations)
    local a = diff_rate * width * height
    local div = 1 + 4 * a
    
    for iter = 1, iterations do
        for y = 1, height - 2 do
            for x = 1, width - 2 do
                local i = idx(x, y)
                local sum = dst[idx(x-1, y)] + dst[idx(x+1, y)] + 
                           dst[idx(x, y-1)] + dst[idx(x, y+1)]
                dst[i] = (src[i] + a * sum) / div
            end
        end
        
        for x = 0, width - 1 do
            dst[idx(x, 0)] = 0
            dst[idx(x, height-1)] = dst[idx(x, height-2)]
        end
        for y = 0, height - 1 do
            dst[idx(0, y)] = dst[idx(1, y)]
            dst[idx(width-1, y)] = dst[idx(width-2, y)]
        end
    end
end

function add_curl_noise(u, v, strength, scale, time_phase)
    for y = 1, height - 2 do
        for x = 1, width - 2 do
            local i = idx(x, y)
            local nx = x / scale
            local ny = y / scale
            
            local curl_x = (math.sin(nx * 3.1 + ny + time_phase) - 
                           math.sin(nx - ny * 2.1 - time_phase)) * strength
            local curl_y = (math.cos(ny * 2.7 + nx + time_phase) - 
                           math.cos(ny - nx * 1.7 + time_phase)) * strength
            
            u[i] = u[i] + curl_x
            v[i] = v[i] + curl_y
        end
    end
end

function apply_global_updraft(v, force, dt)
    for i = 0, width * height - 1 do
        v[i] = v[i] - (force * dt)
    end
end

function apply_expansion(u, v, density, source_x, source_y, base_rate, growth_rate)
    for y = 1, height - 2 do
        for x = 1, width - 2 do
            local i = idx(x, y)
            
            local dx = x - source_x
            local dy = y - source_y
            local distance = math.sqrt(dx * dx + dy * dy) + 1
            
            local expansion = base_rate * math.log(1 + distance * growth_rate)
            
            local grad_x = (density[idx(x+1, y)] - density[idx(x-1, y)]) * 0.5
            local grad_y = (density[idx(x, y+1)] - density[idx(x, y-1)]) * 0.5
            
            u[i] = u[i] + grad_x * expansion
            v[i] = v[i] + grad_y * expansion
        end
    end
end

function add_source_simple(density, u, v, sx, sy, radius, amount, vx, vy, v_rand)
    local r2 = radius * radius
    local min_y = math.max(0, math.floor(sy - radius))
    local max_y = math.min(height - 1, math.floor(sy + radius))
    local min_x = math.max(0, math.floor(sx - radius))
    local max_x = math.min(width - 1, math.floor(sx + radius))

    for y = min_y, max_y do
        for x = min_x, max_x do
            local dx = x - sx
            local dy = y - sy
            local dist2 = dx * dx + dy * dy
            
            if dist2 < r2 then
                local falloff = 1 - dist2 / r2
                
                local i = idx(x, y)
                density[i] = math.min(1.5, density[i] + amount * falloff)
                
                u[i] = u[i] + vx + (math.random() - 0.5) * v_rand
                v[i] = v[i] + vy + (math.random() - 0.5) * v_rand
            end
        end
    end
end

function gaussian_blur_inline(density, radius)
    if radius < 1 then return end
    
    local temp = create_buffer()
    
    local kernel = {}
    local sigma = radius / 2.0
    local sum = 0
    
    for i = -radius, radius do
        for j = -radius, radius do
            local value = math.exp(-(i*i + j*j) / (2 * sigma * sigma))
            kernel[#kernel + 1] = {i, j, value}
            sum = sum + value
        end
    end
    
    for k = 1, #kernel do
        kernel[k][3] = kernel[k][3] / sum
    end
    
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local total = 0
            
            for k = 1, #kernel do
                local offset_x = kernel[k][1]
                local offset_y = kernel[k][2]
                local weight = kernel[k][3]
                
                local sample_x = x + offset_x
                local sample_y = y + offset_y
                
                if sample_x >= 0 and sample_x < width and sample_y >= 0 and sample_y < height then
                    local i_sample = idx(sample_x, sample_y)
                    total = total + density[i_sample] * weight
                end
            end
            
            local i = idx(x, y)
            temp[i] = total
        end
    end
    
    for i = 0, width * height - 1 do
        density[i] = temp[i]
    end
end

function boost_faint_smoke(density, threshold, boost)
    for i = 0, width * height - 1 do
        local d = density[i]
        if d > 0.01 and d < threshold then
            density[i] = d * boost
        end
    end
end

Dog_SaveUndo()

GUI_SetCaption("Smoke - Clean & Light")

GUI_AddControl("TextLabel", "✨ GEMINI SOURCE: Simple, no anda")
GUI_AddControl("TextLabel", "✨ FRAME-BY-FRAME: Light on memory")
GUI_AddControl("TextLabel", "✨ GAUSSIAN BLUR: Smooth texture")
GUI_AddControl("Line")

GUI_AddControl("TextLabel", "SUB-STEPPING")
h_substeps = GUI_AddControl("Scroller", "Sub-Steps", 3, 1, 10)
h_updraft = GUI_AddControl("Scroller", "Updraft", 35, 0, 200)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "SOURCE")
h_src_x = GUI_AddControl("Scroller", "Src X", width/2, 0, width-1)
h_src_y = GUI_AddControl("Scroller", "Src Y", height-50, 0, height-1)
h_radius = GUI_AddControl("Scroller", "Radius", 60, 20, 150)
h_amount = GUI_AddControl("Scroller", "Amount", 80, 30, 200)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "VELOCITY")
h_vel_x = GUI_AddControl("Scroller", "Vel X", 0, -100, 100)
h_vel_y = GUI_AddControl("Scroller", "Vel Y", -60, -200, 20)
h_v_rand = GUI_AddControl("Scroller", "Vel Rand", 30, 0, 100)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "TURBULENCE")
h_turb_s = GUI_AddControl("Scroller", "Turb Str", 50, 0, 100)
h_turb_c = GUI_AddControl("Scroller", "Turb Scl", 50, 10, 200)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "PHYSICS")
h_fade = GUI_AddControl("Scroller", "Fade", 2, 0, 100)
h_diff = GUI_AddControl("Scroller", "Diffusion", 10, 0, 50)
h_exp_base = GUI_AddControl("Scroller", "Expansion", 30, 0, 100)
h_exp_growth = GUI_AddControl("Scroller", "Exp Growth", 40, 10, 150)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "POST-PROCESSING")
h_boost_thresh = GUI_AddControl("Scroller", "Boost Threshold", 30, 0, 100)
h_boost_mult = GUI_AddControl("Scroller", "Boost Multiplier", 150, 100, 300)
h_blur_rad = GUI_AddControl("Scroller", "Blur Radius", 2, 0, 5)

GUI_OpenPanel()

local substeps = 3
local updraft = 35
local src_x = width / 2
local src_y = height - 50
local radius = 60
local amount = 80
local vel_x_val = 0
local vel_y_val = -60
local v_rand = 30
local turb_str = 50
local turb_scl = 50
local fade = 2
local diff = 10
local exp_base = 30
local exp_growth = 40
local boost_thresh = 30
local boost_mult = 150
local blur_rad = 2

repeat
    idx_gui, retval, retstr = GUI_WaitOnEvent()
    
    if idx_gui == h_substeps then substeps = GUI_GetSettings(h_substeps)
    elseif idx_gui == h_updraft then updraft = GUI_GetSettings(h_updraft)
    elseif idx_gui == h_src_x then src_x = GUI_GetSettings(h_src_x)
    elseif idx_gui == h_src_y then src_y = GUI_GetSettings(h_src_y)
    elseif idx_gui == h_radius then radius = GUI_GetSettings(h_radius)
    elseif idx_gui == h_amount then amount = GUI_GetSettings(h_amount)
    elseif idx_gui == h_vel_x then vel_x_val = GUI_GetSettings(h_vel_x)
    elseif idx_gui == h_vel_y then vel_y_val = GUI_GetSettings(h_vel_y)
    elseif idx_gui == h_v_rand then v_rand = GUI_GetSettings(h_v_rand)
    elseif idx_gui == h_turb_s then turb_str = GUI_GetSettings(h_turb_s)
    elseif idx_gui == h_turb_c then turb_scl = GUI_GetSettings(h_turb_c)
    elseif idx_gui == h_fade then fade = GUI_GetSettings(h_fade)
    elseif idx_gui == h_diff then diff = GUI_GetSettings(h_diff)
    elseif idx_gui == h_exp_base then exp_base = GUI_GetSettings(h_exp_base)
    elseif idx_gui == h_exp_growth then exp_growth = GUI_GetSettings(h_exp_growth)
    elseif idx_gui == h_boost_thresh then boost_thresh = GUI_GetSettings(h_boost_thresh)
    elseif idx_gui == h_boost_mult then boost_mult = GUI_GetSettings(h_boost_mult)
    elseif idx_gui == h_blur_rad then blur_rad = GUI_GetSettings(h_blur_rad)
    end
    
until idx_gui < 0

GUI_ClosePanel()

if idx_gui == -2 then return end

Dog_MessageBox("Starting Light Smoke Sim!",
              substeps .. "x sub-stepping",
              "Updraft: " .. updraft,
              "Blur radius: " .. blur_rad,
              "Frame-by-frame processing")

local dt = 1.0
math.randomseed(os.time())

for frame = 0, total_frames - 1 do
    Dog_GotoFrame(frame)
    
    for step = 1, substeps do
        local substep_time = (frame * substeps + step) * 0.05
        
        if step == 1 then
            add_source_simple(density_A, vel_x_A, vel_y_A, src_x, src_y, radius,
                            amount / 100, vel_x_val / 3, vel_y_val / 3, v_rand / 10)
        end
        
        apply_global_updraft(vel_y_A, updraft / 100, dt)
        
        add_curl_noise(vel_x_A, vel_y_A, turb_str / 40, turb_scl, substep_time)
        
        apply_expansion(vel_x_A, vel_y_A, density_A, src_x, src_y,
                       exp_base / 100, exp_growth / 100)
        
        advect(vel_x_A, vel_x_B, vel_x_A, vel_y_A, dt)
        advect(vel_y_A, vel_y_B, vel_x_A, vel_y_A, dt)
        vel_x_A, vel_x_B = swap(vel_x_A, vel_x_B)
        vel_y_A, vel_y_B = swap(vel_y_A, vel_y_B)
        
        if diff > 0 then
            diffuse(density_A, density_B, diff / 10000, 2)
            density_A, density_B = swap(density_A, density_B)
        end
        
        advect(density_A, density_B, vel_x_A, vel_y_A, dt)
        density_A, density_B = swap(density_A, density_B)
        
        for i = 0, width * height - 1 do
            density_A[i] = density_A[i] * 0.998
        end
    end
    
    if boost_thresh > 0 then
        boost_faint_smoke(density_A, boost_thresh / 100, boost_mult / 100)
    end
    
    if blur_rad > 0 then
        gaussian_blur_inline(density_A, blur_rad)
    end
    
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local i = idx(x, y)
            local d = density_A[i]
            
            if d > 1.0 then d = 1.0 end
            if d < 0.0 then d = 0.0 end
            
            set_rgb(x, y, d, d, d)
        end
    end
    
    if frame % 2 == 0 then
        progress(frame / total_frames)
    end
end

Dog_GotoFrame(0)
progress(0)

Dog_MessageBox("Light Smoke Complete! ✨",
              "No anda (simple source)",
              "Faint smoke boosted",
              "Gaussian blur applied",
              "Memory efficient!")
