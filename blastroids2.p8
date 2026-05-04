pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- blastroids 2
-- pico-8 asteroids clone

-- player ship
player = {
    x = 64,
    y = 64,
    grid_x = 1, -- center screen
    grid_y = 1, -- center screen
    angle = 0,
    dx = 0,
    dy = 0,
    thrust = 0.15,
    drag = 0.95,
    turn_speed = 0.05
}

-- asteroids
asteroids = {}

-- bullets
bullets = {}
fire_cooldown = 0

-- game state
score = 0
lives = 3
wave = 1
game_over = false
respawn_timer = 0

-- particles
particles = {}

-- screen shake
shake = 0

-- chain lightning weapon
lightning_cooldown = 0
lightning_max_cooldown = 120 -- 4 seconds
lightning_arcs = {} -- active lightning effects

-- bullet animation
bullet_flash_timer = 0

function spawn_asteroid(x, y, size, dx, dy, gx, gy)
    add(asteroids, {
        x = x or rnd(128),
        y = y or rnd(128),
        grid_x = gx or flr(rnd(3)), -- 0-2
        grid_y = gy or flr(rnd(3)), -- 0-2
        size = size or 3, -- 3=large, 2=medium, 1=small
        dx = dx or rnd(2) - 1,
        dy = dy or rnd(2) - 1,
        rot = rnd(1),
        drot = rnd(0.04) - 0.02
    })
end

function fire_bullet()
    add(bullets, {
        x = player.x + cos(player.angle) * 4,
        y = player.y + sin(player.angle) * 4,
        grid_x = player.grid_x,
        grid_y = player.grid_y,
        dx = cos(player.angle) * 3 + player.dx,
        dy = sin(player.angle) * 3 + player.dy,
        life = 30,
        flash = 0 -- animation counter
    })
    sfx(0) -- shoot sound
end

