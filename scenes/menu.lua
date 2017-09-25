local composer = require( "composer" )
local scene = composer.newScene()
local runtime = require("libraries.runtime")
local starfield = require("libraries.starfield")
local db = require("libraries.db")
runtime.settings["currentscene"] = "menu"

-- Initialize variables
local background, title, playButton, highScoresButton, gamesplayed
local sceneGroup, bgGroup, fgGroup, bgLayer1, bgLayer2, bgStars, bgTimer, btn_config, btn_about
local ticksUntilScroll = 0
local _W = display.contentWidth
local _H = display.contentHeight

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
                if id == "play" then
                    runtime.playSound("select")
                    gamesplayed = gamesplayed + 1
                    db.saveSetting("gamesplayed", gamesplayed)
                    runtime.logger("Lifetime games played: " .. gamesplayed)
                    composer.removeScene( "scenes.game" )
                    composer.gotoScene( "scenes.game", { effect = "crossFade", time = 400 } )         
                elseif id == "about" then
                    runtime.playSound("select")
                    composer.gotoScene( "scenes.gameAbout", { effect = "slideRight", time = 400 } )
                elseif id == "config" then
                    runtime.playSound("select")
                    composer.gotoScene( "scenes.gameConfig", { effect = "slideLeft", time = 400 } )
                elseif id == "scores" then
                    runtime.playSound("select")
                    composer.removeScene( "scenes.highscores" )
                    composer.gotoScene( "scenes.highscores", { effect = "slideRight", time = 400 } )
                end
            end
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
    fgGroup = display.newGroup()
    sceneGroup:insert(fgGroup)
    
	title = display.newImageRect( sceneGroup, "images/title.png", 350, 175 )
	title.x = _W * 0.5
	title.y = _H * 0.25
	fgGroup:insert(title)

    playButton = display.newImageRect(sceneGroup,"images/playButton.png", 250, 100)
    playButton.x, playButton.y = display.contentCenterX, _H * 0.66
	playButton.id = "play"
    playButton:addEventListener( "touch", buttonTouched )
    fgGroup:insert(playButton)

    highScoresButton = display.newImageRect(sceneGroup,"images/scoresButton.png", 250, 100)
    highScoresButton.x, highScoresButton.y = display.contentCenterX, _H * 0.8   
	highScoresButton.id = "scores"
	highScoresButton:addEventListener( "touch", buttonTouched )
	fgGroup:insert(highScoresButton)

    btn_config = display.newImageRect(sceneGroup,"images/config.png", 60, 60)
    btn_config.id = "config"
    btn_config.x = _W - 60
    btn_config.y = _H - 60
    btn_config:addEventListener("touch", buttonTouched)

    btn_about = display.newImageRect(sceneGroup,"images/about.png", 60, 60)
    btn_about.id = "about"
    btn_about.x = 60
    btn_about.y = _H - 60
    btn_about:addEventListener("touch", buttonTouched)
    
    gamesplayed = runtime.settings["gamesplayed"]
    if gamesplayed == nil then gamesplayed = 0; end
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)
        Runtime:addEventListener("enterFrame",gameTick)
	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
		-- Start the music!
		runtime.playBackgroundTrack()
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
        Runtime:removeEventListener("enterFrame",gameTick)
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
