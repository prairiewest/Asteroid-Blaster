local composer = require( "composer" )
local scene = composer.newScene()
local starfield = require("libraries.starfield")
local widget = require("widget")
local runtime = require("libraries.runtime")
runtime.settings["currentscene"] = "highscores"

-- Initialize variables
local json = require( "json" )

local scoresTable = {}
local filePath = system.pathForFile( "scores.json", system.DocumentsDirectory )
local ticksUntilScroll = 0
local _W = display.contentWidth
local _H = display.contentHeight
local frmUsername, sceneGroup, highScoresHeader, yourNameLabel, btnBack, btn, menuButton
local saveTouched, showScoreList, newHighScore

local function loadScores()

	local file = io.open( filePath, "r" )

	if file then
		local contents = file:read( "*a" )
		io.close( file )
		scoresTable = json.decode( contents )
	end

	if ( scoresTable == nil or #scoresTable == 0 ) then
		scoresTable = {}
		for i = 1,10 do
		  scoresTable[i] = {}
		  scoresTable[i]["score"] = 0
		  scoresTable[i]["name"] = ""
		end
	end
end


local function saveScores()

	for i = #scoresTable, 11, -1 do
		table.remove( scoresTable, i )
	end

	local file = io.open( filePath, "w" )

	if file then
		file:write( json.encode( scoresTable ) )
		io.close( file )
	end
end


local function buttonTouched(event)
    local t = event.target
    local id = t.id

    if event.phase == "began" then 
        display.getCurrentStage():setFocus( t )
        t.isFocus = true
        t.alpha = 0.7

    elseif t.isFocus then
        if event.phase == "ended" then 
            display.getCurrentStage():setFocus( nil )
            t.isFocus = false
            t.alpha = 1
            local b = t.contentBounds
            if event.x >= b.xMin and event.x <= b.xMax and event.y >= b.yMin and event.y <= b.yMax then       
                if id == "menu" then
                    runtime.playSound("select")
                    composer.gotoScene( "scenes.menu", { effect = "slideLeft", time = 400 } )
                end
                if id == "save" then
                    timer.performWithDelay( 30, function() saveTouched(); end, 1 )
                end
            end
        end
    end
end

saveTouched = function()
    local username = frmUsername.text
    native.setKeyboardFocus(nil)
    -- Insert the saved score from the last game into the table
    local newScore = {}
    newScore["name"] = username
    newScore["score"] = runtime.finalScore
    table.insert( scoresTable, newScore )
    runtime.finalScore = 0

    -- Sort the table entries from highest to lowest
    local function compare( a, b )
        return a["score"] > b["score"]
    end
    table.sort( scoresTable, compare )

    -- Save the scores
    saveScores()
    
    display.remove(highScoresHeader)
    display.remove(yourNameLabel)
    display.remove(frmUsername)
    display.remove(btnBack)
    display.remove(btn)
    showScoreList()
end

local function showInputForm()
    highScoresHeader = display.newText( sceneGroup, "New High Score!", display.contentCenterX, 100, native.systemFont, 44 )
    yourNameLabel = display.newText( sceneGroup, "Your name:", _W * 0.1, 220, native.systemFont, 38 )
    yourNameLabel.anchorX = 0
    frmUsername = native.newTextField(0, 0, _W*0.8, 60)
        frmUsername.inputType = "default"
        frmUsername.font = native.newFont(font, 36)
        frmUsername.hasBackground = true
        frmUsername.isEditable = true
        frmUsername.align = "left"
        frmUsername.x = _W * 0.5
        frmUsername.y = 300
        frmUsername.text = ''
   sceneGroup:insert(frmUsername)
        
    btnBack = display.newImageRect(sceneGroup, "images/button_white.png", 160, 60)
        btnBack.anchorX, btnBack.anchorY = 0.5,0.5
    
    btn = widget.newButton({
        id = "save",
        left = _W * 0.55,
        top = 365,
        label = "Save",
        width = 256,
        height = 36,
        font = native.systemFont,
        fontSize = 30,
        labelColor = {
            default = {0,0,0},
            over = {255,255,255}
        },
        defaultColor = {201,107,61},
        overColor = {219,146,85},
        onEvent = buttonTouched
       })
       sceneGroup:insert(btn)
       
    -- Align the button background to be under the actual button
    btnBack.x, btnBack.y = btn.x, btn.y+1
end

showScoreList = function()
    local highScoresHeader = display.newText( sceneGroup, "High Scores", display.contentCenterX, 100, native.systemFont, 44 )

    for i = 1, 10 do
        if ( scoresTable[i]["score"] ) then
            local yPos = 150 + ( i * 50 )

            local rankNum = display.newText( sceneGroup, scoresTable[i]["score"], display.contentCenterX-50, yPos, native.systemFont, 32 )
            rankNum:setFillColor(0.3,0.6,1)
            rankNum.anchorX = 1

            local thisScore = display.newText( sceneGroup, scoresTable[i]["name"], display.contentCenterX-30, yPos, native.systemFont, 32 )
            thisScore:setFillColor(1,1,1)
            thisScore.anchorX = 0
        end
    end
end

local function gameTick()
    if ticksUntilScroll < 1 then
        starfield.scroll(1)
        ticksUntilScroll = runtime.scrollRate
    else
        ticksUntilScroll = ticksUntilScroll - 1
    end
end

function scene:create( event )
	sceneGroup = self.view
    starfield.create(scene)
	loadScores()
	
	newHighScore = false
	for i = 1,10 do
	   if runtime.finalScore > scoresTable[i]["score"] then
	       newHighScore = true
	   end
	end

    if newHighScore then
        showInputForm()
    else
        showScoreList()
    end

    menuButton = display.newImageRect(sceneGroup,"images/menuButton.png", 250, 100)
    menuButton.x, menuButton.y = display.contentCenterX, _H * 0.8
    menuButton.id = "menu"
    menuButton:addEventListener( "touch", buttonTouched )
end


function scene:show( event )
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)
        Runtime:addEventListener("enterFrame",gameTick)

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
		if newHighScore then
		   native.setKeyboardFocus(frmUsername)
		end
	end
end


function scene:hide( event )
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
		Runtime:removeEventListener("enterFrame",gameTick)
        native.setKeyboardFocus(nil)
	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
	end
end


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
