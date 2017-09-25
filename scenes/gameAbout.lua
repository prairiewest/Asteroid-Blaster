local composer = require( "composer" )
local scene = composer.newScene()
local runtime = require("libraries.runtime")
runtime.settings["currentscene"] = "gameAbout"

local _W = display.contentWidth
local _H = display.contentHeight 
local screenGroup, mainGroup
local menuButton, menuText
local moreButtonBG, moreButtonText
local rateButtonBG, rateButtonText
local labels = {}
local values = {}

local function rateThisTouched(event)
	runtime.playSound("select") 
    local options =
    {
       iOSAppId = runtime.settings["iOSAppId"],
       supportedAndroidStores = { "google", "samsung", "amazon" },
    }
    native.showPopup( "rateApp", options )
end

local function moreAppsTouched(event)
	runtime.playSound("select") 
	system.openURL(runtime.settings["otherappsurl"]) 
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
            end
        end
    end
end

local function newCreditLabel(whichGroup,textLabel,x,y)
    newCredit = display.newText(whichGroup,textLabel, x, y, native.systemFont, creditFontSize)
    newCredit.anchorY = 0
    newCredit.anchorX = 0
    newCredit:setFillColor(0.3,0.6,1)
end

local function newCreditValue(whichGroup,textLabel,x,y)
    newCredit = display.newText(whichGroup,textLabel, x, y, native.systemFont, creditFontSize)
    newCredit.anchorY = 0
    newCredit.anchorX = 0
    newCredit:setFillColor(1,1,1)
end

function scene:create(event)
	screenGroup = self.view
	mainGroup = display.newGroup()
	screenGroup:insert(mainGroup)
	local creditFontSize = 24
	local creditLineHeight = 38
	local labelX = 20
	local valueX = 80
	local currentY = 240
	
	local background = display.newRect(mainGroup,_W*0.5,_H*0.5,_W,_H)
	background:setFillColor(0,0,0)

	local credits = display.newText(mainGroup,"Credits", _W*0.5, 125, native.systemFont, 48)
	credits:setFillColor(1,1,1)
	
	newCreditLabel(mainGroup,"Programming:", labelX, currentY)
	currentY = currentY + creditLineHeight
	newCreditValue(mainGroup,"Corona Labs", valueX, currentY)
	currentY = currentY + creditLineHeight
	newCreditValue(mainGroup,"Todd Trann", valueX, currentY)
    currentY = currentY + creditLineHeight * 2

    newCreditLabel(mainGroup,"Sound:", labelX, currentY)
    currentY = currentY + creditLineHeight
    newCreditValue(mainGroup,"soundcloud.com/djx-space", valueX, currentY)
    currentY = currentY + creditLineHeight
    newCreditValue(mainGroup,"aries-4rce-beatz.com", valueX, currentY)
    currentY = currentY + creditLineHeight
    newCreditValue(mainGroup,"soundcloud.com/submergedvisitor", valueX, currentY)
    currentY = currentY + creditLineHeight * 2
    
    newCreditLabel(mainGroup,"Graphics:", labelX, currentY)
    currentY = currentY + creditLineHeight
    newCreditValue(mainGroup,"www.kenney.nl", valueX, currentY)
    currentY = currentY + creditLineHeight
	
	--Add a menu button
    menuButton = display.newImageRect(mainGroup,"images/menuButton.png", 250, 100)
    menuButton.x, menuButton.y = display.contentCenterX, _H * 0.8
    menuButton.id = "menu"
    menuButton:addEventListener( "touch", buttonTouched )
	
	if (runtime.settings["showotherapps"]) then
		moreButtonBG = display.newImageRect(mainGroup,"images/rect_btn.png", 200, 60)
			moreButtonBG:addEventListener("tap", moreAppsTouched )
			moreButtonBG.anchorX = 0.5
			moreButtonBG.anchorY = 0.5
			moreButtonBG.x = 120
			moreButtonBG.y = _H - 90
					
		moreButtonText = display.newText(mainGroup,"More Apps", 0, 0, native.systemFont, creditFontSize)
			moreButtonText:setFillColor(0.2,0.2,0.2)
			moreButtonText.anchorX = 0.5
			moreButtonText.anchorY = 0.5
			moreButtonText.x = 120
			moreButtonText.y = _H - 90
	end
			
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
		if (runtime.settings["showotherapps"]) then
			moreButtonBG:removeEventListener("tap", moreAppsTouched )
		end
		if (runtime.settings["showratebutton"]) then
			rateButtonBG:removeEventListener("tap", rateThisTouched )
		end
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

