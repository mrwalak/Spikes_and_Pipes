local CN = require("crazy_numbers")
local util = require("util")


-- SPEED OF ALL OBSTACLES (Number of seconds from top to bottom)
local speed = 5000

local function squareBounceGenerate(num)
    local path
    if (num%2) == 0 then
        path = {-5, -num, 5, -num}
    else
        path = {5, -num, -5, -num}
    end
    local obstacle = {
        name = "Black Square bounce",
        path = path,
        time = {1000, 1000},
        animation_options = {
          position_interpolation = nil,
          rotation = {0},
          rotation_interpolation = nil
        },
        objects = {"black_square"},
        on_complete = "loop",
        first_frame = 1,
        frame_counter = 1
    }
    return obstacle
end 

-- Define obstacles ------------------------------------------------------------
-- Obstacle 1
local obstacle_1 = util.newParentObstacle(speed)
obstacle_1.objects = {}

for i = 0, 15, 1 do
    local add = squareBounceGenerate(i)
    table.insert(obstacle_1.objects, add)
end

--------------------------------------------------------------------------------


-- Define pairs
local obstacles_list = {}
obstacles_list[1] = obstacle_1

local level_1 =  {
    name = "Test level 1",
    speed = 4,
    victory = 10,
    obstacles = obstacles_list,
}

return level_1
