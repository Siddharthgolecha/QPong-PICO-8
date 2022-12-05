pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- qpong
-- by qiskitters

----------------------------------------------------------------------
-- QPong PICO-8 version
-- Source code: https://github.com/HuangJunye/QPong-PICO-8
-- Made during Qiskit Hackathon Taiwan
-- Authors: Jian J-Lee, Lee Yi, Lee Yu-Chieh, Zuo Tso-Yen
-- Coaches: Huang Junye, Leung Shek Lun

-- Original QPong Python version
-- Source code: https://github.com/HuangJunye/QPong
-- Made during Qiskit Camp Flagship 2019
-- Authors: Huang Junye, Jarrod Reilly, Anastasia Jeffery
-- Coach: James Weaver
----------------------------------------------------------------------

#include math.lua
#include microqiskit.lua

----------------------------------------------------------------------
-- Lookup
----------------------------------------------------------------------

-- lookup table with the gpio
--  addresses, used for reading
--  and setting values that we
--  need to pass back and forth
lookup = {}
lookup["player_id"]   = 0x5f80
lookup["room_id"]     = 0x5f81
lookup["score_1"]     = 0x5f82
lookup["score_2"]     = 0x5f83
lookup["ball_x_pos_flr"]  = 0x5f84
lookup["ball_x_pos_rem"]  = 0x5f85
lookup["ball_y_pos_flr"]  = 0x5f86
lookup["ball_y_pos_rem"]  = 0x5f87
lookup["ball_x_spd_flr"]  = 0x5f88
lookup["ball_x_spd_rem"]  = 0x5f89
lookup["ball_x_spd_dir"]  = 0x5f8a
lookup["ball_y_spd_flr"]  = 0x5f8b
lookup["ball_y_spd_rem"]  = 0x5f8c
lookup["ball_y_spd_dir"]  = 0x5f8d
lookup["player_1_joined"] = 0x5f8e
lookup["player_1_y"]  = 0x5f8f
lookup["player_1_prob_1"]  = 0x5f90
lookup["player_1_prob_2"]  = 0x5f91
lookup["player_1_prob_3"]  = 0x5f92
lookup["player_1_prob_4"]  = 0x5f93
lookup["player_1_prob_5"]  = 0x5f94
lookup["player_1_prob_6"]  = 0x5f95
lookup["player_1_prob_7"]  = 0x5f96
lookup["player_1_prob_8"]  = 0x5f97
lookup["player_2_joined"] = 0x5f98
lookup["player_2_y"]  = 0x5f99
lookup["player_2_prob_1"]  = 0x5f9a
lookup["player_2_prob_2"]  = 0x5f9b
lookup["player_2_prob_3"]  = 0x5f9c
lookup["player_2_prob_4"]  = 0x5f9d
lookup["player_2_prob_5"]  = 0x5f9e
lookup["player_2_prob_6"]  = 0x5f9f
lookup["player_2_prob_7"]  = 0x5fa0
lookup["player_2_prob_8"]  = 0x5fa1

-- nset, takes in a lookup key
--  and a value to write to
--  that address
function nset(key, value)
    poke(lookup[key], value)
end

-- nget, takes in a lookup key
--  and returns the value at
--  that address
function nget(key)
    return peek(lookup[key])
end

-- ninc, takes in a lookup key
--  and increments a value,
--  equivalent to +=
function ninc(key, value)
    nset(key, nget(key) + value)
end

function nget_float(key)
    return nget(key..'_flr') + nget(key..'_rem') / 10
end

function nset_float(key, val)
    nset(key..'_flr', flr(val))
    nset(key..'_rem', (val % 1) * 10)
end

----------------
-- init
----------------
-- globals
menu_state = "room"
room_id = flr(rnd(100))
win_score = 4
scored = 1
blink_timer = 0
shots=255
player_color = 7
player_width = 2
player_height = 10
player_speed = 1
player_1_x = 8
player_2_x = 117

-- ball
ball_color = 7
ball_width = 2
ball_speedup = 0.05

-- court
court = {
    left = 0.5,
    right = 127,
    top = 0.5,
    bottom = 82,
    right_edge = 107, --when ball collide this line, measure player 2 circuit
    left_edge = 20, --when ball collide this line, measure player 1 circuit
    color = 5
}

-- court center line
dash_line = {
    x = 63,
    y = 0,
    length = 1.5,
    color = 5
}

-- circuit composer
composer = {
    left = 0,
    right = 127,
    top = 82,
    bottom = 127,
    color = 6
}

-- qubit line
qubit_line = {
    x = 10,
    y = 90,
    length = 108,
    separation = 15,
    color = 5
}

gate_type = {
    x = 0,
    y = 1,
    z = 2,
    h = 3
}

gate_seq = {
    I = 1,
    X = 2,
    Y = 3,
    Z = 4,
    H = 5
}

