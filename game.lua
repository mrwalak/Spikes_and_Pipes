-- game.lua
-- © Matthew Walak 2019
-- Where you actually play a level!


local levels = require("levels")
local util = require("util")
local CN = require ("crazy_numbers")
local composer = require( "composer" )
local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

-- Initialize physics
local physics = require("physics")
physics.start()
physics.setGravity(0,0)

-- Define display groups
local bubbleGroup
local obstacleGroup
local backgroundGroup
local uiGroup

-- Define game loop
local gameLoopTimer

-- Define important gameplay variables
local score -- Same as height within the level

-- Define variable for level data
local level_data

-- ui elements
local scoreText

-- Removes everything from

-- Stops all transitions for a given obstacle
local function stopTransitions(obstacleGroup)
    if not obstacleGroup then return end
    if obstacleGroup.numChildren then
        for i = 1, obstacleGroup.numChildren, 1 do
            stopTransitions(obstacleGroup[i])
        end
    end

    transition.cancel(obstacleGroup)
end

-- Transitions an obstacle from keyframe to keyframe + 1
local function keyframeObstacle(obstacleGroup)
    local obstacle_data = obstacleGroup.obstacle_data
    local name = obstacleGroup.obstacle_data.name
    local num_keyframes = (#obstacle_data.path/2)

    -- Update keyframe for wrap-around
    local keyframe = ((obstacle_data.frame_counter - 1) % num_keyframes) + 1

    -- Initialize next_keyframe (With wrap-arround value)
    local next_keyframe = keyframe + 1
    next_keyframe = ((next_keyframe - 1) % num_keyframes) + 1

    -- Initialize with number of times this animation has looped completely
    local revolutions = (obstacle_data.frame_counter - 1)/num_keyframes
    revolutions = math.floor(revolutions)

    -- Full loop compelte actions
    if(revolutions > 0) then
        if(obstacle_data.on_complete == "destroy") then
            stopTransitions(obstacleGroup)
            obstacleGroup:removeSelf()
            obstacleGroup = nil
            return
        elseif(obstacle_data.on_complete == "stop") then
            return
        elseif(obstacle_data.on_complete == "loop") then
            -- Do nothing
        end
    end

    -- Update our frame count and perform transition
    obstacleGroup.obstacle_data.frame_counter = obstacleGroup.obstacle_data.frame_counter + 1

    local transition_time = obstacle_data.time[keyframe]
    local next_x = obstacle_data.path[(next_keyframe*2)-1] * CN.COL_WIDTH
    local next_y = obstacle_data.path[next_keyframe*2] * CN.COL_WIDTH

    transition.to(obstacleGroup, {
        time = transition_time,
        x = next_x,
        y = next_y,
        onComplete = keyframeObstacle
    })
end

-- Creates an objects and starts transition from frame_counter to frame_counter+1
local function createObstacle(obstacle_data)
    local name = obstacle_data.name

    -- Set up new group for obstacle
    -- Will probably need to set anchor point at some point
    local thisObstacleGroup = display.newGroup()
    thisObstacleGroup.obstacle_data = obstacle_data

    -- find frame and update position
    local num_keyframes = #obstacle_data.path/2
    local this_keyframe = ((obstacle_data.frame_counter - 1) % num_keyframes) + 1
    thisObstacleGroup.x = obstacle_data.path[(this_keyframe*2)-1]*CN.COL_WIDTH
    thisObstacleGroup.y = obstacle_data.path[this_keyframe*2]*CN.COL_WIDTH
    thisObstacleGroup.rotation = obstacle_data.animation_options.rotation[(this_keyframe*2)-1]

    -- Recursively add objects to this obstacle
    local num_objects
    if obstacle_data.objects then
        num_objects = #obstacle_data.objects
    else
        num_objects = 0
    end

    for i = 1, num_objects, 1 do
        local thisObject = obstacle_data.objects[i]
        if not thisObject then
            -- Do nothing
        elseif type(thisObject) == "table" then
            -- Recursively nestled objects!
            thisObstacleGroup:insert(createObstacle(obstacle_data.objects[i]))
        elseif type(thisObject) == "string" then
            if thisObject == "black_square" then
                local black_square = display.newImageRect(thisObstacleGroup, "Game/Obstacle/black_square.png", CN.COL_WIDTH, CN.COL_WIDTH)
            elseif thisObject == "spike" then
                local spike = display.newImageRect(thisObstacleGroup, "Game/Obstacle/spike.png", CN.COL_WIDTH, CN.COL_WIDTH)
            end
        end
    end

    -- Begin obstacle animation
    keyframeObstacle(thisObstacleGroup)
    return thisObstacleGroup
end


-- Update score element
local function update_scoreText()
    scoreText.text = score
end

local function on_victory_tapped(event)
    print("on_victory_tapped")

    -- Remove victory thing
    event.target.text:removeSelf()
    event.target:removeSelf()

    -- Remove all obstacles still on screen

    composer.gotoScene("level_select")
end

local function victory()
    timer.pause(gameLoopTimer)

    -- Creates temporary victory button with event listener
    local button = display.newRect(uiGroup, display.contentWidth/2, display.contentHeight/2,
    display.contentWidth/2,display.contentHeight/8)
    button:setFillColor(0,127,127)
    button:addEventListener("tap", on_victory_tapped)

    -- Adds text
    button.text = display.newText(uiGroup, "Back to level select",
        display.contentWidth/2, display.contentHeight/2,
        native.systemFont)
    button.text:setFillColor(0,0,0)

end

-- Updates obstacles and background (Updates twice a second)
local function gameLoop_slow()
    score = score + 1

    -- Check for VICTORY
    if (score == level_data.victory) then
        victory()
    end

    -- Check if we put on another object (The slot in the array is not null)
    if level_data.obstacles[score] then
        print("adding object "..score)
        obstacleGroup:insert(createObstacle(level_data.obstacles[score]))
    end

    update_scoreText()
end

-- Does all the pagentry showing bubbles escaping the pipe etc...
-- Removes all intro-related graphics from screen itself
local function run_intro()
    print("running intro!")
end

-- Starts the game!
local function start_game()
    print("starting game")
    gameLoopTimer = timer.performWithDelay(500, gameLoop_slow, 0)
end


-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

    local sceneGroup = self.view
    -- Code here runs when the scene is first created but has not yet appeared on screen

    -- Add display groups
    bubbleGroup = display.newGroup()
    obstacleGroup = display.newGroup()
    backgroundGroup = display.newGroup()
    uiGroup = display.newGroup()
    sceneGroup:insert(backgroundGroup)
    sceneGroup:insert(bubbleGroup)
    sceneGroup:insert(obstacleGroup)
    sceneGroup:insert(uiGroup)

    -- Temporary white background (This should be replaced by backgroundGroup later)
    local bg = display.newRect(display.contentWidth/2, display.contentHeight/2, display.contentWidth, display.contentHeight)
    bg:setFillColor(1,1,1)
    backgroundGroup:insert(bg)

    -- Initialize ui
    score = 0
    scoreText = display.newText(uiGroup, score, display.contentWidth/2, display.contentHeight/8, native.systemFont, 36)
    scoreText:setFillColor(0,0,0)
end


-- show()
function scene:show( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is still off screen (but is about to come on screen)
        util.printMemUsage()

        -- Initialize level data
        local level = composer.getVariable("level")
        local level_data_original = require ("Levels."..level)
        level_data = util.deepcopy(level_data_original)

        print("Here we are, playing level ".. level_data.name)
        score = 0
        update_scoreText()

    elseif ( phase == "did" ) then
        -- Code here runs when the scene is entirely on screen
        run_intro()
        timer.performWithDelay(0, start_game)
    end
end


-- hide()
function scene:hide( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is on screen (but is about to go off screen)


    elseif ( phase == "did" ) then
        -- Code here runs immediately after the scene goes entirely off screen

    end
end


-- destroy()
function scene:destroy( event )

    local sceneGroup = self.view
    -- Code here runs prior to the removal of scene's view


end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
