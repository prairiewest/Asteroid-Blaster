local composer = require( "composer" )
local scene = composer.newScene()
local runtime = require("helpers.runtime")

runtime.settings["currentscene"] = "cutscene"

-- Setup the display groups we want
local screenGroup
local gameGroup

-- Some handy maths vars
local _W = display.contentWidth
local _H = display.contentHeight
local background

-----------------------------------------------
-- *** COMPOSER SCENE EVENT FUNCTIONS ***
------------------------------------------------
function scene:create( event )
	screenGroup = self.view

	bgGroup = display.newGroup()
	screenGroup:insert(bgGroup)
    
    -- Create the background
    background = display.newRect(bgGroup,_W*0.5,_H*0.5,_W,_H)
    background:setFillColor(unpack(runtime.backgroundColour))
    background.id = "play"    
end

function scene:show( event )
    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Called when the scene is still off screen (but is about to come on screen).
		
    elseif ( phase == "did" ) then
        -- Called when the scene is now on screen.
        -- Insert code here to make the scene come alive.
        -- Example: start timers, begin animation, play audio, etc.
        composer.removeHidden()  --Remove all other scenes, not really needed in this template. 
		timer.performWithDelay(300, function()
			composer.gotoScene( "scenes.game", {effect = "crossFade",time=100,params={y=240}}  )
		end, 1)
    end
end

function scene:hide( event )
    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Called when the scene is on screen (but is about to go off screen).
        -- Insert code here to "pause" the scene.
        -- Example: stop timers, stop animation, stop audio, etc.

    elseif ( phase == "did" ) then
        -- Called immediately after scene goes off screen.
    end
end

function scene:destroy( event )
    local sceneGroup = self.view

    -- Called prior to the removal of scene's view ("sceneGroup").
    -- Insert code here to clean up the scene.
    -- Example: remove display objects, save state, etc.
	runtime.stopAllSounds()
end


-- Then add the listeners for the above functions
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )


return scene