gates = {
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1}
}

function _init()
    set_scene("title")
    init_menu()
    -- use gameboy palette
    gb_palette()
end

----------------
-- set scene
----------------
function set_scene(s)
    if s == "title" then
        _update = update_title
        _draw = draw_title
    elseif s == "game" then
        _update = update_game
        _draw = draw_game
    elseif s == "select" then
        _update = select_update
        _draw = select_draw
    elseif s == "game_over" then
        _update = update_game_over
        _draw = draw_game_over
    elseif s == "credits" then
        _update = update_credits
        _draw = draw_credits
    end
end

----------------
-- title
----------------
function update_title()
    update_cursor()

    if sub_mode == 0 then
        if btnp(4) and
            menu_timer > 1 then

            if menu.options[menu.sel] == "start" then
                set_scene("select")
            elseif menu.options[menu.sel] == "colors" then
                init_settings()
            elseif menu.options[menu.sel] == "credits" then
                set_scene("credits")
            end
        end
    end

    if (sub_mode == 1) then
        update_settings()
    end

    col1 = 7
    col2 = 0
    menu_timer += 1
end

----------------
-- draw title
----------------
function draw_title()
    cls()
    draw_game_logo()
    draw_options()
end

function draw_game_logo()
    sspr(0, 32, 64, 16, 32, 30)
    print("made by qiskitters with", 4*3, 120, 6)
    print("qiskitters", 4*11, 120, 12)
    print("\135", 4*27, 120, 8)
end

----------------
-- game
----------------
function draw_game()
    cls()

    --court
    rect(court.left, court.top, court.right, court.bottom, court.color)

    --dashed center line
    repeat
        line(dash_line.x, dash_line.y, dash_line.x, dash_line.y + dash_line.length, dash_line.color)
        dash_line.y += dash_line.length * 2
    until dash_line.y > court.bottom - 1
    dash_line.y = 0 -- reset

    --circuit composer
    rectfill(composer.left, composer.top, composer.right, composer.bottom, composer.color)

    --qubit lines
    repeat
      line(qubit_line.x, qubit_line.y, qubit_line.x + qubit_line.length, qubit_line.y, qubit_line.color)
      qubit_line.y += qubit_line.separation
    until qubit_line.y > composer.bottom - 1
    qubit_line.y = 90 -- reset

    for slot = 1,8 do
        for wire = 1,3 do
            gnum = gates[wire][slot] - 2
            if gnum != -1 then
                spr(
                    gnum,
                    qubit_line.x + (slot - 1) * qubit_line.separation - 4,
                    qubit_line.y + (wire - 1) * qubit_line.separation - 4
                )
            end
        end
    end

    -- cursor
    grid_cursor.x = qubit_line.x + grid_cursor.column * qubit_line.separation - 4
    grid_cursor.y = qubit_line.y + grid_cursor.row * qubit_line.separation - 4
    spr(grid_cursor.sprite, grid_cursor.x, grid_cursor.y)

    -- player 1 ket sprites
    for x = 0,7 do
        spr(6, 14, 10 * x + 2)
        a = x % 2
        b = flr(x/2) % 2
        c = flr(x/4) % 2
        spr(c+4, 17, 10 * x + 2)
        spr(b+4, 22, 10 * x + 2)
        spr(a+4, 27, 10 * x + 2)
        spr(7, 31, 10 * x + 2)
    end

    --player 2 ket sprites
    for x = 0,7 do
        spr(6, 94, 10 * x + 2)
        a = x % 2
        b = flr(x/2) % 2
        c = flr(x/4) % 2
        spr(c+4, 97, 10 * x + 2)
        spr(b+4, 102, 10 * x + 2)
        spr(a+4, 107, 10 * x + 2)
        spr(7, 111, 10 * x + 2)
    end

    for i = 1,2 do
      for y = 1,8 do
          local color
          local prob = nget("player_"..i.."_prob_"..y)

          -- dangerous, hard coded for 255 shots !!
          if prob > 252 then
              color = 7
          elseif prob > 124 then
              color = 6
          elseif prob > 63 then
              color = 13
          elseif prob > 28 then
              color = 5
          else
              color = 0
          end

          if i == 1 then
              rectfill(
                  player_1_x,
                  10 * (y - 1)  + 1,
                  player_1_x + player_width,
                  10 * (y - 1) + player_height,
                  color
              )
          else
              rectfill(
                  player_2_x,
                  10 * (y - 1)  + 1,
                  player_2_x + player_width,
                  10 * (y - 1) + player_height,
                  color
              )
          end
      end
    end

    -- ball
    rectfill(
        nget_float("ball_x_pos"),
        nget_float("ball_y_pos"),
        nget_float("ball_x_pos") + ball_width,
        nget_float("ball_y_pos") + ball_width,
        ball_color
    )

    --scores
    print(nget("score_1"), 58, 2, player_color)
    print(nget("score_2"), 66, 2, player_color)
