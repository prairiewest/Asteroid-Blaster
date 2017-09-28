local composer = require( "composer" )
local scene = composer.newScene()
local runtime = require("libraries.runtime")
local db = require("libraries.db")
runtime.settings["currentscene"] = "controlChoice"

local _W = display.contentWidth
local _H = display.contentHeight 

local screenGroup, mainGroup, settingsLabel, playButton
local controls1, controls2, controls3, chooseLabel

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
                if id == "tilt" or id == "tap" or id == "drag" or id == "keyboard" or id == "mouse" then
                    runtime.playSound("select")
                    db.saveSetting("controls", id)
                    composer.gotoScene( "scenes.game", { effect = "crossFade", time = 400 } )
                end
            end
        end
    end
end


function scene:create( event )
	screenGroup = self.view
	mainGroup = display.newGroup()
	screenGroup:insert(mainGroup)

	-- Background
	local background = display.newRect(mainGroup,_W*0.5,_H*0.5,_W,_H)
	background:setFillColor(0,0,0)
	
	settingsLabel = display.newText(mainGroup,"Controls", 0, 0, native.systemFont, 40)
	settingsLabel.x = _W * 0.5;
	settingsLabel.y = 60;
	settingsLabel:setFillColor(1,1,1 )

    chooseLabel = display.newText(mainGroup,"Please choose:", 0, 0, native.systemFont, 40)
    chooseLabel.x = _W * 0.5;
    chooseLabel.y = 180;
    chooseLabel:setFillColor(230/255, 230/255, 230/255 )
            
    if system.hasEventSource("accelerometer") and runtime.settings["platform"] ~= "simulator" then   
        controls1 = display.newImageRect(mainGroup,"images/controls_tilt.png", 380, 160)
        controls1.x, controls1.y = _W * 0.5, _H * 0.35
        controls1.id = "tilt"
        controls1:addEventListener( "touch", buttonTouched )
        
        controls2 = display.newImageRect(mainGroup,"images/controls_drag.png", 380, 160)
        controls2.x, controls2.y = _W * 0.5, _H * 0.55
        controls2.id = "drag"
        controls2:addEventListener( "touch", buttonTouched )        

        controls3 = display.newImageRect(mainGroup,"images/controls_tap.png", 380, 160)
        controls3.x, controls3.y = _W * 0.5, _H * 0.75
        controls3.id = "tap"
        controls3:addEventListener( "touch", buttonTouched ) 
    else
        controls1 = display.newImageRect(mainGroup,"images/controls_keyboard.png", 380, 160)
        controls1.id = "keyboard"
        controls1.x, controls1.y = _W * 0.5, _H * 0.40
        controls1:addEventListener( "touch", buttonTouched ) 

        controls2 = display.newImageRect(mainGroup,"images/controls_mouse.png", 380, 160)
        controls2.id = "mouse"
        controls2.x, controls2.y = _W * 0.5, _H * 0.70
        controls2:addEventListener( "touch", buttonTouched ) 
                
    end

end

function scene:show( event )
    local phase = event.phase

    if ( phase == "will" ) then
        -- Called when the scene is still off screen (but is about to come on screen).
    elseif ( phase == "did" ) then
        -- Called when the scene is now on screen.
    end
end


function scene:hide( event )
    local phase = event.phase

    if ( phase == "will" ) then
        -- Called when the scene is on screen (but is about to go off screen).
        -- Insert code here to "pause" the scene.
        
    elseif ( phase == "did" ) then
        -- Called immediately after scene goes off screen.
    end
end

function scene:destroy( event )
    -- Called prior to the removal of scene's view ("sceneGroup").

end

-- Then add the listeners for the above functions
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene

