-- game.lua
-- © Matthew Walak 2019
-- Where you actually play a level!!!


local levels = require("levels")
local util = require("util")
local CN = require ("crazy_numbers")
local A = require ("animation")
local lb = require ("level_builder")
local composer = require( "composer" )
local bubble = require("bubble")
local scene = composer.newScene()

-- -----------------------------------------------------------------------------------
-- Code outside of the scene event functions below will only be executed ONCE unless
-- the scene is removed entirely (not recycled) via "composer.removeScene()"
-- -----------------------------------------------------------------------------------

-- Initialize physics
local physics = require("physics")

-- Game borders
local leftBorder
local rightBorder
local bottomBorder
local topBorder

-- Define display groups
local bubbleGroup
local obstacleGroup
local backgroundGroup
local uiGroup
local padGroup -- In front of everything

-- Define important gameplay variables
local score -- Total normalized seconds offset by height of heighest bubble
local total_norm_sec -- Total normalized seconds
local activeObstacles = {} -- List of pointers to parent null for all active obstacles (1 for each obstacle)
local activeTransitioners = {} -- One transition for each null object

local last_frame_time -- Time in ms of the last frame render
local time_scale -- Value of each ms in game time
local next_obstacle_time -- Time when next obstacle is added

local gameStarted = false

-- Define variable for level data
local level_data

-- ui elements
local scoreText

-- Screen size data & pads
local _top = display.screenOriginY
local _left = display.screenOriginX
local _bottom = display.actualContentHeight
local _right = display.actualContentWidth
local _width = display.contentWidth
local _height = display.contentHeight
local leftPad
local bottomPad
local rightPad
local topPad

-- Draws a checkerboard for debug things
local function drawCheckerboard()
    local yMax = math.ceil(display.contentHeight/CN.COL_WIDTH)
    print("x: 10, y: "..yMax)
    for y = 0, yMax, 1 do
        for x = 0, CN.COL_NUM, 1 do
            local rect = display.newRect(backgroundGroup, (x*CN.COL_WIDTH) + CN.COL_WIDTH/2, (y*CN.COL_WIDTH) + CN.COL_WIDTH/2,
                CN.COL_WIDTH, CN.COL_WIDTH)
            if(((x+y)%2) == 0) then
                rect:setFillColor(.5, .5, .5)
            else
                rect:setFillColor(1,1,1)
            end
        end
    end
end

-- Sets object to nil, remove all children, remove all transitioners. If contained in activeObstacles, will be removed too
local function destroyObject(thisObject)
	if not thisObject then return end
    if thisObject.type == "null" then
    	if thisObject.children then
    		while #thisObject.children > 0 do -- Children will remove themselves from the parent
    			destroyObject(thisObject.children[1])
    		end
    	end

    	util.removeFromList(activeTransitioners, thisObject.linkedTransitioner)
    	thisObject.linkedTransitioner = nil

	    if util.tableContains(activeObstacles, thisObject) then
	    	util.removeFromList(activeObstacles, thisObject)
	    end

	    if thisObject.parent then
	    	util.removeFromList(thisObject.parent.children, thisObject)
	    end
    else
        thisObject.image:removeSelf()
        thisObject.image = nil
    	util.removeFromList(thisObject.parent.children, thisObject)
    end

    thisObject = nil
end

-- Clears everything from the screen
local function clearScreen()
    while activeObstacles[1] do
        destroyObject(activeObstacles[1])
    end
end