end

function update_circuit_grid_cursor()
    -- moves circuit grid cursor
    if btnp(2) and grid_cursor.row > 0 then
        grid_cursor.row -= 1
    end

    if btnp(3) and grid_cursor.row < 2 then
        grid_cursor.row += 1
    end

    if btnp(0) and grid_cursor.column > 0 then
        grid_cursor.column -= 1
    end

    if btnp(1) and grid_cursor.column < 7  then
        grid_cursor.column += 1
    end
end


function update_circuit_grid()
    --Places a gate and simulates gates on the circuit grid
    if btnp(5) then
        cur_gate = gates[grid_cursor.row+1][grid_cursor.column+1]
        if cur_gate == 2 then
            gates[grid_cursor.row + 1][grid_cursor.column + 1] = 1
        else
            gates[grid_cursor.row + 1][grid_cursor.column + 1] = 2
        end
        simulate_circuit(nget("player_id"))
    end

    if btnp(4) then
        cur_gate = gates[grid_cursor.row+1][grid_cursor.column+1]
        if cur_gate == 5 then
            gates[grid_cursor.row + 1][grid_cursor.column + 1] = 1
        else
            gates[grid_cursor.row + 1][grid_cursor.column + 1] = 5
        end
        simulate_circuit(nget("player_id"))
    end
end


function update_paddles()
    -- measure player 1 near the left edge
    if nget("ball_x_spd_dir") == 0 and nget_float("ball_x_pos") < court.left_edge then
        if (nget("player_id") == 1) then
          measure(1)
          for i = 1,8 do
              prob_key = "player_1_prob_"..i
              probs_i = nget(prob_key)
              if probs_i == shots then
                  nset("player_1_y", 10 * (i  - 1))
              end
          end
        end
    -- measure player 2 near the right edge
    elseif nget("ball_x_spd_dir") == 1 and nget_float("ball_x_pos") > court.right_edge then
        if (nget("player_id") == 2) then
          measure(2)
          for i = 1,8 do
              prob_key = "player_2_prob_"..i
              probs_i = nget(prob_key)
              if probs_i == shots then
                  nset("player_2_y", 10 * (i  - 1))
              end
          end
        end
    end
end


function endgame()
    if nget("ball_x_spd_dir") == 1 and nget_float("ball_x_pos") >= court.right then
        ninc("score_1", 1)
        scored = 1
        if nget("score_1") < win_score then
            if (nget("player_id") == 2) then
              simulate_circuit(2)
            end
            reset_ball()
        else
            set_scene("game_over")
        end
    end

    if nget("ball_x_spd_dir") == 0 and nget_float("ball_x_pos") <= court.left then
        ninc("score_2", 1)
        scored = 2
        if nget("score_2") < win_score then
            --simulate_circuit(1)
            if (nget("player_id") == 1) then
                simulate_circuit(1)
            end
            reset_ball()
        else
            set_scene("game_over")
        end
    end
end


function update_ball()
    local new_dx = 0
    local new_dy = 0

    -- collide with court
    if nget_float("ball_y_pos") + ball_width >= court.bottom
    or nget_float("ball_y_pos") <= court.top then
        nset("ball_y_spd_dir", (nget("ball_y_spd_dir") + 1) % 2)
        sfx(2)
    end

    -- collide with player 1
    if nget("ball_x_spd_dir") == 0
        and nget_float("ball_x_pos") <= player_1_x + player_width
        and nget_float("ball_x_pos") > player_1_x
        and (((nget_float("ball_y_pos") + ball_width <= nget("player_1_y") + player_height)
        and (nget_float("ball_y_pos") + ball_width >= nget("player_1_y")))
        or ((nget_float("ball_y_pos") <= nget("player_1_y") + player_height)
        and (nget_float("ball_y_pos") >= nget("player_1_y"))))
     then
        new_dy = (-(-1)^nget("ball_y_spd_dir")) * nget_float("ball_y_spd") - 2.0 * ball_speedup
        nset_float("ball_y_spd", abs(new_dy))

        if new_dy < 0 then
          nset("ball_y_spd_dir", 0)
        else
          nset("ball_y_spd_dir", 1)
        end

        new_dx = -(-nget_float("ball_x_spd") - ball_speedup)
        nset_float("ball_x_spd", abs(new_dx))

        if new_dx < 0 then
          nset("ball_x_spd_dir", 0)
        else
          nset("ball_x_spd_dir", 1)
        end
        sfx(1)
     end

    -- collide with player 2
    if nget("ball_x_spd_dir") == 1
        and nget_float("ball_x_pos") <= player_2_x + player_width
        and nget_float("ball_x_pos") > player_2_x
        and (((nget_float("ball_y_pos") + ball_width <= nget("player_2_y") + player_height)
        and (nget_float("ball_y_pos") + ball_width >= nget("player_2_y")))
        or ((nget_float("ball_y_pos") <= nget("player_2_y") + player_height)
        and (nget_float("ball_y_pos") >= nget("player_2_y"))))
     then
        new_dy = (-(-1)^nget("ball_y_spd_dir")) * nget_float("ball_y_spd") - 2.0 * ball_speedup
        nset_float("ball_y_spd", abs(new_dy))

        if new_dy < 0 then
          nset("ball_y_spd_dir", 0)
        else
          nset("ball_y_spd_dir", 1)
        end

        new_dx = -(nget_float("ball_x_spd") - ball_speedup)
        nset_float("ball_x_spd", abs(new_dx))

        if new_dx < 0 then
          nset("ball_x_spd_dir", 0)
        else
          nset("ball_x_spd_dir", 1)
        end
        sfx(1)
     end

    -- ball movement
    new_dx = nget_float("ball_x_pos") -(-1)^(nget("ball_x_spd_dir")) * nget_float("ball_x_spd")
    new_dy = nget_float("ball_y_pos") -(-1)^(nget("ball_y_spd_dir")) * nget_float("ball_y_spd")

    nset_float("ball_x_pos", abs(new_dx))
    nset_float("ball_y_pos", abs(new_dy))
end


function update_game()
    --- update circuit grid cursor
    update_circuit_grid_cursor()

    --- update and simulate circuit grid
    update_circuit_grid()

    -- quantum paddles
    update_paddles()

    -- update ball
    update_ball()

    -- endgame
    endgame()
end


function init_qpong_game()
    set_scene("game")

    -- reset cursor
    grid_cursor = {
        row=0,
        column=0,
        x=0,
        y=0,
        sprite=16
    }

    -- reset gates
    gates = {
        {1,1,1,1,1,1,1,1},
        {1,1,1,1,1,1,1,1},
        {1,1,1,1,1,1,1,1}
    }

    nset("player_1_y", 20)
    nset("player_2_y", 20)

    for y = 1,8 do
      if y == 1  then
          nset("player_1_prob_"..y, shots)
          nset("player_2_prob_"..y, shots)
      else
          nset("player_1_prob_"..y, 0)
          nset("player_2_prob_"..y, 0)
      end
    end

    nset("score_1", 0)
    nset("score_2", 0)

    -- sound
    if scored == 1 then
        sfx(3)
    elseif scored == 2  then
        sfx(4)
    else
        sfx(5)
    end

    reset_ball()
end

function reset_ball()
    nset_float("ball_x_pos", 63)
    nset_float("ball_y_pos", 33)
    nset_float("ball_x_spd", 0.8)
    nset_float("ball_y_spd", 0.8)

    if scored == 1 then
      nset("ball_x_spd_dir", 0)
    else
      nset("ball_x_spd_dir", 1)
    end

    nset("ball_y_spd_dir",  flr((nget("ball_y_spd_dir") + rnd(2))) % 2)
end

function select_update()
  blink_timer = (blink_timer + 1) % 60

  if menu_state == "room" then

      if (btnp(2)) then
          room_id = (room_id + 1) % 100
      end

      if (btnp(3)) then
          room_id = (room_id - 1) % 100
      end


      if (btnp(5)) then
          nset("room_id", room_id)
          nset("player_id", 0)
          nset("player_1_joined", -1)
          nset("player_2_joined", -2)
          menu_state = "player"
      end
  end


  if menu_state == "player" then
      spectating = nget("player_id") == 0
      can_join_as_1 = nget("player_1_joined") != nget("room_id")
      can_join_as_2 = nget("player_2_joined") != nget("room_id")
      can_join = (can_join_as_1 or can_join_as_2)

      if (can_join and spectating) then
          if (btnp(0) and can_join_as_1) then
              nset("player_id", 1)
              nset("player_1_joined", nget("room_id"))
              menu_state = "ready"
          end

          if (btnp(1) and can_join_as_2) then
              nset("player_id", 2)
              nset("player_2_joined", nget("room_id"))
              menu_state = "ready"
          end
      end
  end

  if menu_state == "ready" then
      if (nget("player_1_joined") == nget("player_2_joined")) then
          init_qpong_game()
      end
  end
end


