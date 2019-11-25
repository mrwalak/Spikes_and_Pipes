-- Utilities! (yay?)

local CN = require("crazy_numbers")
local util = {}

-- Table clone method (Put this somewhere else when you are done plz)
-- Credit: http://lua-users.org/wiki/CopyTable
function util.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[util.deepcopy(orig_key)] = util.deepcopy(orig_value)
        end
        setmetatable(copy, util.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Clones a table at the first level
function util.shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for i = 1, #orig, 1 do
            copy[i] = orig[i]
        end
    else
        copy = orig
    end
    return copy
end

-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
-- Credit: https://gist.github.com/hashmal/874792
function util.tprint (tbl, indent)
if not indent then indent = 0 end
for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
if type(v) == "table" then
print(formatting)
util.tprint(v, indent+1)
else
    if type(v) == "function" then
        print(formatting .. "some funciton")
    else
        print(formatting .. v)
    end
end
end
end

-- Returns a Point object (x,y) pair
function util.newPoint(x_in, y_in)
    local point = {x=x_in, y=y_in}
    return point
end

-- Prints the name and nestled objects for an obstacle_data data structure
function util.printObstacleData(data, indent)
    if not data then return end
    if not indent then indent = 0 end
    local formatting = string.rep("\t", indent)

    if type(data) == "table" then
        print(formatting..data.name..":")
    elseif type(data) == "string" then
        print(formatting..data)
    end

    for i = 1, #data.objects, 1 do
        util.printObstacleData(data.objects[i], indent+1)
    end
end

-- Prints memory usage data
-- Credit: https://forums.coronalabs.com/topic/22091-guide-findingsolving-memory-leaks/
function util.printMemUsage()
    local memUsed = (collectgarbage("count")) / 1000
    local texUsed = system.getInfo( "textureMemoryUsed" ) / 1000000

    print("\n---------MEMORY USAGE INFORMATION---------")
    print("System Memory Used:", string.format("%.03f", memUsed), "Mb")
    print("Texture Memory Used:", string.format("%.03f", texUsed), "Mb")
    print("------------------------------------------\n")

    return true
end

-- returns true if table contains entry, false otherwise
function util.tableContains(tbl, item)
    if not tbl then return false end
    if not type(tbl) == "table" then return false end
    for i = 1, #tbl, 1 do
        if tbl[i] == item then return true end
    end
    return false
end

-- removes item from list. Returns true if success, false otherwise
function util.removeFromList(tbl, item)
    if not tbl then return false end
    if not type(tbl) == "table" then return false end
    for i = 1, #tbl, 1 do
        if tbl[i] == item then
            table.remove(tbl, i)
            return true
        end
    end
    print("removeFromList() ERROR: item not found in list")
    return false
end

-- Extends adds the elements of tbl2 to tbl1
function util.tableExtend(tbl1, tbl2)
    if not tbl1 then tbl1 = {} end
    if not tbl2 then return end
    if type(tbl2) ~= "table" then table.insert(tbl1, tbl2) end

    local start_i = #tbl1
    for i = 1, #tbl2, 1 do
        tbl1[start_i+i] = tbl2[i]
    end
end

-- deepcopies item n times
function util.list(item, n)
	local result = {}
	for i = 1, n, 1 do
		table.insert(result, util.deepcopy(item))
	end
	return result
end

-- ******************************** LEVEL BUILDING UTILITIES ***************************************

-- Returns the default parent object that travels from the top of the
-- screen to the bottom in a given ammount of time (Stored in speed)
function util.newParentObstacle(speed, name)
	if not name then name = "Parent" end
    local BOTTOM_Y = (display.contentHeight/CN.COL_WIDTH)
    local MIDDLE_X = (display.contentWidth/CN.COL_WIDTH)/2
    local parent = {
        type = "null",
        name = name,
        position_path = {util.newPoint(MIDDLE_X, BOTTOM_Y), util.newPoint(MIDDLE_X, 0)},
        rotation_path = {0,0},
        transition_time = {speed, speed},
        position_interpolation = easing.linear,
        rotation_interpolation = easing.linear,
        on_complete = "destroy",
        first_frame = 2,
        children = {}
    }
    return parent
end

-- THE FOLLOWING LEVEL BUILDING UTILITIES ALL RETURN A TABLE OF OBJECTS (NULL OR DISPLAY)

function util.newCoin(x,y)
	local coin = {}
	coin.type = "coin"
	coin.x = x
	coin.y = y
	coin.rotation = 0
	return coin
end

function util.newBlackSquare(x, y, rot)
    local square = {}
    square.type = "black_square"
    square.x = x
    square.y = y
    square.rotation = rot
    return square
end

function util.newSpikePoint(x, y, rot)
    local spike = {}
    spike.type = "spike"
    spike.x = x
    spike.y = y
    spike.rotation = rot
    return spike
end

function util.newSpike(x,y, isVertical)
    local topSpike
    local block
    local bottomSpike

    if isVertical then
    	topSpike = util.newSpikePoint(x, y-1, 0)
   		block = util.newBlackSquare(x, y, 0)
    	bottomSpike = util.newSpikePoint(x, y+1, 180)
    else
    	topSpike = util.newSpikePoint(-1+x, y, 270)
    	block = util.newBlackSquare(x, y, 0)
    	bottomSpike = util.newSpikePoint(x+1, y, 90)
    end

    return {topSpike, block, bottomSpike}
end

function util.newSpikeList(n, isVertical)
	local result = {}
	for i = 1, n, 1 do
		table.insert(result, util.newSpike(0,0,isVertical))
	end
	return result
end

-- Wraps list of objects around a path (and loops)
-- number of objects and number of path vertices must be equal
-- Used to create line, square, polygon, and other looping fun things
function util.wrapLoopPath(nullModel, objectList)
	local result = {}
	for i = 1, #nullModel.position_path, 1 do
		local thisObject = util.deepcopy(nullModel)
		if objectList[i] then
			util.tprint(objectList[i])
			util.tableExtend(thisObject.children, objectList[i])
			thisObject.first_frame = i
			table.insert(result, thisObject)
		end
	end
	return result
end


-- Simple spike line from x to y, loops endlessly
function util.newLineModel(startPoint, endPoint, num_spikes, period)
    local nullModel = {}
    nullModel.type = "null"
    nullModel.name = "SpikeLineNull"
    nullModel.position_interpolation = easing.linear
    nullModel.rotation_interpolation = easing.linear
    nullModel.on_complete = "loop"
    nullModel.children = {}

    -- Set position_path, rotation_path, transition_time
    local position_path = {}
    local rotation_path = {}
    local transition_time = {}
    for i = 1, (num_spikes+1), 1 do
        local dx = ((endPoint.x-startPoint.x)/num_spikes) * (i-1)
        local dy = ((endPoint.y-startPoint.y)/num_spikes) * (i-1)
        local x = dx + startPoint.x
        local y = dy + startPoint.y
        table.insert(position_path, util.newPoint(x, y))
        table.insert(rotation_path, 0)
        if i == 1 then
            table.insert(transition_time, 0)
        else
            table.insert(transition_time, period/num_spikes)
        end
    end
    nullModel.position_path = position_path
    nullModel.rotation_path = rotation_path
    nullModel.transition_time = transition_time

    return nullModel
end


-- Creates a new square (4 vertices) with 4 spikes
function util.new4SquareModel(center, edge_size, period)
	local nullModel = {}
    nullModel.type = "null"
    nullModel.name = "4SquareModel"
    nullModel.position_interpolation = easing.linear
    nullModel.rotation_interpolation = easing.linear
    nullModel.on_complete = "loop"
    nullModel.children = {}

    -- Set position_path, rotation_path, transition_time
    local position_path = {}
    local rotation_path = {}
    local transition_time = {}
    local max = edge_size/2
    for i = 1, 4, 1 do
    	local xSign = 1
    	local ySign = 1
    	if (i == 1) or (i == 4) then
    		xSign = -1
    	end
    	if (i == 3) or (i == 4) then
    		ySign = -1
    	end

    	table.insert(position_path, util.newPoint(center.x + xSign*max, center.y + ySign*max))
    	table.insert(transition_time, period/4)
    	table.insert(rotation_path, 0)
    end
    nullModel.position_path = position_path
    nullModel.rotation_path = rotation_path
    nullModel.transition_time = transition_time

    return nullModel
end

return util