-- Updates all transition objects and corresponding null objects
local function updateTransitions(dt)
	local scaled_time = dt*time_scale
	local i = 1
	while i <= #activeTransitioners do
		local t = activeTransitioners[i]
		t.internal_time = t.internal_time + scaled_time

		local continue = true
		if (t.internal_time/t.total_time) >= 1 then
			if t.on_complete == "destroy" then
				destroyObject(t.linkedNull)
				i = 0 -- Just go through all transitioners again (Probably a better way to do this)
				continue = false
			elseif t.on_complete == "stop" then
				continue = false
			end
		end

		if continue then
			local time = t.internal_time%t.total_time

			-- Find the most recent frame percent
			local last_frame = -1
			local time_sum = 0
			time_sum = 0
			for i = 1, #t.transition_time, 1 do
				time_sum = time_sum + t.transition_time[i]
				if time < time_sum then
					last_frame = i
					break
				end
			end
			local next_frame = (last_frame%(#t.transition_time))+1
			local time_into_frame = time - (time_sum - t.transition_time[last_frame]) -- Time into transition
			local total_frame_time = t.transition_time[last_frame]
			local percent = time_into_frame/total_frame_time
			percent = util.scale(percent, "linear")

			-- Calculate new position
			local ori_pos = t.position_path[last_frame]
			local ori_rot = t.rotation_path[last_frame]
			local new_pos = t.position_path[next_frame]
			local new_rot = t.rotation_path[next_frame]
			local new_x = ori_pos.x+((new_pos.x-ori_pos.x)*percent)
			local new_y = ori_pos.y+((new_pos.y-ori_pos.y)*percent)
			local new_rot = ori_rot+((new_rot-ori_rot)*percent)

			t.linkedNull.x = new_x
			t.linkedNull.y = new_y
			t.linkedNull.rotation = new_rot

		end
		i = i + 1
	end
end

-- Creates the required corona object for a displayObject. Also adds object to physics engine
local function getImage(displayObject)
	local image
	if displayObject.type == "black_square" then
		image = display.newImageRect(obstacleGroup, "Game/Obstacle/black_square.png", CN.COL_WIDTH, CN.COL_WIDTH)
        imageOutline = graphics.newOutline(2, "Game/Obstacle/black_square.png")
    elseif displayObject.type == "spike" then
		image = display.newImageRect(obstacleGroup, "Game/Obstacle/spike.png", CN.COL_WIDTH, CN.COL_WIDTH)
        imageOutline = graphics.newOutline(2, "Game/Obstacle/spike.png")
    elseif displayObject.type == "coin" then
        image = display.newSprite(A.sheet_coin, A.sequences_coin)
        obstacleGroup:insert(image)
        image:play()
        image.collected = false
        imageOutline = graphics.newOutline(2, "Game/Item/coin_2d.png")
    elseif displayObject.type == "text" then
    	image = display.newText(obstacleGroup, thisObject.text, thisObject.x, thisObject.y, thisObject.font, thisObject.fontSize)
    	image:setFillColor( thisObject.color[1], thisObject.color[2], thisObject.color[3] )
    	imageOutline = nil
    end

    if displayObject.type ~= "text" then
    	physics.addBody(image, "static", {outline=imageOutline})
    end

    image.type = displayObject.type
	return image
end

-- Repositions a display object based on its ancestry
local function reposition(displayObject, ancestry)	
    local total_x = 0
    local total_y = 0
    local last_rot = 0
    local total_rot = 0

    for i = 1, #ancestry+1, 1 do
        local thisObject
        if i > #ancestry then
            thisObject = displayObject
        else
            thisObject = ancestry[i]
        end

        local r_x = thisObject.x*math.cos(math.rad(total_rot))-thisObject.y*math.sin(math.rad(total_rot))
        local r_y = thisObject.y*math.cos(math.rad(total_rot))+thisObject.x*math.sin(math.rad(total_rot))
        total_x = total_x + r_x
        total_y = total_y + r_y
        total_rot = total_rot + thisObject.rotation
        last_rot = thisObject.rotation
    end

    displayObject.image.x = total_x * CN.COL_WIDTH
    displayObject.image.y = total_y * CN.COL_WIDTH
    displayObject.image.rotation = total_rot
end

local function updateObstacle(obstacle, ancestry)
	if not obstacle then return end
	if not ancestry then ancestry = {} end

	if obstacle.type == "null" then
		if obstacle.children then
			for i = 1, #obstacle.children, 1 do
				local new_ancestry = util.shallowcopy(ancestry)
				new_ancestry[#new_ancestry+1] = obstacle
				updateObstacle(obstacle.children[i], new_ancestry)
			end
		end
	else
        if obstacle.image.needsRemoval == true then
            print("removing physics object")
            physics.removeBody(obstacle.image)
            obstacle.image.needsRemoval = false
        else
            reposition(obstacle, ancestry)
        end
	end
end

-- Returns a new transitioner object linked to the active obstacle
local function newTransitioner(obstacleData, linkedNull)
	-- We know obstacleData represents a null object
	local t = {} -- This transitioner
	t.name = obstacleData.name.."_transitioner"
	t.linkedNull = linkedNull

	-- Set internal time
    local internal_time = 0
    if obstacleData.time_offset then
    	internal_time = internal_time + time_offset
    end
    if obstacleData.first_frame ~= 1 then
    	local sum_time = 0
    	for i = 2, obstacleData.first_frame, 1 do
    		sum_time = sum_time + obstacleData.transition_time[i]
    	end
    	internal_time = internal_time + sum_time
    end
    t.internal_time = internal_time

    -- Calculate and set total time
    local total_time = 0
    for i = 1, #obstacleData.transition_time, 1 do
    	total_time = total_time + obstacleData.transition_time[i]
    end
    t.total_time = total_time

    -- Set animation data
    t.position_path = obstacleData.position_path
    t.rotation_path = obstacleData.rotation_path
    t.transition_time = obstacleData.transition_time
    t.position_interpolation = obstacleData.position_interpolation
    t.rotation_interpolation = obstacleData.rotation_interpolation
    t.on_complete = obstacleData.on_complete

    return t
end	

-- Returns a nestled obstacle. Creates all neccesary transitions for nulls in between
local function newObstacle(obstacleData, parent)
    if not obstacleData then return {} end
    local thisObject = {}
    thisObject.parent = parent

    if obstacleData.type == "null" then
    	thisObject.type = "null"
    	thisObject.name = obstacleData.name
    	thisObject.x = 0 -- Will be updated later
    	thisObject.y = 0
    	thisObject.rotation = 0

    	-- Create transitioner
    	local transitioner = newTransitioner(obstacleData, thisObject)
    	thisObject.linkedTransitioner = transitioner
    	table.insert(activeTransitioners, transitioner)

    	-- Get children
    	thisObject.children = {}
    	if obstacleData.children then
    		for i = 1, #obstacleData.children, 1 do
    			local newChild = newObstacle(obstacleData.children[i], thisObject)
    			table.insert(thisObject.children, newChild)
    		end
    	end
    else
    	thisObject.type = obstacleData.type -- Some display object
    	thisObject.name = obstacleData.type.."_display"
    	thisObject.x = obstacleData.x
    	thisObject.y = obstacleData.y
    	thisObject.rotation = obstacleData.rotation
    	thisObject.image = getImage(obstacleData)
    end

    return thisObject
end

-- Update score element
local function update_scoreText()
    scoreText.text = score
end

local function on_victory_tapped(event)
    print("on_victory_tapped")
    bubble.destroyBubbles()

    -- Remove victory thing
    event.target.text:removeSelf()
    event.target:removeSelf()

    -- Remove all obstacles still on screen
    clearScreen()

    composer.gotoScene("level_select")
end

local function gameOver()
    -- Creates temporary victory button with event listener
    local button = display.newRect(uiGroup, _width/2, _height/2,
    _width/2,_height/8)
    button:setFillColor(127,0,0)
    button:addEventListener("tap", on_victory_tapped)

    -- Adds text
    button.text = display.newText(uiGroup, "Back to level select",
        _width/2, _height/2,
        native.systemFont)
    button.text:setFillColor(0,0,0)
end

-- Gets new time scale from bubble_num (Maybe do a non-linear thing?)
local function getTimeScale(num_bubbles)
	local diff = CN.START_CLUMP_SIZE-num_bubbles
	local frac = diff/CN.START_CLUMP_SIZE
	local add = frac*1
	local goal = 1+add

	if time_scale < goal then
		-- print("increase time scale")
		return time_scale + .01
	elseif time_scale > goal then
		-- print("decrease time scale")
		return time_scale - .01
	else
		return time_scale
	end
end


local function onEnterFrame()
	if gameStarted then
		time_scale = getTimeScale(bubble.numBubbles())                -- Update time scale

		local t = system.getTimer()                                   -- Get change in time
		local dt = t - last_frame_time
		last_frame_time = t
		total_norm_sec = total_norm_sec + (time_scale*dt)

        if total_norm_sec > next_obstacle_time then                   -- Add next obstacle (If applicable)
            local obstacle_num = math.random(10)
            local obstacle
            local wait_time
            obstacle, wait_time = lb.obstacle(CN.BASE_OBSTACLE_TIME, 1)
            obstacle = newObstacle(obstacle, nil)
            table.insert(activeObstacles, obstacle)
            next_obstacle_time = total_norm_sec + wait_time
        end

		updateTransitions(dt)                                         -- Update transitioners and obstacles
		for i = 1, #activeObstacles, 1 do
			updateObstacle(activeObstacles[i])
		end

	    bubble.applyForce()                                            -- Apply bubble force
	    if gameStarted and (bubble.numBubbles() == 0) then
	        gameStarted = false
	        gameOver()
	    end

	    score = total_norm_sec                                         -- Update score and score text
	    update_scoreText()
    end
end

-- Does all the pagentry showing bubbles escaping the pipe etc...
-- Removes all intro-related graphics from screen itself
local function run_intro()
    print("running intro!")
    bubble.introBubbles(bubbleGroup, 10, util.newPoint(_width/2,5*_height/6))
end

-- Starts the game!
local function start_game()
    print("starting game")
    Runtime:addEventListener("enterFrame",onEnterFrame)
    
    time_scale = 1
    next_obstacle_time = 0
    total_norm_sec = 0
    last_frame_time = system.getTimer()

    gameStarted = true
end

-- Method tied to physics collision listener
local function onCollision(event)
    if(event.phase == "began") then

		local obj1 = event.object1
		local obj2 = event.object2

		--SPIKE COLLISION
		if(obj1.type == "bubble" and obj2.type == "spike") then
			if(event.element2 == 2) then
				return
			end
            bubble.popBubble(obj1)

		elseif(obj1.type == "spike" and obj2.type == "bubble") then
			if(event.element1 == 2) then
				return
			end
			bubble.popBubble(obj2)

        -- COIN COLLISION
		elseif(obj1.type == "bubble" and obj2.type == "coin") then
            if(event.element2 == 2) then
                return
            end
            obj2.isVisible = false
            obj2.needsRemoval = true

        elseif(obj1.type == "coin" and obj2.type == "bubble") then
            if(event.element1 == 2) then
                return
            end
            obj1.isVisible = false
            obj1.needsRemoval = true

        end
	end
end

-- Method tied to runtime touch listener -> Dispatches touched accordingly
local function onTouch(event)
    -- Will probably have to do some math here once you implement powerups to see if you are interacting with the UI
    bubble.onTouch(event)
end


local function addObstacle_tapped(event)
	print("addObstacle_tapped")
	local obstacle = newObstacle(lb.testObject(), nil)
	table.insert(activeObstacles, obstacle)
end

local function addTime_tapped(event)
	print("addTime_tapped")
	updateTransitions(2000)
	for i = 1, #activeObstacles, 1 do
		updateObstacle(activeObstacles[i])
	end
end


-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )

    local sceneGroup = self.view
    -- Code here runs when the scene is first created but has not yet appeared on screen

    activeDisplayObjects = {}
    activeNullObjects = {}

    -- Add display groups
    bubbleGroup = display.newGroup()
    obstacleGroup = display.newGroup()
    backgroundGroup = display.newGroup()
    uiGroup = display.newGroup()
    padGroup = display.newGroup()
    sceneGroup:insert(backgroundGroup)
    sceneGroup:insert(bubbleGroup)
    sceneGroup:insert(obstacleGroup)
    sceneGroup:insert(uiGroup)
    sceneGroup:insert(padGroup)

    -- Initialize borders
    leftBorder = display.newRect(-100, _height/2, 200, _height)
    rightBorder = display.newRect(_width+100, _height/2, 200, _height)
    topBorder = display.newRect(_width/2, -100, _width, 200)
    bottomBorder = display.newRect(_width/2, _height+100, _width, 200)
    leftBorder.type = "border"
    rightBorder.type = "border"
    topBorder.type = "border"
    bottomBorder.type = "border"
    obstacleGroup:insert(leftBorder)
    obstacleGroup:insert(rightBorder)
    obstacleGroup:insert(topBorder)
    obstacleGroup:insert(bottomBorder)

    -- Cover unused portions (Temporary solution)
    local sideWidth = (_right-_width)/2
    local topHeight = (_bottom-_height)/2

    leftPad = display.newRect(_left+(sideWidth/2), _top+(_bottom/2), sideWidth, _bottom)
    rightPad = display.newRect(_width+(sideWidth/2), _top+(_bottom/2), sideWidth, _bottom)
    topPad = display.newRect(_width/2, _top+(topHeight/2), _right, topHeight)
    bottomPad = display.newRect(_width/2, _height+(topHeight/2), _right, topHeight)

    leftPad:setFillColor(0,0,0)
    rightPad:setFillColor(0,0,0)
    topPad:setFillColor(0,0,0)
    bottomPad:setFillColor(0,0,0)
    
    -- Temporary white background (This should be replaced by backgroundGroup later)
    local bg = display.newRect(_width/2, _height/2, _width, _height)
    bg:setFillColor(1,1,1) -- This isn't the only white thing... I don't know why
    backgroundGroup:insert(bg)


    --[[
    -- Add obstacle button
 	local button = display.newRect(uiGroup, 3*display.contentWidth/4, 3*display.contentHeight/4,
 	display.contentWidth/2,display.contentHeight/8)
 	button:setFillColor(0,127,0)
 	button:addEventListener("tap", addObstacle_tapped)
 	local text = display.newText(uiGroup, "add obstacle", 
 		3*display.contentWidth/4, 3*display.contentHeight/4,
 		native.systemFont)
 	text:setFillColor(0,0,0)

 	-- Increase time button
 	local button = display.newRect(uiGroup, display.contentWidth/4, 3*display.contentHeight/4,
 	display.contentWidth/2,display.contentHeight/8)
 	button:setFillColor(127,0,0)
 	button:addEventListener("tap", addTime_tapped)
 	local text = display.newText(uiGroup, "add 1000", 
 		display.contentWidth/4, 3*display.contentHeight/4,
 		native.systemFont)
 	text:setFillColor(0,0,0)
    ]]--

    -- Initialize ui
    score = 0
    time_scale = 1
    total_norm_sec = 0
    scoreText = display.newText(uiGroup, score, _width/2, _height/8, native.systemFont, 36)
    scoreText:setFillColor(0,0,0)

    --drawCheckerboard()
end


-- show()
function scene:show( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is still off screen (but is about to come on screen)
        util.printMemUsage()
        last_frame_time = system.getTimer()

        -- Initialize level data
        local level = composer.getVariable("level")
        level_data = require ("Levels."..level)

        print("Here we are, playing level ".. level_data.name)
        if level_data.startScore then
            score = level_data.startScore
        else
            score = 0
        end

        update_scoreText()

    elseif ( phase == "did" ) then
        -- Code here runs when the scene is entirely on screen

        -- Start the physics!
        physics.start()
        physics.setGravity(0,0)
        physics.setDrawMode("normal")
        Runtime:addEventListener("collision", onCollision) -- This should probably move somewhere else but it is here for now
        Runtime:addEventListener("touch", onTouch)

        -- Add borders to Physics
        local borderProperties = {density = 1.0, bounce = 0.2}
        physics.addBody(leftBorder,"static", borderProperties)
        physics.addBody(rightBorder,"static", borderProperties)
        physics.addBody(topBorder,"static", borderProperties)
        physics.addBody(bottomBorder,"static", borderProperties)

        -- Run the intro, then start the game!
        run_intro()
        timer.performWithDelay(100, start_game)
    end
end


-- hide()
function scene:hide( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is on screen (but is about to go off screen)
        Runtime:removeEventListener("enterFrame",onEnterFrame)

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