function fire_lightning()
    if lightning_cooldown > 0 then return end

    -- find nearest asteroid in current screen
    local target = find_nearest_asteroid(player.x, player.y, player.grid_x, player.grid_y)
    if not target then return end

    -- create chain lightning effect
    local hits = {}
    add(hits, target)

    -- chain to additional asteroids
    for i = 1, 2 do -- chain up to 2 more times
        local last = hits[#hits]
        local next_target = find_nearest_asteroid(last.x, last.y, last.grid_x, last.grid_y, hits)
        if next_target then
            add(hits, next_target)
        else
            break
        end
    end

    -- damage and create visual arcs
    for i = 1, #hits do
        local a = hits[i]
        local damage = 4 - i -- damage decreases with each jump

        -- create arc effect
        local prev_x, prev_y = player.x, player.y
        if i > 1 then
            prev_x, prev_y = hits[i-1].x, hits[i-1].y
        end

        add(lightning_arcs, {
            x1 = prev_x,
            y1 = prev_y,
            x2 = a.x,
            y2 = a.y,
            life = 10,
            intensity = 1
        })

        -- apply damage
        a.health = (a.health or a.size * 2) - damage
        if a.health <= 0 then
            -- destroy asteroid
            if a.size == 3 then score += 20
            elseif a.size == 2 then score += 50
            else score += 100 end

            spawn_particles(a.x, a.y, 8 + a.size * 3, 12) -- light blue particles
            shake = 3 + a.size

            if a.size > 1 then
                local speed = 1.5
                spawn_asteroid(a.x, a.y, a.size - 1, rnd(speed) - speed / 2, rnd(speed) - speed / 2, a.grid_x, a.grid_y)
                spawn_asteroid(a.x, a.y, a.size - 1, rnd(speed) - speed / 2, rnd(speed) - speed / 2, a.grid_x, a.grid_y)
            end
            del(asteroids, a)
        end
    end

    lightning_cooldown = lightning_max_cooldown
    shake = 4
    sfx(3) -- lightning sound
end

function find_nearest_asteroid(x, y, gx, gy, exclude)
    local nearest = nil
    local min_dist = 9999
    exclude = exclude or {}

    for a in all(asteroids) do
        -- only check asteroids in same screen
        if a.grid_x == gx and a.grid_y == gy then
            -- check if not in exclude list
            local excluded = false
            for e in all(exclude) do
                if e == a then excluded = true break end
            end

            if not excluded then
                local dx = a.x - x
                local dy = a.y - y
                local dist = dx * dx + dy * dy
                if dist < min_dist then
                    min_dist = dist
                    nearest = a
                end
            end
        end
    end

    return nearest
end

function check_spawn_safe()
    for a in all(asteroids) do
        if a.grid_x == 1 and a.grid_y == 1 then
            if check_collision(64, 64, 10, a.x, a.y, a.size * 4) then
                return false
            end
        end
    end
    return true
end

function spawn_particles(x, y, count, col)
    for i = 1, count do
        add(particles, {
            x = x,
            y = y,
            dx = rnd(2) - 1,
            dy = rnd(2) - 1,
            life = 15 + rnd(10),
            col = col or 7
        })
    end
end

function _init()
    -- reset player position to center screen
    player.grid_x = 1
    player.grid_y = 1
    player.x = 64
    player.y = 64
    player.dx = 0
    player.dy = 0
    player.angle = 0

    -- clear all game objects
    asteroids = {}
    bullets = {}
    lightning_arcs = {}
    particles = {}

    -- spawn asteroids across all 9 screens
    for i = 1, 12 do
        spawn_asteroid()
    end
end

function _update()
    if game_over then
        -- restart on button press
        if btnp(4) then
            _init()
            game_over = false
            score = 0
            lives = 3
            wave = 1
        end
        return
    end

    -- handle respawn timer
    if respawn_timer > 0 then
        respawn_timer -= 1

        -- limit shake to first 30 frames (~1 second) during respawn only
        -- respawn_timer starts at 60, so when it hits 30 we've shaken for 30 frames
        if respawn_timer == 30 and not game_over then
            shake = 0
        end

        if respawn_timer == 0 then
            -- check if spawn location is safe
            if check_spawn_safe() then
                player.x = 64
                player.y = 64
                player.grid_x = 1
                player.grid_y = 1
                player.dx = 0
                player.dy = 0
                player.angle = 0
            else
                -- delay respawn if not safe
                respawn_timer = 30
            end
        end
    end

    -- handle input (skip if respawning)
    if respawn_timer == 0 then
    if btn(0) then -- left
        player.angle += player.turn_speed
    end
    if btn(1) then -- right
        player.angle -= player.turn_speed
    end
    if btn(2) then -- up (thrust)
        player.dx += cos(player.angle) * player.thrust
        player.dy += sin(player.angle) * player.thrust
        -- thrust particles
        if rnd(1) < 0.3 then
            spawn_particles(player.x - cos(player.angle) * 4, player.y - sin(player.angle) * 4, 1, 9)
        end
    end
    if btnp(4) and fire_cooldown == 0 then -- x button
        fire_bullet()
        fire_cooldown = 10
    end
    if btnp(5) then -- o button
        fire_lightning()
    end

    -- update cooldowns
    if fire_cooldown > 0 then
        fire_cooldown -= 1
    end
    if lightning_cooldown > 0 then
        lightning_cooldown -= 1
    end

    -- update bullet flash timer
    bullet_flash_timer += 1

    -- apply drag
    player.dx *= player.drag
    player.dy *= player.drag

    -- update position
    player.x += player.dx
    player.y += player.dy

    -- multi-screen wrapping
    if player.x < 0 then
        player.x = 127
        if player.grid_x > 0 then
            player.grid_x -= 1
        else
            player.grid_x = 2 -- wrap to right edge
        end
    end
    if player.x > 127 then
        player.x = 0
        if player.grid_x < 2 then
            player.grid_x += 1
        else
            player.grid_x = 0 -- wrap to left edge
        end
    end
    if player.y < 0 then
        player.y = 127
        if player.grid_y > 0 then
            player.grid_y -= 1
        else
            player.grid_y = 2 -- wrap within column
        end
    end
    if player.y > 127 then
        player.y = 0
        if player.grid_y < 2 then
            player.grid_y += 1
        else
            player.grid_y = 0 -- wrap within column
        end
    end
    end -- end of respawn_timer == 0 check

    -- update asteroids
    for a in all(asteroids) do
        a.x += a.dx
        a.y += a.dy
        a.rot += a.drot

        -- multi-screen wrapping
        if a.x < 0 then
            a.x = 127
            if a.grid_x > 0 then a.grid_x -= 1 else a.grid_x = 2 end
        end
        if a.x > 127 then
            a.x = 0
            if a.grid_x < 2 then a.grid_x += 1 else a.grid_x = 0 end
        end
        if a.y < 0 then
            a.y = 127
            if a.grid_y > 0 then a.grid_y -= 1 else a.grid_y = 2 end
        end
        if a.y > 127 then
            a.y = 0
            if a.grid_y < 2 then a.grid_y += 1 else a.grid_y = 0 end
        end

        -- collision with player (only in same screen)
        if respawn_timer == 0 and a.grid_x == player.grid_x and a.grid_y == player.grid_y and check_collision(player.x, player.y, 4, a.x, a.y, a.size * 4) then
            lives -= 1
            spawn_particles(player.x, player.y, 20, 8)
            shake = 16
            sfx(2) -- death sound
            if lives <= 0 then
                game_over = true
            else
                -- respawn player after delay
                respawn_timer = 60
                -- move player off screen during respawn
                player.x = -100
                player.y = -100
            end
        end
    end

    -- update bullets
    for b in all(bullets) do
        b.x += b.dx
        b.y += b.dy
        b.life -= 1
        b.flash += 1

        -- multi-screen wrapping
        if b.x < 0 then
            b.x = 127
            if b.grid_x > 0 then b.grid_x -= 1 else b.grid_x = 2 end
        end
        if b.x > 127 then
            b.x = 0
            if b.grid_x < 2 then b.grid_x += 1 else b.grid_x = 0 end
        end
        if b.y < 0 then
            b.y = 127
            if b.grid_y > 0 then b.grid_y -= 1 else b.grid_y = 2 end
        end
        if b.y > 127 then
            b.y = 0
            if b.grid_y < 2 then b.grid_y += 1 else b.grid_y = 0 end
        end

        -- check collision with asteroids (only in same screen)
        for a in all(asteroids) do
            if b.grid_x == a.grid_x and b.grid_y == a.grid_y and check_collision(b.x, b.y, 1, a.x, a.y, a.size * 4) then
                -- add score based on size
                if a.size == 3 then score += 20
                elseif a.size == 2 then score += 50
                else score += 100 end

                -- explosion particles
                spawn_particles(a.x, a.y, 8 + a.size * 3, 6)
                shake = 3 + a.size
                sfx(1) -- explosion sound

                -- split or destroy asteroid
                if a.size > 1 then
                    -- spawn 2 smaller asteroids
                    local speed = 1.5
                    spawn_asteroid(a.x, a.y, a.size - 1, rnd(speed) - speed / 2, rnd(speed) - speed / 2, a.grid_x, a.grid_y)
                    spawn_asteroid(a.x, a.y, a.size - 1, rnd(speed) - speed / 2, rnd(speed) - speed / 2, a.grid_x, a.grid_y)
                end
                del(asteroids, a)
                del(bullets, b)
                break
            end
        end

        -- remove if expired
        if b.life <= 0 then
            del(bullets, b)
        end
    end

    -- update particles
    for p in all(particles) do
        p.x += p.dx
        p.y += p.dy
        p.life -= 1
        if p.life <= 0 then
            del(particles, p)
        end
    end

    -- update lightning arcs
    for l in all(lightning_arcs) do
        l.life -= 1
        l.intensity = l.life / 10 -- fade out
        if l.life <= 0 then
            del(lightning_arcs, l)
        end
    end

    -- update screen shake
    if shake > 0 then
        shake -= 1
    end

    -- check for wave complete
    if #asteroids == 0 and not game_over then
        wave += 1
        for i = 1, 3 + wave do
            spawn_asteroid()
        end
    end
end

function draw_asteroid(a)
    local r = a.size * 4
    local pts = 8
    for i = 0, pts - 1 do
        local a1 = a.rot + i / pts
        local a2 = a.rot + (i + 1) / pts
        local r1 = r + cos(i * 0.7) * r * 0.3
        local r2 = r + cos((i + 1) * 0.7) * r * 0.3
        local x1 = a.x + cos(a1) * r1
        local y1 = a.y + sin(a1) * r1
        local x2 = a.x + cos(a2) * r2
        local y2 = a.y + sin(a2) * r2
        line(x1, y1, x2, y2, 6)
    end
end

function check_collision(x1, y1, r1, x2, y2, r2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy < (r1 + r2) * (r1 + r2)
end

function _draw()
    cls(0)

    -- apply screen shake
    local shake_x = 0
    local shake_y = 0
    if shake > 0 then
        shake_x = rnd(shake) - shake / 2
        shake_y = rnd(shake) - shake / 2
        camera(shake_x, shake_y)
    end

    -- draw asteroids (only in current screen)
    for a in all(asteroids) do
        if a.grid_x == player.grid_x and a.grid_y == player.grid_y then
            draw_asteroid(a)
        end
    end

    -- draw particles
    for p in all(particles) do
        pset(p.x, p.y, p.col)
    end

    -- draw bullets (only in current screen) with flashing effect
    for b in all(bullets) do
        if b.grid_x == player.grid_x and b.grid_y == player.grid_y then
            -- cycle through bright colors for arcade effect
            local flash_cycle = b.flash % 4
            local col = 7 -- white
            if flash_cycle == 1 then col = 10 -- yellow
            elseif flash_cycle == 2 then col = 7 -- white
            elseif flash_cycle == 3 then col = 12 end -- light blue

            -- draw as 2x2 pixel on bright frames
            if flash_cycle == 0 or flash_cycle == 2 then
                rectfill(b.x, b.y, b.x + 1, b.y + 1, col)
            else
                pset(b.x, b.y, col)
            end
        end
    end

    -- draw lightning arcs with animated effect
    for l in all(lightning_arcs) do
        -- draw multiple offset lines for thickness
        local cols = {7, 12, 1} -- white, light blue, dark blue
        for i = 1, 3 do
            local offset = (i - 2) * 0.5
            local col = cols[i]
            if l.intensity < 0.5 then col = 1 end -- fade to dark blue

            -- add random jitter to arcs for lightning effect
            local jx1 = l.x1 + rnd(2) - 1
            local jy1 = l.y1 + rnd(2) - 1
            local jx2 = l.x2 + rnd(2) - 1
            local jy2 = l.y2 + rnd(2) - 1

            line(jx1, jy1, jx2, jy2, col)
        end
    end

    -- draw ship as triangle (only if not respawning)
    if respawn_timer == 0 then
        local size = 4
        local x1 = player.x + cos(player.angle) * size
        local y1 = player.y + sin(player.angle) * size
        local x2 = player.x + cos(player.angle + 0.6) * size
        local y2 = player.y + sin(player.angle + 0.6) * size
        local x3 = player.x + cos(player.angle - 0.6) * size
        local y3 = player.y + sin(player.angle - 0.6) * size

        line(x1, y1, x2, y2, 7)
        line(x2, y2, x3, y3, 7)
        line(x3, y3, x1, y1, 7)
    elseif respawn_timer > 0 and respawn_timer % 10 < 5 then
        -- blinking respawn indicator
        circfill(64, 64, 2, 10)
    end

    -- reset camera for HUD
    camera()

    -- draw HUD
    print("score: " .. score, 2, 2, 7)
    print("lives: " .. lives, 2, 8, 7)
    print("wave: " .. wave, 2, 14, 7)

    -- draw lightning cooldown bar
    local cd_width = 30
    local cd_filled = cd_width * (1 - lightning_cooldown / lightning_max_cooldown)
    rect(2, 20, 2 + cd_width, 24, 5)
    if cd_filled > 0 then
        rectfill(2, 20, 2 + cd_filled, 24, 12)
    end
    print("ヌあく", 34, 20, 7)

    -- draw minimap (3x3 grid)
    local map_x = 96
    local map_y = 2
    local cell_size = 8

    -- draw grid
    for gy = 0, 2 do
        for gx = 0, 2 do
            local mx = map_x + gx * cell_size
            local my = map_y + gy * cell_size

            -- count asteroids in this cell
            local ast_count = 0
            for a in all(asteroids) do
                if a.grid_x == gx and a.grid_y == gy then
                    ast_count += 1
                end
            end

            -- draw cell
            local col = 1 -- dark blue for empty
            if ast_count > 0 then col = 8 end -- red for asteroids
            if gx == player.grid_x and gy == player.grid_y then
                -- player location (bright)
                rectfill(mx, my, mx + cell_size - 2, my + cell_size - 2, 11)
            else
                rect(mx, my, mx + cell_size - 2, my + cell_size - 2, 5)
                if ast_count > 0 then
                    -- show asteroid indicator
                    circfill(mx + 3, my + 3, 1, col)
                end
            end
        end
    end
    print("map", map_x, map_y + 26, 6)

    -- draw game over
    if game_over then
        print("game over", 40, 60, 8)
        print("press x to restart", 24, 68, 7)
    end
end

__sfx__
00030000336500a6001c6500b600106500b6000865000600016500a60000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000200001e6501d6501865016650126501265014650186501c65020650236502565025650216501b6501665012650106500f6500e6500e6500e6500e6501165013650166501a6502065023650266500060000600
00040000206501b650156500f6500c650096500765006650056500365000650166000060000600006000060000600006001c6000060000600006000060000600006001a600006000060000600006000060000600
0010000c2b0502305016050140501405015050170501d0501f0501e05016050140500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000305503055030550305502f5502d5502b55029550275502555023550215500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000003075030750307503075030750307503075030750307503075030750307502e7502c7502a7502875000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00014344

