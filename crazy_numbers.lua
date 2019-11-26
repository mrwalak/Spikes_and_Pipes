-- crazy_numbers.lua
-- © Matthew Walak 2019
-- All the important constants and things

-- Display
local COL_NUM = 14
local COL_WIDTH = display.contentWidth/COL_NUM

-- Physics
local LN_DAMPING = 1
local GRAVITY = 3.5
local TOUCH_FORCE_FACTOR = 400

-- Spike
local SPIKE_WIDTH = 1 -- In terms of COL_WIDTH
local SPIKE_HEIGHT = 3

-- Bubble
local BUBBLE_SIZE = COL_WIDTH
local BUBBLE_RADIUS = (4/5)*(BUBBLE_SIZE/2)
local BUBBLE_MIN_GROUP_DIST = 3*BUBBLE_SIZE
local EDGE_FORCE_FACTOR = .5
local EDGE_FORCE_DIST = BUBBLE_SIZE

-- Intro
local INTRO_DELAY = 80
local INTRO_FORCE = -.7
local INTRO_RANDOM_WIDTH = .25


local crazy_numbers = {
	-- Display
	COL_NUM = COL_NUM,
	COL_WIDTH = COL_WIDTH,

	-- Physics
	LN_DAMPING = LN_DAMPING,
	GRAVITY = GRAVITY,
	TOUCH_FORCE_FACTOR = TOUCH_FORCE_FACTOR,

	-- Spike
	SPIKE_WIDTH = SPIKE_WIDTH,
	SPIKE_HEIGHT = SPIKE_HEIGHT,

	-- Bubble
	BUBBLE_SIZE = BUBBLE_SIZE,
	BUBBLE_RADIUS = BUBBLE_RADIUS,
	BUBBLE_MIN_GROUP_DIST = BUBBLE_MIN_GROUP_DIST, 
	EDGE_FORCE_FACTOR = EDGE_FORCE_FACTOR,
	EDGE_FORCE_DIST = EDGE_FORCE_DIST,

	-- Intro
	INTRO_DELAY = INTRO_DELAY,
	INTRO_FORCE = INTRO_FORCE,
	INTRO_RANDOM_WIDTH = INTRO_RANDOM_WIDTH,
}

return crazy_numbers
