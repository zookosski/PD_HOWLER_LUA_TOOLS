local total_frames = Dog_GetTotalFrames()
if total_frames <= 0 then
    Dog_MessageBox("No Animation Timeline!", "Create animation first")
    return
end

local scale_factor = height / 512

math.randomseed(os.time())

local particles = {}
local particle_count = 0

function spawn_particle(x, y, vx, vy, life, r, g, b, size)
    particle_count = particle_count + 1
    particles[particle_count] = {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        life = life,
        max_life = life,
        r = r,
        g = g,
        b = b,
        size = size or 1
    }
end

function update_particles(dt, gravity)
    local alive = {}
    local alive_count = 0
    
    for i = 1, particle_count do
        local p = particles[i]
        
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + gravity * dt
        p.life = p.life - 1
        
        if p.life > 0 and p.x >= 0 and p.x < width and p.y >= 0 and p.y < height then
            alive_count = alive_count + 1
            alive[alive_count] = p
        end
    end
    
    particles = alive
    particle_count = alive_count
end

function render_particles(trail_fade)
    for i = 1, particle_count do
        local p = particles[i]
        
        local fade = p.life / p.max_life
        local brightness = fade * 2.0
        
        if brightness > 1.0 then brightness = 1.0 end
        
        local x = math.floor(p.x)
        local y = math.floor(p.y)
        
        if x >= 0 and x < width and y >= 0 and y < height then
            local existing_r, existing_g, existing_b = get_rgb(x, y)
            
            local new_r = math.min(1, existing_r * trail_fade + p.r * brightness)
            local new_g = math.min(1, existing_g * trail_fade + p.g * brightness)
            local new_b = math.min(1, existing_b * trail_fade + p.b * brightness)
            
            set_rgb(x, y, new_r, new_g, new_b)
            
            if p.size > 1 then
                local radius = math.floor(p.size)
                for dx = -radius, radius do
                    for dy = -radius, radius do
                        if dx*dx + dy*dy <= radius*radius then
                            local nx = x + dx
                            local ny = y + dy
                            if nx >= 0 and nx < width and ny >= 0 and ny < height then
                                local dist_fade = 1 - math.sqrt(dx*dx + dy*dy) / radius
                                local br = brightness * dist_fade * 0.8
                                local er, eg, eb = get_rgb(nx, ny)
                                set_rgb(nx, ny, 
                                    math.min(1, er * trail_fade + p.r * br),
                                    math.min(1, eg * trail_fade + p.g * br),
                                    math.min(1, eb * trail_fade + p.b * br))
                            end
                        end
                    end
                end
            end
        end
    end
end

function explode(x, y, count, force, life, r, g, b, variation, size)
    for i = 1, count do
        local angle = (math.random() * 2 * math.pi)
        local speed = force * (0.5 + math.random() * 0.5)
        
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        
        local color_var = 1 - variation + math.random() * variation * 2
        local pr = math.min(1, r * color_var)
        local pg = math.min(1, g * color_var)
        local pb = math.min(1, b * color_var)
        
        spawn_particle(x, y, vx, vy, life, pr, pg, pb, size)
    end
end

Dog_SaveUndo()

GUI_SetCaption("Fireworks - Particle System")

GUI_AddControl("TextLabel", "SIMULATION")
h_substeps = GUI_AddControl("Scroller", "Sub-Steps", 4, 1, 10)
h_gravity = GUI_AddControl("Scroller", "Gravity", 15, 0, 50)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "START POSITION")
h_start_x = GUI_AddControl("Scroller", "Start X", width/2, 0, width-1)
h_start_y = GUI_AddControl("Scroller", "Start Y", height/2, 0, height-1)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "LAUNCH")
h_rockets = GUI_AddControl("Scroller", "Rkt/Frame", 3, 0, 10)
h_launch_speed = GUI_AddControl("Scroller", "L-Speed", 80, 0, 150)
h_launch_spread = GUI_AddControl("Scroller", "L-Spread", 30, 0, 100)
h_fuse_time = GUI_AddControl("Scroller", "Fuse", 25, 0, 60)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "EXPLOSION")
h_spark_count = GUI_AddControl("Scroller", "Spark Cnt", 200, 50, 500)
h_burst_force = GUI_AddControl("Scroller", "Burst Frc", 30, 10, 100)
h_spark_life = GUI_AddControl("Scroller", "Spark Life", 30, 10, 80)

GUI_AddControl("Line")
GUI_AddControl("TextLabel", "VISUALS")
h_particle_size = GUI_AddControl("Scroller", "Part Size", 3, 1, 8)
h_trail_fade = GUI_AddControl("Scroller", "Trail Fade", 90, 50, 99)
h_color_var = GUI_AddControl("Scroller", "Color Var", 30, 0, 100)

GUI_OpenPanel()

local substeps = 4
local gravity = 15
local start_x = width / 2
local start_y = height / 2
local rockets_per = 3
local launch_speed = 80
local launch_spread = 30
local fuse_time = 25
local spark_count = 200
local burst_force = 30
local spark_life = 30
local particle_size = 3
local trail_fade = 90
local color_var = 30

