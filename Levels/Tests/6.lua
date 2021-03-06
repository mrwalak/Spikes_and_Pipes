local CN = require("crazy_numbers")
local util = require("util")


-- SPEED OF ALL OBSTACLES (Number of seconds from top to bottom)
local speed = 4000

-- Define obstacles ------------------------------------------------------------
-- Obstacle 1
local obstacle_1 = util.newParentObstacle(speed)
local obstacle_1_child = {
    name = "Black Square bounce",
    path = {-5, 0, 5, 0},
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
obstacle_1.objects = {obstacle_1_child}

-- Obstacle 2
local obstacle_2 = util.newParentObstacle(speed)
local obstacle_2_child = {
    name = "Black Square square rotate",
    path = {-1, 1, 1, 1, 1, -1, -1, -1},
    time = {40, 40, 40, 40},
    animation_options = {
      position_interpolation = nil,
      rotation = {0, 0},
      rotation_interpolation = nil
    },
    objects = {"black_square"},
    on_complete = "loop",
    first_frame = 1,
    frame_counter = 1
}
obstacle_2.objects = {obstacle_2_child}

-- Obstacle 3
local obstacle_3 = util.newParentObstacle(speed)
obstacle_3.time = {400, 400}
local obstacle_3_child = {
    name = "Black Square still",
    path = {0,0},
    time = {400},
    animation_options = {
      position_interpolation = nil,
      rotation = {0},
      rotation_interpolation = nil
    },
    objects = {"black_square"},
    on_complete = "stop",
    first_frame = 1,
    frame_counter = 1
}
obstacle_3.objects = {obstacle_3_child}
--------------------------------------------------------------------------------


-- Define pairs
local obstacles_list = {}
--obstacles_list[2] = obstacle_1
--obstacles_list[4] = obstacle_2
--obstacles_list[6] = obstacle_3

local level_3 =  {
    name = "Test level 3",
    speed = 4,
    victory = 20,
    obstacles = obstacles_list,
}

return level_3