function select_draw()
    cls()
    draw_game_logo()

    color_stale = 7
    color_flash = 8 + ((blink_timer/2) % 6)

    if menu_state == "room" then
        --print("", 31, 90, color_stale)
        print("⬆️ room:"..room_id.." ⬇️", 38, 70, color_stale)
        print("press ❎ to lock in room", 17, 70+10, color_stale)
    elseif menu_state == "player" then
        can_join_as_1 = nget("player_1_joined") != nget("room_id")
        can_join_as_2 = nget("player_2_joined") != nget("room_id")
        can_join = (can_join_as_1 or can_join_as_2)

        if (not can_join) then
            print("occupied", 50, 70, color_stale)
        end

        if (can_join_as_1) then
            print("press ⬅️ to join as player 1", 8, 70, color_stale)
        end

        if (can_join_as_2) then
            print("press ➡️ to join as player 2", 8, 70+10, color_stale)
        end
    elseif menu_state == "ready" then
          print("waiting", 50, 70, color_flash)
    end
end

----------------
-- game over
----------------
function update_game_over()
    nset("player_"..nget("player_id").."_joined", -1)

    if btnp(5) then
        nset("player_"..nget("player_id").."_joined", nget("room_id"))
        menu_state = "ready"
        set_scene("select")
    end

    if btnp(4) then
        stop()
    end

end

function draw_game_over()
    cls()

    blink_timer = (blink_timer + 1) % 60

    if scored == nget("player_id") then
        -- player win
        print("you demonstrated", 8, 28, 8)

        -- quantum advantage
        sspr(0,80,80,16,24,40)
        -- cat
        sspr(16,64,16,16,2,94,32,32)

        draw_qiskit_logo(100,10)

        print("for the first time ",44,58,8)
        print("in human history!",56,66,8)
    else
        -- com win
        print("classical computers",8,28,8)
        print("still rule the world!",40,50,8)
        -- cat
        sspr(0,64,16,16,2,94,32,32)

        -- computer
        sspr(32,64,16,16,96,4,32,32)
    end

    -- restart
    if blink_timer < 40 then
        print("press  ❎  to rematch", 24, 80, 10)
        print("press 🅾️ to quit", 24, 90, 10)
    end
end

----------------
-- credits
----------------
function update_credits()
    if btnp(5) then
        set_scene("title")
    end
end

function draw_credits()
    cls()
    print("made during", 4, 8, 9)
    print("qiskit hackathon taiwan 2020", 4*2, 8*2, 7)
    print("by", 4, 8*4, 9)
    authors = {"jian j-lee", "lee yi", "lee yu-chieh", "zuo tso-yen"}
    coaches = {"huang junye", "leung shek lun"}
    xoffset = 4*2
    yoffset = 8*5

    print("team members", xoffset, yoffset, 12)
    for i, name in ipairs(authors) do
        print(name, xoffset+4, yoffset+i*8, 7)
    end

    print("coaches", xoffset, yoffset+44, 12)
    for i, name in ipairs(coaches) do
        print(name, xoffset+4, yoffset+44+i*8, 7)
    end

    draw_qiskit_logo(90,50)
end

function draw_qiskit_logo(x,y)
    sspr(48,64,16,16,x,y)
    print("qiskit", x-3, y+19, 6)
end

----------------
-- quantum circuits
----------------
function simulate_circuit(p_id)
    qc = QuantumCircuit()
    qc.set_registers(3,3)

    for slots = 1,8 do
        for wires = 1,3 do
            if (gates[wires][slots] == 2) then
                qc.x(wires-1)
            elseif (gates[wires][slots] == 3) then
                qc.y(wires-1)
            elseif (gates[wires][slots] == 4) then
                qc.z(wires-1)
            elseif (gates[wires][slots] == 5) then
                qc.h(wires-1)
            end
        end
    end

    qc.measure(0,0)
    qc.measure(1,1)
    qc.measure(2,2)

    result = simulate(qc, 'expected_counts', shots)

    for key, value in pairs(result) do
        --print(key, value)
        idx = tonum('0b'..key) + 1
        nset("player_"..p_id.."_prob_"..idx, value)
    end
end

function measure(p_id)
    idx = -1
    math.randomseed(os.time())
    r= flr(math.random() * shots)
    num = 0
    for i = 1,8 do
        prob_key = "player_"..p_id.."_prob_"..i
        probs_i = nget(prob_key)
        if (r > probs_i) then
              num = r - probs_i
              r = num
        elseif (r <= probs_i) then
              idx = i
              break
        end
    end

    for i = 1,8 do
        prob_key = "player_"..p_id.."_prob_"..i
        if i == idx then
            nset(prob_key, shots)
        else
            nset(prob_key, 0)
        end
    end
    return idx
end

----------------
-- menu
-- Inspired by PixelCode
-- Source code: https://www.lexaloffle.com/bbs/?tid=27725
----------------
function lerp(startv,endv,per)
    return(startv+per*(endv-startv))
end

function update_cursor()
    if (btnp(2)) then
        menu.sel -= 1
        cx = menu.x
        sfx(0)
    end
    if (btnp(3)) then
      menu.sel += 1
      cx = menu.x
      sfx(0)
    end
    if (btnp(4)) then
      cx = menu.x
      sfx(1)
    end
    if (btnp(5)) then
      sfx(2)
    end
    if (menu.sel > menu.amt) then
      menu.sel = 1
    end
    if (menu.sel <= 0) then
      menu.sel = menu.amt
    end

    cx = lerp(cx, menu.x + 5, 0.5)