repeat
    idx_gui, retval, retstr = GUI_WaitOnEvent()
    
    if idx_gui == h_substeps then substeps = GUI_GetSettings(h_substeps)
    elseif idx_gui == h_gravity then gravity = GUI_GetSettings(h_gravity)
    elseif idx_gui == h_start_x then start_x = GUI_GetSettings(h_start_x)
    elseif idx_gui == h_start_y then start_y = GUI_GetSettings(h_start_y)
    elseif idx_gui == h_rockets then rockets_per = GUI_GetSettings(h_rockets)
    elseif idx_gui == h_launch_speed then launch_speed = GUI_GetSettings(h_launch_speed)
    elseif idx_gui == h_launch_spread then launch_spread = GUI_GetSettings(h_launch_spread)
    elseif idx_gui == h_fuse_time then fuse_time = GUI_GetSettings(h_fuse_time)
    elseif idx_gui == h_spark_count then spark_count = GUI_GetSettings(h_spark_count)
    elseif idx_gui == h_burst_force then burst_force = GUI_GetSettings(h_burst_force)
    elseif idx_gui == h_spark_life then spark_life = GUI_GetSettings(h_spark_life)
    elseif idx_gui == h_particle_size then particle_size = GUI_GetSettings(h_particle_size)
    elseif idx_gui == h_trail_fade then trail_fade = GUI_GetSettings(h_trail_fade)
    elseif idx_gui == h_color_var then color_var = GUI_GetSettings(h_color_var)
    end
until idx_gui < 0

GUI_ClosePanel()

if idx_gui == -2 then return end

Dog_MessageBox("Starting Fireworks!",
              "Canvas: " .. width .. "x" .. height,
              "Scale: " .. string.format("%.2f", scale_factor) .. "x",
              spark_count .. " sparks per burst")

local dt = 1.0
local rockets = {}
local rocket_count = 0

local colors = {
    {1.0, 0.2, 0.2},
    {0.2, 1.0, 0.2},
    {0.2, 0.2, 1.0},
    {1.0, 1.0, 0.2},
    {1.0, 0.2, 1.0},
    {0.2, 1.0, 1.0},
    {1.0, 0.5, 0.0},
    {1.0, 1.0, 1.0}
}

local scaled_particle_size = particle_size * scale_factor

for frame = 0, total_frames - 1 do
    Dog_GotoFrame(frame)
    
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            set_rgb(x, y, 0, 0, 0)
        end
    end
    
    if rockets_per > 0 then
        if math.random() < rockets_per / 10 then
            for r = 1, rockets_per do
                local launch_x = start_x + (math.random() - 0.5) * launch_spread * scale_factor * 2
                local launch_vx = (math.random() - 0.5) * launch_spread * scale_factor / 10
                local launch_vy = -launch_speed * scale_factor / 10
                
                local color_idx = math.random(1, #colors)
                local color = colors[color_idx]
                
                rocket_count = rocket_count + 1
                rockets[rocket_count] = {
                    x = launch_x,
                    y = start_y,
                    vx = launch_vx,
                    vy = launch_vy,
                    fuse = fuse_time,
                    r = color[1],
                    g = color[2],
                    b = color[3]
                }
            end
        end
    else
        if frame == 0 then
            local color_idx = math.random(1, #colors)
            local color = colors[color_idx]
            explode(start_x, start_y, spark_count, burst_force * scale_factor / 10, 
                   spark_life, color[1], color[2], color[3], color_var / 100, scaled_particle_size)
        end
    end
    
    for step = 1, substeps do
        local substep_dt = dt / substeps
        
        update_particles(substep_dt, gravity * scale_factor / 10)
        
        local alive_rockets = {}
        local alive_rocket_count = 0
        
        for i = 1, rocket_count do
            local rkt = rockets[i]
            
            rkt.x = rkt.x + rkt.vx * substep_dt
            rkt.y = rkt.y + rkt.vy * substep_dt
            rkt.vy = rkt.vy + (gravity * scale_factor / 10) * substep_dt
            rkt.fuse = rkt.fuse - 1
            
            spawn_particle(rkt.x, rkt.y, 0, 0, 3, rkt.r, rkt.g, rkt.b, scaled_particle_size * 1.5)
            
            if rkt.fuse <= 0 then
                explode(rkt.x, rkt.y, spark_count, burst_force * scale_factor / 10, 
                       spark_life, rkt.r, rkt.g, rkt.b, color_var / 100, scaled_particle_size)
            elseif rkt.y >= 0 and rkt.y < height then
                alive_rocket_count = alive_rocket_count + 1
                alive_rockets[alive_rocket_count] = rkt
            end
        end
        
        rockets = alive_rockets
        rocket_count = alive_rocket_count
    end
    
    render_particles(trail_fade / 100)
    
    if frame % 3 == 0 then
        progress(frame / total_frames)
    end
end

Dog_GotoFrame(0)
progress(0)

Dog_MessageBox("Fireworks Complete!",
              "Brighter, denser bursts!",
              "Ready for your zoom blur!")