local composer = require( "composer" )
local scene = composer.newScene()
local runtime = require("libraries.runtime")
local db = require("libraries.db")
runtime.settings["currentscene"] = "gameConfig"
local widget = require ("widget")

--Vars...
local _W = display.contentWidth
local _H = display.contentHeight 

local screenGroup, mainGroup, settingsLabel, menuBtn, menuText, bgLabel, menuButton
local bgSlider, fxLabel, fxSlider
local previewSoundPlaying = false

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
                    composer.gotoScene( "scenes.menu", { effect = "slideRight", time = 400 } )
                end
            end
        end
    end
end

local function bgSliderListener( event )
	local sliderValue = event.value
	local logValue
	if sliderValue == nil then sliderValue = 0 end
	if (sliderValue > 0) then
		logValue = (math.pow(3,sliderValue/100)-1)/(3-1)
	else
		logValue = 0.0
	end
	runtime.settings["bgvolume"] = logValue
	runtime.setChannelVolumes()
end

local function fgSliderListener( event )
	local sliderValue = event.value
	local logValue
	if sliderValue == nil then sliderValue = 0 end
	if (sliderValue > 0) then
		logValue = (math.pow(3,sliderValue/100)-1)/(3-1)
	else
		logValue = 0.0
	end
	runtime.settings["fxvolume"] = logValue
    runtime.setChannelVolumes()
    if (previewSoundPlaying == false) then
        previewSoundPlaying = true
        runtime.playSound("laser")
        timer.performWithDelay(250, function() previewSoundPlaying = false; end,1 );
    end
end

function scene:create( event )
	screenGroup = self.view
	mainGroup = display.newGroup()
	screenGroup:insert(mainGroup)

	-- Background
	local background = display.newRect(mainGroup,_W*0.5,_H*0.5,_W,_H)
	background:setFillColor(0,0,0)
	
	settingsLabel = display.newText(mainGroup,"Settings", 0, 0, native.systemFont, 40)
	settingsLabel.x = _W * 0.5;
	settingsLabel.y = 60;
	settingsLabel:setFillColor(230/255, 230/255, 230/255 )
	
	--Add a menu button
    menuButton = display.newImageRect(mainGroup,"images/menuButton.png", 250, 100)
    menuButton.x, menuButton.y = display.contentCenterX, _H * 0.8   
    menuButton.id = "menu"
    menuButton:addEventListener( "touch", buttonTouched )

	-- Background volume
	bgLabel = display.newText(mainGroup,"Background Volume", 0,0, native.systemFont, 30)
	bgLabel.anchorY = 1
	bgLabel.anchorX = 0
	bgLabel.x = 50; 
	bgLabel.y = 200; 
	bgLabel:setFillColor(230/255, 230/255, 230/255 )	

	bgSlider = widget.newSlider{
		top = bgLabel.y + 12,
		left = 50,
		width=440,
		height=10,
		value=(math.log((runtime.settings["bgvolume"] * (3-1)) + 1) / math.log(3)) * 100,
		background = "images/slider/sliderBg.png",
		fillImage = "images/slider/sliderFill.png",
		fillWidth = 2, 
		leftWidth = 16,
		handle = "images/slider/handle.png",
		handleWidth = 32, 
		handleHeight = 32,
		listener = bgSliderListener
	}
	mainGroup:insert( bgSlider )

	-- Effects volume
	fxLabel = display.newText(mainGroup, "Effects Volume", 0,0, native.systemFont, 30)
	fxLabel.anchorY = 1
	fxLabel.anchorX = 0
	fxLabel.x = 50; 
	fxLabel.y = 360; 
	fxLabel:setFillColor(230/255,230/255,230/255 )	

	fxSlider = widget.newSlider{
		top = fxLabel.y + 12,
		left = 50,
		width=440,
		height=10,
		value=(math.log((runtime.settings["fxvolume"] * (3-1)) + 1) / math.log(3)) * 100,
		background = "images/slider/sliderBg.png",
		fillImage = "images/slider/sliderFill.png",
		fillWidth = 2, 
		leftWidth = 16,
		handle = "images/slider/handle.png",
		handleWidth = 32, 
		handleHeight = 32,
		listener = fgSliderListener
	}
	mainGroup:insert( fxSlider )

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
        --composer.removeHidden()  --Remove all other scenes
    end
end


function scene:hide( event )
    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Called when the scene is on screen (but is about to go off screen).
        -- Insert code here to "pause" the scene.
        -- Example: stop timers, stop animation, stop audio, etc.
        db.saveSetting('bgvolume', runtime.settings["bgvolume"])
        db.saveSetting('fxvolume', runtime.settings["fxvolume"])
        
    elseif ( phase == "did" ) then
        -- Called immediately after scene goes off screen.
    end
end

function scene:destroy( event )
    local sceneGroup = self.view

    -- Called prior to the removal of scene's view ("sceneGroup").
	-- Remove any sound effects
	-- They must NOT be playing to be removed
	runtime.stopAllSounds()
end

-- Then add the listeners for the above functions
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

return scene