end

function draw_options()
    for i=1, menu.amt do
        oset=i*8
        if i==menu.sel then
            rectfill(cx,menu.y+oset-1,cx+4*7,menu.y+oset+5,col1)
            print(menu.options[i],cx+1,menu.y+oset,col2)
        else
            print(menu.options[i],menu.x,menu.y+oset,col1)
        end
    end
end

function init_menu()
    menu={}
    menu.x=50
    cx=menu.x
    menu.y=70
    menu.options={"start", "colors", "credits"}
    menu.amt=0
    for i in all(menu.options) do
        menu.amt += 1
    end
    menu.sel = 1
    sub_mode = 0
    menu_timer = 0
end

function init_settings()
    menu.sel=1
    menu.options={"gameboy", "pico-8"}
    menu.amt=0
    for i in all(menu.options) do
        menu.amt+=1
    end
    sub_mode=1
    menu_timer=0
end

function update_settings()
    if (btnp(5)) then
      init_menu()
    end
    if btnp(4) and menu_timer>1 then
        if menu.options[menu.sel]=="gameboy" then
            gb_palette()
        elseif menu.options[menu.sel]=="pico-8" then
            pico8_palette()
        end
    end
end

----------------
-- color palette
-- Inspired by @TheUnproPro
-- Source code: https://twitter.com/TheUnproPro/status/1168665614896062468
----------------
function gb_palette()
    -- gameboy color palette

    green_0 = 0xf1 -- darkest green
    green_1 = 0x93 -- dark green
    green_2 = 0x23 -- light green
    green_3 = 0xfb -- lightest green

    poke(0x5f10+0, green_0)
    poke(0x5f10+1, green_1)
    poke(0x5f10+2, green_2)
    poke(0x5f10+3, green_2)
    poke(0x5f10+4, green_0)
    poke(0x5f10+5, green_1)
    poke(0x5f10+6, green_2)
    poke(0x5f10+7, green_3)
    poke(0x5f10+8, green_1)
    poke(0x5f10+9, green_1)
    poke(0x5f10+10, green_3)
    poke(0x5f10+11, green_1)
    poke(0x5f10+12, green_1)
    poke(0x5f10+13, green_1)
    poke(0x5f10+14, green_2)
    poke(0x5f10+15, green_3)
end

function pico8_palette()
    -- pico-8 original palette

    for i = 0, 15 do
      poke(0x5f10+i, i)
    end
end

__gfx__
77777771777777717777777177777771000000000000000010000000010000000000000000000000000000000000000000000000000000000000000000000000
71777171717771717111117171777171011000000010000010000000001000000000000000000000000000000000000000000000000000000000000000000000
77171771771717717777177171777171100100000110000010000000001000000000000000000000000000000000000000000000000000000000000000000000
77717771777177717771777171111171100100000010000010000000000100000000000000000000000000000000000000000000000000000000000000000000
77171771777177717717777171777171100100000010000010000000000100000000000000000000000000000000000000000000000000000000000000000000
71777171777177717111117171777171011000000010000010000000001000000000000000000000000000000000000000000000000000000000000000000000
77777771777777717777777177777771000000000000000010000000001000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111000000000000000010000000010000000000000000000000000000000000000000000000000000000000000000000000
c0c0c0c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c0c0c0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000ccc00000007777770000000007770000007700007770000777777700000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ccccccc000007777777770000777777700007770007770007777777770000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ccc000ccc00007770007770007770007770007777007770007770000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ccc000ccc00007777777770007770007770007777777770007770777770000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ccc000ccc00007777770000007770007770007777777770007770777770000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ccc000ccc00007770000000007770007770007770077770007770007770000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ccccccc000007770000000000777777700007770007770007777777770000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000ccccccc0007770000000000007770000007770000770000777777700000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000b00000000000000000000000000000000000000077077770770000000000000000000000000000000000000000000000000000000000000000000
0000000b00000b0b0000000000000000000000000000000000777700007777000000000000000000000000000000000000000000000000000000000000000000
00000000000b000b0000000000070700000000000000000007777777777777700000000000000000000000000000000000000000000000000000000000000000
00000000b0b00b000000777000077700011111111110000077099000000000770000000000000000000000000000000000000000000000000000000000000000
000000000b0b00b00100007777707000017777777710000070799777777777070000000000000000000000000000000000000000000000000000000000000000
00070070000000000010000077770000017777777710000007777977777777700000000000000000000000000000000000000000000000000000000000000000
000777700b00bb0b0001000070070000017977779710000070777797777777070000000000000000000000000000000000000000000000000000000000000000
00077770000000000001000700700000017979979710000077000009000000770000000000000000000000000000000000000000000000000000000000000000
00077770333333339000010000000000017999999710000077777777977777770000000000000000000000000000000000000000000000000000000000000000
00077770333333339000100010110000011111111110000077000000090000770000000000000000000000000000000000000000000000000000000000000000
00077770333383339000000100000000011111111110000070777777779777070000000000000000000000000000000000000000000000000000000000000000
000777703338a83399999900000000000dddddddddd0000007777777777997700000000000000000000000000000000000000000000000000000000000000000
770777703388a88399999900000000000d06060606d0000070777777777997070000000000000000000000000000000000000000000000000000000000000000
070777703888888899999900000000000d60606060d0d60007000000000000700000000000000000000000000000000000000000000000000000000000000000
077777708888a88899999900000000000d06060606d0660000777777777777000000000000000000000000000000000000000000000000000000000000000000
000777703333333399999900000000000dddd77dddd0660000077700007770000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaaa00000000000000000000000000000000000aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000a0000000000000000000000000000000000a00a000a0000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000a0000000000000000000000000000000000a00a000a0000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000a0000000000000a00000000000000000000a00a000a0000000000000a00000000000000000000000000000000000000000000000000000000000000000
0a00a0a0a0a0aaa0aaa0aa0a0a0aaaaa000000000aaaa0aaa0a0a0aaa0aaa0aa0aaa0aaa0aaa0000000000000000000000000000000000000000000000000000
0a000aa0a0a0a0a0a0a0a00a0a0a0a0a000000000a00a0a0a0a0a0a0a0a0a0a00a0a0a0a0a0a0000000000000000000000000000000000000000000000000000
0aaaaaaaaaaaaaaaa0aaaaaaaaaa0a0a000000000a00a0aaa00a00aaaaa0aaaaaaaaaa0aaaaa0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000a0a000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000aaa0aaa0000000000000000000000000000000000000000000000000000
__label__
66606060666066600000606066606000666000006660066066600000606066606000666000000000000000000000000000000000000000000000000000000000
06006060606060000000606060006000606000006000606060600000606060006000606000000000000000000000000000000000000000000000000000000000
06006660666066000000666066006000666000006600606066000000666066006000666000000000000000000000000000000000000000000000000000000000
06000060600060000000606060006000600000006000606060600000606060006000600000000000000000000000000000000000000000000000000000000000
06006660600066600000606066606660600000006000660060600000606066606660600000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000700007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000700077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000700000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000777077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc00ccc0ccc0ccc00cc0ccc00cc0ccc0c0c00000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c00c00c0c0c000c0000c00c0c0c0c0c0c00c0000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c00c00cc00cc00c0000c00c0c0cc00ccc0000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c00c00c0c0c000c0000c00c0c0c0c000c00c0000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc0ccc0c0c0ccc00cc00c00cc00c0c0ccc000000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
eee0eee00ee00ee00000eee00ee0ee000ee000000ee0ee00e000eee0ee00eee00000000000000000000000000000000000000000000000000000000000000000
e0e00e00e000e0e00000e0e0e0e0e0e0e0000000e0e0e0e0e0000e00e0e0e0000000000000000000000000000000000000000000000000000000000000000000
eee00e00e000e0e0eee0eee0e0e0e0e0e000eee0e0e0e0e0e0000e00e0e0ee000000000000000000000000000000000000000000000000000000000000000000
e0000e00e000e0e00000e000e0e0e0e0e0e00000e0e0e0e0e0000e00e0e0e0000000000000000000000000000000000000000000000000000000000000000000
e000eee00ee0ee000000e000ee00e0e0eee00000ee00e0e0eee0eee0e0e0eee00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e00eee00ee0ee000ee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0eee0e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ee00e000e0e0e0e0e0e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ee0e000ee00e0e0eee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ee0eee0eee0ee000000e0e0eee0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e0e0e000e0e00000e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0eee0ee00e0e00000e0e0ee00e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e000e000e0e00000e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ee00e000eee0e0e0eee00ee0e0e0eee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000ee0ee000ee0000000000000000000000000eee000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e000ee0e0e0e0e0e00000000ee0eee00ee00ee00000e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e0e0e0e0e0e0e000eee0e0e00e00e000e0e0eee0eee000000000000000000000000000000000000000000000000000000000000000000000000000000000
ee00eee0e0e0e0e0e0e00000eee00e00e000e0e00000e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ee0e000ee00e0e0eee00000e000eee00ee0ee000000eee000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000077077000000070077700770770007700000777077700770077000007770000000000000000000000000000000000000000000000000000000000000
07000000700070700000707070707070707070000000707007007000707000007070000000000000000000000000000000000000000000000000000000000000
00700000700070700000707077707070707070007770777007007000707077707770000000000000000000000000000000000000000000000000000000000000
07000000700070700000770070007070707070700000700007007000707000007070000000000000000000000000000000000000000000000000000000000000
70000000077077700000077070007700707077700000700077700770770000007770000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c00c00ccc00cc0cc000cc00000ccc0ccc00cc00cc00000ccc000c0000000000000000000000000000000000000000000000000000000000000000000000000
0c00c0c0c0c0c0c0c0c0c0000000c0c00c00c000c0c00000c0c00c00000000000000000000000000000000000000000000000000000000000000000000000000
0c00c0c0ccc0c0c0c0c0c000ccc0ccc00c00c000c0c0ccc0ccc00c00000000000000000000000000000000000000000000000000000000000000000000000000
0c00cc00c000c0c0c0c0c0c00000c0000c00c000c0c00000c0c00c00000000000000000000000000000000000000000000000000000000000000000000000000
c0000cc0c000cc00c0c0ccc00000c000ccc00cc0cc000000ccc0c000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000700007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000700077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000700000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000777077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc00ccc0ccc0ccc00cc0ccc00cc0ccc0c0c00000000000c00c00ccc00cc0cc000cc00000ccc0ccc00cc00cc00000ccc000000000000000000000000000000000
c0c00c00c0c0c000c0000c00c0c0c0c0c0c00c0000000c00c0c0c0c0c0c0c0c0c0000000c0c00c00c000c0c00000c0c000000000000000000000000000000000
c0c00c00cc00cc00c0000c00c0c0cc00ccc0000000000c00c0c0ccc0c0c0c0c0c000ccc0ccc00c00c000c0c0ccc0ccc000000000000000000000000000000000
c0c00c00c0c0c000c0000c00c0c0c0c000c00c0000000c00cc00c000c0c0c0c0c0c00000c0000c00c000c0c00000c0c000000000000000000000000000000000
ccc0ccc0c0c0ccc00cc00c00cc00c0c0ccc000000000c0000cc0c000cc00c0c0ccc00000c000ccc00cc0cc000000ccc000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ee000ee0ee00eee00000eee00ee0ee00e0e0e000eee00ee000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e0e0e0e0e0000000eee0e0e0e0e0e0e0e000e000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e0e0e0e0ee000000e0e0e0e0e0e0e0e0e000ee00eee000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e0e0e0e0e0000000e0e0e0e0e0e0e0e0e000e00000e000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0ee00eee0eee0eee0e0e0ee00eee00ee0eee0eee0ee0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000ee0eee0eee0e0e0e0e0eee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000e0000e000e00e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000e0000e000e00eee0e0e0ee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000e0e00e000e00e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e00eee0eee00e00e0e00ee0eee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000ee0eee0eee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000e0000e000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000e0000e000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000e0e00e000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e00eee0eee00e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06006660066066000660000066606660000066606660606000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060606000000060606060000060606060606000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660606060606000000066606660000066006660660000000000000000000000000000000000000000000000000000000000000000000000000000000000
66006000606060606060000060006060000060606060606000000000000000000000000000000000000000000000000000000000000000000000000000000000
06606000660060606660060060006660060066606060606000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06006660066066000660000006606660000066606660000066606600066000000000000000000000000000000000000000000000000000000000000000000000
60606060606060606000000060006060000060606060000060606060600000000000000000000000000000000000000000000000000000000000000000000000
60606660606060606000666060006600000066606660000066606060600000000000000000000000000000000000000000000000000000000000000000000000
66006000606060606060000060606060000060006060000060006060606000000000000000000000000000000000000000000000000000000000000000000000
06606000660060606660000066606660060060006660060060006060666000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06006660066066000660000066606660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606060606060606000000060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60606660606060606000000066606660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66006000606060606060000060006060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06606000660060606660060060006660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000700007707770770000000700777007707700077000007770777000000000000000000000000000000000000000000000000000000000000000000000
07000000700070707070707000007070707070707070700000007070707000000000000000000000000000000000000000000000000000000000000000000000
00700000700070707770707000007070777070707070700000007770777000000000000000000000000000000000000000000000000000000000000000000000
07000000700070707070707000007700700070707070707000007000707000000000000000000000000000000000000000000000000000000000000000000000
70000000777077007070777000000770700077007070777007007000777000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000660666066006660660000000600666006606600066000006660666000000600666066606000666066600000066060606660666006600600000000000000
60006060606060606000606000006060606060606060600000006060606000006000006000606000606000600000600060606060606060000060000000000000
60006060666060606600606000006060666060606060600000006660666000006000666066606660606006600000600066606660660066600060000000000000
60006060606060606000606000006600600060606060606000006000606000006000600060006060606000600000600060606060606000600060000000000000
66606600606066606660666000000660600066006060666006006000666000000600666066606660666066600000066060606060606066000600000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

