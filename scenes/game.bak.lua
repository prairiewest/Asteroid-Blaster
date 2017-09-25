local composer = require( "composer" )
local scene = composer.newScene()
local utils = require("libraries.utils")
local runtime = require("libraries.runtime")

runtime.settings["currentscene"] = "game"

--[[
	ITEM	CATEGORY	MASK
	border	1			2
	player	2			29 (16 + 8 + 4 + 1)
	spike	4			34 (32 + 4)
	coin	8			2
	powerup	16			2
	laser	32			4
]]--

-- Require our physics library
local physics = require ("physics")	-- Require physics
physics.setDrawMode( "normal" )
--physics.setDrawMode( "hybrid" ) -- Set to hybrid to see the physics shapes.
physics.start()
physics.setGravity(0,30) -- Increase this value to make the player fall faster
	
-- Setup the display groups we want
local screenGroup
local bgGroup
local gameGroup

-- Local math vars
local _W = display.contentWidth
local _H = display.contentHeight
local mFloor = math.floor 
local mRand = math.random 
local mAbs = math.abs 
local mSin = math.sin
local toXLeft = -24 --Default left position (offscreen) (1/2 sprite height + 4)
local toXRight = _W + 24 --Default right position (offscreen)

-- Sprites
local background
local text_score
local text_rect 
local player = {}
local deadfish = {}
local spikes_left = {}
local spikes_right = {}
local spikes_topbottom = {}
local lasers = {}
local coin
local foam = {}
local foamDisappearing = false

-- Game control variables
local touchAllowed = true 
local isGameOver = false
local currentScore = 0 		-- Keeps track of the planks passed
local bestScore = 0 		-- Load this on game over
local playerShapeNormal = {-24,0, -14,-12, 14,-12, 24,0, 14,12, -14,12 } -- Physics shape for our player
local playerShapeSmall = {-12,0, -7,-6, 7,-6, 12,0, 7,6, -7,6 } 
local spikeVertices = {-20,-10, 20,-10, 8,6, 2,10, -2,10, -8,6}  -- The shape of our spikes

local playerTransition 		-- Used to fade the player out. 
local trailTimer 			-- Used to create the trail behind the player
local coinsCollected = 0  	-- Added to our total coins value at the end
local spikeSpeed = 0
local spikeAcceleration = 0.05
local maxSpikeSpeed = 5
local maxSpikeCount = 2
local minSpikeCount = 2
local newSpikesPerBounce = 0.18
local movesSinceLastPowerup = 0
local powerUpPill
local powerUpFallSpeed = 2
local powerUpRotateSpeed = 5
local pnum
local pobj
local currentlyKillingPlayer
local leftSideHasSpikes = 0
local lastPowerup = 0
local powerupArray
local scoreIncrement = 1
local playersCurrentlySmall = false
local canNuke = false
local nextNukeAtScore = 30
local explosionOptions
local explosionSheet
local explosionSprite
local languageFont
local isLaserPurchased = false
local powerupsSinceLastLaser = 4
local reverseGravity = false
local coinsPer = 1
local gamesBetweenAds = runtime.settings["gamesbetweenads"]
local gravityTimer
local gravityTimer2
local doublerTimer
local borderArray = {}
	
-- Pre-declare some functions
local backgroundTouched
local updateScore 
local gameOver
local gameTick
local onCollision
local removePlayerStage1
local animateDeadFishToTop
local createPlayerSprite
local handlePowerUp
local useBubble
local useHardhat
local useBombshield
local fireLaser
local explodeSpike
local swapSpikes
local impulsePlayer
local removeOneSpike

-----------------------------------------------
--*** Other Functions ***
-----------------------------------------------
function gameOver(withSound)
	coinsPer = 1
	local overGroup = display.newGroup()
	screenGroup:insert(overGroup)
	overGroup.y = _H
	if (withSound) then	runtime.playSound("gameover") end
	isGameOver = true
	touchAllowed = false

	-- Remove anything we need to
	if coin ~= nil then 
		transition.to(coin, {time=200, alpha=0.01, onComplete=function()
			display.remove(coin)
			if coin.setLinearVelocity and type(coin.setLinearVelocity) == "function" then
				physics.removeBody(coin)
			end
			coin = nil
		end})
	end
	if gravityTimer ~= nil then 
		timer.cancel(gravityTimer)
		gravityTimer = nil 
	end
	if gravityTimer2 ~= nil then 
		timer.cancel(gravityTimer2)
		gravityTimer2 = nil 
	end
	if doublerTimer ~= nil then 
		timer.cancel(doublerTimer)
		doublerTimer = nil 
	end
    if currentScore > utils.highscore then
        bestScore = currentScore;  utils.highscore = currentScore
        utils.saveHighscore()
    end

	utils.recordCoinsEarned(coinsCollected)

	-- Now make the game over screen
	local overText = display.newText({parent=overGroup,text=T.find("game_over"),font=languageFont,fontSize=28})
	overText.x = _W*0.5;	overText.y = mFloor(_H*0.20)
	overText:setFillColor(unpack(runtime.spikeColour))

	local overRect = display.newImageRect(overGroup,"images/rect_score.png", 225, 70)
	overRect.x = overText.x; overRect.y = overText.y + 80
    overRect:setFillColor(1)
    overRect.alpha = 0.6

	local overText1 = display.newText({parent=overGroup,text=currentScore,font=languageFont,fontSize=32})
	overText1.x = overRect.x;	overText1.y = overRect.y - 10
	overText1:setFillColor(255/255,53/255,110/255)

	local overText2 = display.newText({parent=overGroup,text=T.find("score"),font=languageFont,fontSize=18})
	overText2.x = overRect.x;	overText2.y = overRect.y + 18
	overText2:setFillColor(255/255,53/255,110/255)

	local replayRect = display.newImageRect(overGroup,"images/rect_btn.png", 225, 70)
	replayRect.x = overRect.x; replayRect.y = overRect.y + 75
	replayRect.id = "replay"

	local replayText = display.newText({parent=overGroup,text=T.find("new_game"),font=languageFont,fontSize=18})
	replayText.x = replayRect.x;	replayText.y = replayRect.y
	replayText:setFillColor(unpack(runtime.spikeColour))

	local menuRect = display.newImageRect(overGroup,"images/rect_btn.png", 225, 40)
	menuRect.x = overRect.x; menuRect.y = replayRect.y + 60
	menuRect.id = "menu"

	local menuText = display.newText({parent=overGroup,text=T.find("menu"),font=languageFont,fontSize=18})
	menuText.x = menuRect.x;	menuText.y = menuRect.y
	menuText:setFillColor(unpack(runtime.spikeColour))

	local shareRect = display.newImageRect(overGroup,"images/rect_btn.png", 225, 40)
	shareRect.x = overRect.x; shareRect.y = menuRect.y + 45
	shareRect.id = "share"

	local shareText = display.newText({parent=overGroup,text=T.find("share"),font=languageFont,fontSize=18})
	shareText.x = shareRect.x;	shareText.y = shareRect.y
	shareText:setFillColor(unpack(runtime.spikeColour))
	
	runtime.settings["games_this_session"] = runtime.settings["games_this_session"] + 1
	runtime.logger("Games this session: " .. runtime.settings["games_this_session"] )
	local touchDelay = 200
	if (runtime.settings["showads"] == true) then
    	if (runtime.settings["games_this_session"] % gamesBetweenAds == 0 and runtime.settings["madepurchase"] == 0) then
    		touchDelay = 1500
    		runtime.showAdMobAd("interstitial")
    	else
    	   runtime.checkAdIsLoaded("interstitial")
    	end
	end

	-- Transition it all in and give the buttons a touch listener
	local trans2 = transition.to(overGroup, {time=250, delay=200, y=0, onComplete=function()
		text_rect.isVisible = false
		text_score.isVisible = false
		overGroup:toFront()
		overGroup.isFocus = true

		local function buttonTouched(event)
			local t = event.target
			local id = t.id 
			
			if event.phase == "began" then 
				display.getCurrentStage():setFocus( t )
				t.isFocus = true
				t.alpha = 0.7
			
			elseif t.isFocus then 
				if event.phase == "ended"  then 
					display.getCurrentStage():setFocus( nil )
					t.isFocus = false
					t.alpha = 1

					local b = t.contentBounds
					if event.x >= b.xMin and event.x <= b.xMax and event.y >= b.yMin and event.y <= b.yMax then 
						runtime.playSound("select")

						if id == "share" then 
							local sharingPlatform = "facebook"
							local function file_exists(name)
								local f=io.open(name,"r")
								if f~=nil then io.close(f) return true else return false end
							end
							timer.performWithDelay(300,function() 
								display.save( screenGroup, { filename="screenshare.jpg", baseDir=system.DocumentsDirectory, jpegQuality=0.8} )
								local path = tostring(system.pathForFile("screenshare.jpg", system.DocumentsDirectory ))
								local function shareNow()
									local options = {
									    service = sharingPlatform,
									    message = T.find("share_part1") .. " " .. currentScore .. " " .. T.find("share_part2") .. " #SpikySwim http://spikyswim.com"
									}
									if (file_exists(path)) then
										options.image = {{ filename = "screenshare.jpg", baseDir = system.DocumentsDirectory }}
									end
									native.showPopup( "social", options )
								end
	
								if runtime.settings["platform"] == "Android" then 
									shareNow()
								else
									local function alertPressed(event)
										if event.index == 1 or event.index == 2 then 
											if event.index == 2 then 
												sharingPlatform = "twitter" 
											end
											shareNow()
										end
									end
									local alert = native.showAlert(T.find("share"), "Facebook / Twitter?", {"Facebook", "Twitter", "Cancel"}, alertPressed)
								end
							end)

						elseif id == "menu" then 
							replayRect:removeEventListener("touch", buttonTouched)
							menuRect:removeEventListener("touch", buttonTouched)
							shareRect:removeEventListener("touch", buttonTouched)
							composer.gotoScene( "scenes.menu", "crossFade", 200 )
						else
							-- replay the game
							local plays = runtime.settings["gamesplayed"]
        		            plays = plays + 1
							utils.saveSetting("gamesplayed",plays)
							runtime.logger("Lifetime games played: " .. plays)
							replayRect:removeEventListener("touch", buttonTouched)
							menuRect:removeEventListener("touch", buttonTouched)
							shareRect:removeEventListener("touch", buttonTouched)
							composer.gotoScene( "scenes.cutscene", "crossFade", 200 )
						end
					end
				end
			end
			return true
		end
		timer.performWithDelay(touchDelay,function() 
			replayRect:addEventListener("touch", buttonTouched)
			menuRect:addEventListener("touch", buttonTouched)
			shareRect:addEventListener("touch", buttonTouched)
		end)
	end})

end

local function gameSpriteListener( event )
  if ( event.phase == "ended" ) then
    gameGroup:remove(event.target)
    display.remove(event.target)
    event.target:removeEventListener("sprite", gameSpriteListener)
    event.target = nil
  end 
end

function updateScore(amount)
	if (amount == nil) then amount = scoreIncrement end
	local newScore = currentScore + amount
	if (currentScore < 100 and newScore >= 100) then
		display.remove(text_score)
		text_score = nil
		text_score = display.newText({parent=bgGroup,text=currentScore,font=languageFont,fontSize=70})
		text_score.x = text_rect.x
		text_score.y = text_rect.y + 4
		text_score:setFillColor(unpack(runtime.backgroundColour))
	end
	if (currentScore < 1000 and newScore >= 1000) then
		display.remove(text_score)
		text_score = nil
		text_score = display.newText({parent=bgGroup,text=currentScore,font=languageFont,fontSize=52})
		text_score.x = text_rect.x
		text_score.y = text_rect.y + 4
		text_score:setFillColor(unpack(runtime.backgroundColour))
	end
	currentScore = newScore
	text_score.text = currentScore
	runtime.playSound("score")
	if (currentScore > nextNukeAtScore) then
		canNuke = true
	end
end

function handlePowerUp(target, forcePillNumber)
	if (powerUpPill ~= nil or forcePillNumber > 0) then
		local whichPowerup = forcePillNumber
		if (powerUpPill ~= nil) then
			physics.removeBody(powerUpPill)
			whichPowerup = powerUpPill.whichPowerup
		end
		
		if (whichPowerup == 1) then
			if (target.bubble == nil) then
				-- Bubble is a double shield
				target.bubble = display.newImageRect(gameGroup,"images/bubble.png", 54, 32)
				target.bubble.x = target.x
				target.bubble.y = target.y
				target.bubble.xScale = target.xScale
				target.bubble.yScale = target.yScale
				target.bubbleCount = 2
			else
				target.bubbleCount = 2
			end
			
		elseif (whichPowerup == 2) then
			-- Flip causes spikes to travel the other way
			spikeSpeed = 0
			spikeAcceleration = 0 - spikeAcceleration
			
		elseif (whichPowerup == 3) then
			-- Plus adds more players
			createPlayerSprite(target)
			
		elseif (whichPowerup == 4) then
			-- Lightning zaps some spikes
			removeOneSpike()
			
		elseif (whichPowerup == 5) then
			-- hardhat is a single shield
			if (target.hardhat == nil) then
				-- Shield surrounds player
				target.hardhat = display.newImageRect(gameGroup,"images/hardhat.png", 54, 32)
				target.hardhat.x = target.x
				target.hardhat.y = target.y
				target.hardhat.xScale = target.xScale
				target.hardhat.yScale = target.yScale
				target.hardhatCount = 1
			end
			
		elseif (whichPowerup == 6) then
			-- Laser!!
			if (target.laser == nil) then
				target.laser = display.newImageRect(gameGroup,"images/laser.png", 54, 32)
				target.laser.x = target.x
				target.laser.y = target.y
				target.laser.xScale = target.xScale
				target.laser.yScale = target.yScale
				target.laserCount = 5
			end
			
		elseif (whichPowerup == 7) then
			-- Shrink
			if (target ~= nil and target.isDying == false) then
				target.isDying = true
				target.alpha = 0
				local params = {}			
				params.xScale = 0.6
				params.yScale = 0.6
				if (target.xScale < 0) then
					params.xScale = -0.6
				end
				params.x, params.y = target.x, target.y
				params.vx, params.vy = target:getLinearVelocity()
				params.bubble, params.bubbleCount = target.bubble, target.bubbleCount
				params.hardhat, params.hardhatCount = target.hardhat, target.hardhatCount
				params.bombshield, params.bombshieldCount = target.bombshield, target.bombshieldCount
				params.laser, params.laserCount = target.laser, target.laserCount
				params.isSmall = true
				local newtarget = createPlayerSprite(nil,params)
				newtarget.selftimer = timer.performWithDelay(6000, function()
					if (newtarget ~= nil) then
						newtarget.isDying = true
						newtarget.alpha = 0
						runtime.playSound("slideup")
						local params = {}			
						params.xScale = 1
						if (newtarget.xScale < 0) then
							params.xScale = -1
						end
						params.yScale = 1
						params.x, params.y = newtarget.x, newtarget.y
						params.vx, params.vy = newtarget:getLinearVelocity()
						params.bubble, params.bubbleCount = newtarget.bubble, newtarget.bubbleCount
						params.hardhat, params.hardhatCount = newtarget.hardhat, newtarget.hardhatCount
						params.bombshield, params.bombshieldCount = newtarget.bombshield, newtarget.bombshieldCount
						params.laser, params.laserCount = newtarget.laser, newtarget.laserCount
						params.isSmall = false
						createPlayerSprite(nil,params)
						removePlayerStage1(newtarget.pnum, false, false)
					end
				end, 1)
				removePlayerStage1(target.pnum, false, false)
			end
			
		elseif (whichPowerup == 8) then
			-- Nuke
			nextNukeAtScore = currentScore + 50
			canNuke = false
			timer.performWithDelay(1000, function()
				spikeSpeed = 0
				for i=1, #spikes_right do 
					spikes_right[i].x = toXRight
					spikes_right[i].onscreen = false
					timer.performWithDelay(60*mRand(1,10), function()
						local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)	
						explosionAnimation.x = _W - 20
						explosionAnimation.y = spikes_right[i].y
						explosionAnimation:setSequence("explosion")
						explosionAnimation:play()
						explosionAnimation:addEventListener("sprite", gameSpriteListener)
						gameGroup:insert(explosionAnimation)
					end, 1)
				end
				for i=1, #spikes_left do 
					spikes_left[i].x = toXLeft
					spikes_left[i].onscreen = false
					timer.performWithDelay(60*mRand(1,10), function()
						local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)	
						explosionAnimation.x = 20
						explosionAnimation.y = spikes_left[i].y
						explosionAnimation:setSequence("explosion")
						explosionAnimation:play()
						explosionAnimation:addEventListener("sprite", gameSpriteListener)
						gameGroup:insert(explosionAnimation)
					end, 1)
				end
				minSpikeCount = 0
				maxSpikeCount = 0
			runtime.playSound("nuke")
			end, 1)
			timer.performWithDelay(5000, function()
				minSpikeCount = 2
				maxSpikeCount = 2
			end, 1)
			
		elseif (whichPowerup == 9) then
			-- bomb is a single shield that blows up target
			if (target.bombshield == nil) then
				-- Shield surrounds player
				target.bombshield = display.newImageRect(gameGroup,"images/bombshield.png", 54, 32)
				target.bombshield.x = target.x
				target.bombshield.y = target.y
				target.bombshield.xScale = target.xScale
				target.bombshield.yScale = target.yScale
				target.bombshieldCount = 1
			end

		elseif (whichPowerup == 10) then
			-- Reverse gravity
			if gravityTimer ~= nil then 
				timer.cancel(gravityTimer)
				gravityTimer = nil 
			end
			if gravityTimer2 ~= nil then 
				timer.cancel(gravityTimer2)
				gravityTimer2 = nil 
			end
			local flipArrow = display.newImageRect(gameGroup,"images/gravityfliparrow.png", 290, 260)
			flipArrow.x = _W * 0.5
			flipArrow.y = _H * 0.5
			transition.to(flipArrow, {time=800,rotation=90,onComplete=function()
				display.remove(flipArrow)
				flipArrow = nil 
			end})
			gravityTimer2 = timer.performWithDelay(1000, function()
				physics.setGravity( 0, -30)
				reverseGravity = true
				for pnum,pobj in pairs(player) do
					if (pobj ~= nil and pobj.isDying == false) then
						local vx, vy = pobj:getLinearVelocity()
						pobj:setLinearVelocity(vx,0)
						pobj.yScale = 0 - pobj.yScale
						if (pobj.bubble ~= nil) then pobj.bubble.yScale = 0 - pobj.bubble.yScale end
						if (pobj.hardhat ~= nil) then pobj.hardhat.yScale = 0 - pobj.hardhat.yScale end
						if (pobj.bombshield ~= nil) then pobj.bombshield.yScale = 0 - pobj.bombshield.yScale end
						if (pobj.laser ~= nil) then pobj.laser.yScale = 0 - pobj.laser.yScale end
					end
				end
			end,1);
			gravityTimer = timer.performWithDelay(6000, function()
				runtime.playSound("powerup10")
				local flipArrow = display.newImageRect(gameGroup,"images/gravityfliparrow.png", 290, 260)
				flipArrow.x = _W * 0.5
				flipArrow.y = _H * 0.5
				transition.to(flipArrow, {time=800,rotation=90,onComplete=function()
					display.remove(flipArrow)
					flipArrow = nil 
				end})
				gravityTimer2 = timer.performWithDelay(1000, function()
					physics.setGravity( 0, 30)
					reverseGravity = false
					for pnum,pobj in pairs(player) do
						if (pobj ~= nil and pobj.isDying == false) then		
							local vx, vy = pobj:getLinearVelocity()
							pobj:setLinearVelocity(vx,0)
							pobj.yScale = 0 - pobj.yScale
							if (pobj.bubble ~= nil) then pobj.bubble.yScale = 0 - pobj.bubble.yScale end
							if (pobj.hardhat ~= nil) then pobj.hardhat.yScale = 0 - pobj.hardhat.yScale end
							if (pobj.bombshield ~= nil) then pobj.bombshield.yScale = 0 - pobj.bombshield.yScale end
							if (pobj.laser ~= nil) then pobj.laser.yScale = 0 - pobj.laser.yScale end
						end
					end
				end, 1)
			end,1);
			
		elseif (whichPowerup == 11) then
			-- Doubler
			coinsPer = 2
			if (coin ~= nil) then
				local oldX = coin.x
				local oldY = coin.y
				physics.removeBody(coin)
				display.remove(coin)
				coin = nil
				coin = display.newImageRect(gameGroup,"images/coin2.png", 32, 32)
				coin.y = oldY; coin.origY = coin.y
				coin.x = oldX
				coin.alpha = 1
				coin.id = "coin"
				physics.addBody(coin, "static", {isSensor=true,filter= { categoryBits = 8, maskBits = 2}} )
			end
			if doublerTimer ~= nil then 
				timer.cancel(doublerTimer)
				doublerTimer = nil 
			end
			doublerTimer = timer.performWithDelay(10000, function()
				coinsPer = 1
				runtime.playSound("powerup11")
				if (coin ~= nil) then
					local oldX = coin.x
					local oldY = coin.y
					physics.removeBody(coin)
					display.remove(coin)
					coin = nil
					coin = display.newImageRect(gameGroup,"images/coin.png", 32, 32)
					coin.y = oldY; coin.origY = coin.y
					coin.x = oldX
					coin.alpha = 1
					coin.id = "coin"
					physics.addBody(coin, "static", {isSensor=true,filter= { categoryBits = 8, maskBits = 2}} )
				end
			end, 1)

        elseif (whichPowerup == 12) then
            if (#foam == 0) then
                foam[1] = display.newImageRect(gameGroup,"images/foam.png", 350, 35)
                foam[1].x, foam[1].y = _W/2, -35
                foam[1].id = "foam"
                physics.addBody(foam[1], "static", {isSensor=true,filter= { categoryBits = 1, maskBits = 2}} )
                transition.to(foam[1], {time=600,y = 12 })
                foam[2] = display.newImageRect(gameGroup,"images/foam.png", 350, 35)
                foam[2].x, foam[2].y = _W/2, _H + 35
                foam[2].id = "foam"
                physics.addBody(foam[2], "static", {isSensor=true,filter= { categoryBits = 1, maskBits = 2}} )
                transition.to(foam[2], {time=600,y=(_H - 12) })
            end
            
		end
		
		if (powerUpPill ~= nil) then
			updateScore()
			local tempText = display.newText({gameGroup,text="+1",x=powerUpPill.x,y=powerUpPill.y,font=native.systemFontBold,fontSize=22})
			tempText:setTextColor(0.33, 0.70, 0.9)
			transition.to(tempText, {time=800,y=tempText.y-32,alpha=0.1,onComplete=function()
				display.remove(tempText)
				tempText = nil 
			end})
			
			runtime.playSound("powerup" .. whichPowerup)
			display.remove(powerUpPill)
			powerUpPill = nil
		end
						
	end
end

function swapSpikes()
	if (spikeAcceleration > 0) then
		if (spikeSpeed < maxSpikeSpeed) then
			spikeSpeed = spikeSpeed + spikeAcceleration
		end
	else
		if (spikeSpeed > 0-maxSpikeSpeed) then
			spikeSpeed = spikeSpeed + spikeAcceleration
		end
	end
	movesSinceLastPowerup = movesSinceLastPowerup + 1
	local transSpeed = 350 
	local leftX = {}   -- The arrays we use to transition the spikes.
	local rightX = {}
	local amount = mRand(minSpikeCount, mFloor(maxSpikeCount)) -- Always have at least 2 spikes showing
	local amountSet = 0 

	-- If a coin doesn't already exist create one and place it
	if coin == nil then 
		if (coinsPer == 2) then
			coin = display.newImageRect(gameGroup,"images/coin2.png", 32, 32)
		else
			coin = display.newImageRect(gameGroup,"images/coin.png", 32, 32)
		end
		coin.y = mRand(100,_H-100); coin.origY = coin.y 
		coin.alpha = 0.01
		coin.id = "coin"
		physics.addBody(coin, "static", {isSensor=true,filter= { categoryBits = 8, maskBits = 2}} )
		local coinat = 0
		for pnum,pobj in pairs(player) do
			if (pobj ~= nil and pobj.isDying == false) then
				pobj:toFront()
				if (pobj.bombshield and pobj.toFront) then
					pobj.bombshield:toFront()
				end
				if (pobj.hardhat and pobj.toFront) then
					pobj.hardhat:toFront()
				end
				if (pobj.laser and pobj.toFront) then
					pobj.laser:toFront()
				end
				if (pobj.bubble and pobj.toFront) then
					pobj.bubble:toFront()
				end
				coinat = pnum
			end
		end
		
		if (coinat > 0) then
			if player[coinat].xScale == -1 then 
				coin.x = toXLeft + 80
			else
				coin.x = toXRight - 80
			end
			transition.to(coin, {time=200, alpha=1})
		end
	end
	
	-- See if a power up should appear
	movesSinceLastPowerup = movesSinceLastPowerup + 1
	local pChance = mRand(1,movesSinceLastPowerup)
	if (pChance > 4) then
		if powerUpPill == nil then
			local whichPowerup
			local pickAgain
			local pickCount = 0
			repeat
				pickAgain = false
				whichPowerup = mRand(1,#powerupArray)
				if (whichPowerup == lastPowerup) then
					pickAgain = true
				else
					if (isLaserPurchased) then
						if (powerupsSinceLastLaser > 3) then
							if (powerupArray[whichPowerup].pid ~= 6) then
								if (mRand(1,100) > (80 - powerupsSinceLastLaser*5)) then
									pickAgain = true
								end
							end
						end
					end
					if (powerupArray[whichPowerup].pid == 8 and canNuke == false) then
						pickAgain = true
					end
					if (powerupArray[whichPowerup].pid == 10 and reverseGravity == true) then
						pickAgain = true
					end
					if (powerupArray[whichPowerup].pid == 10 and currentScore < 10) then
						pickAgain = true
					end
					if (powerupArray[whichPowerup].pid == 12 and foamDisappearing) then
					   pickAgain = true
					end
				end
				pickCount = pickCount + 1
			until (pickAgain == false or pickCount > 100)
			if (isLaserPurchased) then
				if (powerupArray[whichPowerup].pid == 6) then
					powerupsSinceLastLaser = 0
				else
					powerupsSinceLastLaser = powerupsSinceLastLaser + 1
				end
			end
			lastPowerup = whichPowerup -- Make sure they don't see the same one twice in a row
			powerUpRotateSpeed = mRand(2,6)
			movesSinceLastPowerup = 0
			powerUpPill = display.newImageRect(gameGroup,powerupArray[whichPowerup].file, powerupArray[whichPowerup].wh[1], powerupArray[whichPowerup].wh[2])
			powerUpPill.y = 0
			powerUpPill.fallSpeed = powerUpFallSpeed
			if (powerupArray[whichPowerup].gravity == 1) then
				powerUpPill.y = _H
				powerUpPill.fallSpeed = 0 - powerUpFallSpeed
			end
			if (reverseGravity == true) then
				powerUpPill.fallSpeed = 0 - powerUpFallSpeed
				powerUpPill.y = _H - powerUpPill.y 
			end
			powerUpPill.x = mRand(50,_W-50)
			powerUpPill.id = "powerup"
			powerUpPill.whichPowerup = powerupArray[whichPowerup].pid
			physics.addBody(powerUpPill, "static", {isSensor=true,filter= { categoryBits = 16, maskBits = 2 }})
			powerUpPill:toBack()
			for pnum,pobj in pairs(player) do
				if (pobj ~= nil and pobj.isDying == false) then
					pobj:toFront()
					if (pobj and pobj.bombshield and pobj.toFront) then
						pobj.bombshield:toFront()
					end
					if (pobj and pobj.hardhat and pobj.toFront) then
						pobj.hardhat:toFront()
					end
					if (pobj and pobj.laser and pobj.toFront) then
						pobj.laser:toFront()
					end
					if (pobj and pobj.bubble and pobj.toFront) then
						pobj.bubble:toFront()
					end
				end
			end
		end
	end

	-- Randomise which spikes move into the screen with this array.
	local moveSpikes = {} 
	for i=1, #spikes_left do 
		moveSpikes[i] = false 
	end 

	local function chooseSpike()
		local randSpike = mRand(1, #spikes_left)
		if moveSpikes[randSpike] == false then 
			moveSpikes[randSpike] = true 
			amountSet = amountSet + 1
		end
	end
	
	local loopcount = 0
	while (amountSet < amount and loopcount < 200) do
		loopcount = loopcount + 1
		chooseSpike()
	end
	
	-- Set the arrays containing the X positions
	-- The other side is put back to its normal position
	local playerat = 0
	for pnum,pobj in pairs(player) do
		if (pobj ~= nil and pobj.isDying == false) then
			playerat = pnum
		end
	end
	
	if (playerat > 0) then
		if player[playerat].xScale < 0 then
			leftSideHasSpikes = 1
			for i=1, #spikes_left do 
				if moveSpikes[i] == false then 
					leftX[i] = toXLeft
					spikes_left[i].onscreen = false
				else
					leftX[i] = mFloor(spikes_left[1].height/2)
					spikes_left[i].onscreen = true
				end
			end
	
			for i=1, #spikes_right do 
				rightX[i] = toXRight 
			end 
		else
			leftSideHasSpikes = 0
			for i=1, #spikes_right do 
				if moveSpikes[i] == false then 
					rightX[i] = toXRight
					spikes_right[i].onscreen = false
				else
					rightX[i] = _W - mFloor(spikes_right[1].height/2)
					spikes_right[i].onscreen = true
				end
			end
		
			for i=1, #spikes_left do 
				leftX[i] = toXLeft
			end 
		end
	
		-- Now run the transitions
		for i=1, #spikes_right do 
			local trans = transition.to(spikes_right[i], {time=100,x=rightX[i]})
		end
	
		for i=1, #spikes_left do 
			local trans = transition.to(spikes_left[i], {time=100,x=leftX[i]})
		end	
	end
	
	maxSpikeCount = maxSpikeCount + newSpikesPerBounce
	if (maxSpikeCount > #spikes_left - 2) then
		maxSpikeCount = #spikes_left - 2 -- always leave 2 spikes open per side
	end
end

local function fadeOutFoam(pobj)
    if foamDisappearing then return; end
    foamDisappearing = true
    if (foam[2] ~= nil) then
        transition.to(foam[2], {time=500,y=foam[2].y+15,alpha=0.05,onComplete=function()
            physics.removeBody(foam[2])
            foam[2]:removeSelf()
            foam[2] = nil
        end})
    end
    if (foam[1] ~= nil) then
        transition.to(foam[1], {time=500,y=foam[1].y-15,alpha=0.05,onComplete=function()
            physics.removeBody(foam[1])
            foam[1]:removeSelf()
            foam[1] = nil
            foamDisappearing = false
        end})
    end
end

function removeOneSpike()
	local foundSpike = false
	local randSpike
	local loopcount = 0
	local lightning
	local transSpeed = 350
	
	-- Search for a currently showing spike to remove
	while (foundSpike == false and loopcount < 200) do
		loopcount = loopcount + 1
		randSpike = mRand(1, #spikes_left)
		if (leftSideHasSpikes == 1) then
			if spikes_left[randSpike].x > toXLeft then 
				foundSpike = true
				lightning =  display.newImageRect(gameGroup, "images/lightning.png", 27, 17)
				lightning.y = spikes_left[randSpike].y
				lightning.x = spikes_left[randSpike].x + 20
				lightning.xScale = -1
				transition.to(lightning, {time=120, delay=20, alpha=0.1, transition=easing.outBounce, iterations=7, onComplete=function()
					if lightning ~= nil then 
						display.remove(lightning)
						lightning = nil
					end
				end})
				local trans2 = transition.to(spikes_left[randSpike], {time=transSpeed,x=toXLeft})
			end
		else
			if spikes_right[randSpike].x < toXRight then 
				foundSpike = true
				lightning =  display.newImageRect(gameGroup, "images/lightning.png", 27, 17)
				lightning.y = spikes_right[randSpike].y
				lightning.x = spikes_right[randSpike].x - 20
				transition.to(lightning, {time=120, delay=20, alpha=0.1, transition=easing.outBounce, iterations=7, onComplete=function()
					if lightning ~= nil then 
						display.remove(lightning)
						lightning = nil
					end
				end})
				local trans = transition.to(spikes_right[randSpike], {time=transSpeed,x=toXRight})
			end
		end
	end

	-- After removing one spike, we will lower the max number of spikes generated
	maxSpikeCount = maxSpikeCount - 0.6
	if (maxSpikeCount < 2) then
		maxSpikeCount = 2
	end
end

function explodeSpike(target)
	target.onscreen = false

	local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)
	explosionAnimation.x = target.x
	explosionAnimation.y = target.y
	explosionAnimation:setSequence("explosion")
	explosionAnimation:play()
	explosionAnimation:addEventListener("sprite", gameSpriteListener)
	gameGroup:insert(explosionAnimation)
	runtime.playSound("explode")
	target.x = target.originalx
	
	-- After removing one spike, we will lower the max number of spikes generated
	maxSpikeCount = maxSpikeCount - 0.6
	if (maxSpikeCount < 2) then
		maxSpikeCount = 2
	end
	updateScore(5)
	local textx = explosionAnimation.x - 20
	if (explosionAnimation.x < _W*0.5) then textx = explosionAnimation.x + 20 end
	local tempText = display.newText({gameGroup,text="+5",x=textx,y=explosionAnimation.y,font=native.systemFontBold,fontSize=22})
	tempText:setTextColor(0.33, 0.70, 0.9)
	transition.to(tempText, {time=800,y=tempText.y-32,alpha=0.1,onComplete=function()
		display.remove(tempText)
		tempText = nil 
	end})
end

function impulsePlayer()
		for pnum,pobj in pairs(player) do
			if (pobj ~= nil and pobj.isDying == false) then
				pobj:setLinearVelocity(0,0)
				local vertImpulseAmount = runtime.settings["playerswimpowerV"]
				if (pobj.isSmall) then
					vertImpulseAmount = vertImpulseAmount * 0.25
				end
				if (reverseGravity == true) then
					vertImpulseAmount = 0 - vertImpulseAmount
				end
				local horizImpulseAmount = runtime.settings["playerswimpowerH"]
				if (pobj.xScale < 0) then
					horizImpulseAmount = 0 - horizImpulseAmount
				end
				if (pobj.isSmall) then
					horizImpulseAmount = horizImpulseAmount * 0.25
				end
				pobj:applyLinearImpulse( horizImpulseAmount, vertImpulseAmount, pobj.x, pobj.y )
				pobj:play()
			end
		end

		if trailTimer ~= nil then 
			timer.cancel(trailTimer)
			trailTimer = nil 
		end

		trailTimer = timer.performWithDelay(120, function()
			for pnum,pobj in pairs(player) do
				if (pobj ~= nil and pobj.isDying == false) then
				    local trail
				    if (pobj.isSmall) then
					   trail = display.newImageRect(gameGroup, "images/trails/" .. runtime.settings["playersprite"] .. ".png", 8, 8)
					else
					   trail = display.newImageRect(gameGroup, "images/trails/" .. runtime.settings["playersprite"] .. ".png", 16, 16)
					end
					trail.x = pobj.x
					trail.y = pobj.y 
					trail:toBack()
		
					if pobj.xScale > 0 then 
						trail.x = trail.x - 10
					else
						trail.x = trail.x + 10
					end
		
					transition.to(trail, {time=250, delay=60, alpha=0, xScale=0.2, yScale=0.2, onComplete=function()
						if trail ~= nil then 
							display.remove(trail)
							trail = nil
						end
					end})
				end
			end
		end, 4)
end

function backgroundTouched(event)
	local t = event.target
	if event.phase == "began" and touchAllowed == true then 
		display.getCurrentStage():setFocus( t )
		t.isFocus = true
		
		impulsePlayer()

	elseif t.isFocus then 
		if event.phase == "ended" then 
			for pnum,pobj in pairs(player) do
				if (pobj ~= nil and pobj.isDying == false) then
					if (pobj.laser ~= nil) then
						timer.performWithDelay(30, function() fireLaser(pobj) end,1 );
					end
				end
			end
			display.getCurrentStage():setFocus( nil )
			t.isFocus = false
		end
	end
	return true
end

function gameTick(event)
    for pnum, pobj in pairs(deadfish) do
		pobj.x = pobj.origx + mSin(10 * pobj.y / _H) * 16
	end
	if isGameOver == false then 				
		-- Move the powerups with the players
		for pnum,pobj in pairs(player) do
			if (pobj ~= nil and pobj.isDying == false) then
				if (pobj.noCollision > 0) then
					pobj.noCollision = pobj.noCollision - 1
				end
				if (pobj.bubble ~= nil) then
					pobj.bubble.x = pobj.x
					pobj.bubble.y = pobj.y
				end
				if (pobj.bombshield ~= nil) then
					pobj.bombshield.x = pobj.x
					pobj.bombshield.y = pobj.y
				end
				if (pobj.hardhat ~= nil) then
					pobj.hardhat.x = pobj.x
					pobj.hardhat.y = pobj.y
				end
				if (pobj.laser ~= nil) then
					pobj.laser.x = pobj.x
					pobj.laser.y = pobj.y
				end
			end
		end

		for i=1, #spikes_right do 
			spikes_right[i].y = spikes_right[i].y + spikeSpeed
			if spikes_right[i].y > (_H - 20) then
				spikes_right[i].y = 20
			end
			if spikes_right[i].y < 20 then
				spikes_right[i].y = _H - 20
			end
		end
	
		for i=1, #spikes_left do 
			spikes_left[i].y = spikes_left[i].y + spikeSpeed
			if spikes_left[i].y > (_H - 20) then
				spikes_left[i].y = 20
			end
			if spikes_left[i].y < 20 then
				spikes_left[i].y = _H - 20
			end
		end
	
		-- If a coin exists move it up and down using a sine wave
		if coin ~= nil then 
			coin.y = coin.origY + mSin(event.time / 200) * 8
		end
		
		if powerUpPill ~= nil then
			powerUpPill.y = powerUpPill.y + powerUpPill.fallSpeed
			powerUpPill:rotate(powerUpRotateSpeed)
			if (powerUpPill.fallSpeed > 0) then
				if (powerUpPill.y > _H + 30) then
					display.remove(powerUpPill)
					powerUpPill = nil 
				end
			else
				if (powerUpPill.y < -30) then
					display.remove(powerUpPill)
					powerUpPill = nil 
				end
			end
		end
	end
end

function createPlayerSprite(target,params)
	local pnum = 0
	local vX = 0
	local vY = 0 
	local newX = _W * 0.5
	local newY = _H * 0.5
	local newxScale = 1
	local newyScale = 1
	local hasTarget = false
	if (target ~= nil) then
		vX, vY = target:getLinearVelocity()
		newX = target.x
		newY = target.y
		hasTarget = true
		if (target.xScale > 0) then
			newxScale = -1
		end
		if (target.yScale < 0) then
			newyScale = -1
		end
	end
	for i = 1,#player do   --count used on purpose to find hole in table
		if (player[i] == nil) then
			pnum = i
		end
	end
	if (pnum == 0) then pnum = #player + 1 end
	local currentPlayerSprite = runtime.settings["playersprite"]
	player[pnum] = display.newSprite(gameGroup, runtime.playerSpriteSheets[currentPlayerSprite], runtime.playerSequenceData)
	player[pnum]:setSequence("player")
	player[pnum].id = "player"
	player[pnum].pnum = pnum
	player[pnum].isDying = false
	player[pnum].noCollision = 0
	player[pnum].laser = nil
	player[pnum].laserCount = 0
	if (params ~= nil) then
		if (params.isSmall == true) then
			physics.addBody(player[pnum], "dynamic",{shape=playerShapeSmall, bounce=0.8,filter= {categoryBits = 2, maskBits = 29}} )
		else
			physics.addBody(player[pnum], "dynamic",{shape=playerShapeNormal, bounce=0.8,filter= {categoryBits = 2, maskBits = 29}})
		end
	else
		physics.addBody(player[pnum], "dynamic",{shape=playerShapeNormal, bounce=0.8,filter= {categoryBits = 2, maskBits = 29}})
	end
	player[pnum].isFixedRotation = true
	if (hasTarget) then
		player[pnum]:setLinearVelocity(-vX,vY)
		player[pnum].x = newX - 5 + mRand(0,10)
		player[pnum].y = newY - 5 + mRand(0,10)
		player[pnum].xScale = newxScale
		player[pnum].yScale = newyScale
	else
		player[pnum].x = _W*0.5
		player[pnum].y = _H*0.5
	end
	if (params ~= nil) then
		player[pnum].isSmall = params.isSmall
		player[pnum].xScale = params.xScale
		player[pnum].yScale = params.yScale
		if (params.xScale == 1 or params.xScale == -1) then
			if (params.x < 27) then
				params.x = 27
			end
			if (params.x > (_W - 27)) then
				params.x = _W - 27
			end
		end
		player[pnum].x = params.x
		player[pnum].y = params.y
		player[pnum]:setLinearVelocity(params.vx, params.vy)
		if (params.bombshield ~= nil) then
			player[pnum].bombshield = params.bombshield
			player[pnum].bombshieldCount = params.bombshieldCount
			player[pnum].bombshield.xScale = params.xScale
			player[pnum].bombshield.yScale = params.yScale
			player[pnum].bombshield:toFront()
		end
		if (params.hardhat ~= nil) then
			player[pnum].hardhat = params.hardhat
			player[pnum].hardhatCount = params.hardhatCount
			player[pnum].hardhat.xScale = params.xScale
			player[pnum].hardhat.yScale = params.yScale
			player[pnum].hardhat:toFront()
		end
		if (params.laser ~= nil) then
			player[pnum].laser = params.laser
			player[pnum].laserCount = params.laserCount
			player[pnum].laser.xScale = params.xScale
			player[pnum].laser.yScale = params.yScale
			player[pnum].laser:toFront()
		end
		if (params.bubble ~= nil) then
			player[pnum].bubble = params.bubble
			player[pnum].bubbleCount = params.bubbleCount
			player[pnum].bubble.xScale = params.xScale
			player[pnum].bubble.yScale = params.yScale
			player[pnum].bubble:toFront()
		end
	end
	-- Score increment will equal number of active player sprites
	scoreIncrement = 0
	for pnum,pobj in pairs(player) do
		if (pobj ~= nil and pobj.isDying == false) then
			scoreIncrement = scoreIncrement + 1
		end
	end
	return player[pnum]
end

function removePlayerStage1(p, cleanPowerups, animateToTop)
	local px, py, xs, ys = player[p].x, player[p].y, player[p].xScale, player[p].yScale
	player[p].isBodyActive = false
	player[p].isFixedRotation = false
	player[p].isDying = true
	physics.removeBody(player[p])
	if (player[p].selftimer ~= nil) then
		timer.cancel(player[p].selftimer)
	end
	if (player[p].selftimer2 ~= nil) then
		timer.cancel(player[p].selftimer2)
	end
	if (player[p].laser ~= nil and cleanPowerups == true) then
		display.remove(player[p].laser)
		player[p].laser = nil
	end
	if (player[p].bubble ~= nil and cleanPowerups == true) then
		display.remove(player[p].bubble)
		player[p].bubble = nil
	end
	if (player[p].bombshield ~= nil and cleanPowerups == true) then
		display.remove(player[p].bombshield)
		player[p].bombshield = nil
	end
	if (player[p].hardhat ~= nil and cleanPowerups == true) then
		display.remove(player[p].hardhat)
		player[p].hardhat = nil
	end
	display.remove(player[p])
	player[p] = nil
	-- Score increment will equal number of active player sprites
	scoreIncrement = 0
	local numPlayers = 0
	for pnum,pobj in pairs(player) do
		if (pobj ~= nil and pobj.isDying == false) then
			scoreIncrement = scoreIncrement + 1
			numPlayers = numPlayers + 1
		end
	end
	if (numPlayers == 0 and isGameOver == false) then
		gameOver(true)
	end
	if (animateToTop) then
		timer.performWithDelay(30, function() animateDeadFishToTop(px,py,xs,ys) end,1 );
	end
end

function animateDeadFishToTop(px,py,xs,ys)
	local fnum = 0
	for i = 1,#deadfish do   --count used on purpose to find hole in table
		if (deadfish[i] == nil) then
			fnum = i
		end
	end
	if (fnum == 0) then fnum = #deadfish + 1 end
	local currentPlayerSprite = runtime.settings["playersprite"]
	deadfish[fnum] = display.newSprite(gameGroup, runtime.playerSpriteSheets[currentPlayerSprite], runtime.playerSequenceData)
	deadfish[fnum]:setSequence("player")
	deadfish[fnum].id = "deadfish"
	deadfish[fnum].pnum = pnum
	deadfish[fnum].isDying = true
	deadfish[fnum].noCollision = 1
	deadfish[fnum].x = px
	deadfish[fnum].origx = px
	deadfish[fnum].y = py
	deadfish[fnum].xScale = xs
	deadfish[fnum].yScale = ys
	
	deadfish[fnum].trans = transition.to(deadfish[fnum], {time=200, yScale=0-ys, onComplete=function() 
            deadfish[fnum].trans = transition.to(deadfish[fnum], {time=2500,y=-20,yScale=0.5*deadfish[fnum].yScale,xScale=0.5*deadfish[fnum].xScale,onComplete=function()
				deadfish[fnum].trans = nil
				display.remove(deadfish[fnum])
				deadfish[fnum] = nil
        end})	
	end})
end

function useBubble(playerObj,spikeObj)
	runtime.playSound("usebubble")
	local pX, pY = playerObj:getLinearVelocity()
	if (spikeObj.spiketype == "horizontal") then
		playerObj.xScale = 0 - playerObj.xScale
		if (playerObj.bubble ~= nil) then
			playerObj.bubble.xScale = playerObj.xScale
		end
		if (playerObj.bombshield ~= nil) then
			playerObj.bombshield.xScale = playerObj.xScale
		end
		if (playerObj.hardhat ~= nil) then
			playerObj.hardhat.xScale = playerObj.xScale
		end
		if (playerObj.laser ~= nil) then
			playerObj.laser.xScale = playerObj.xScale
		end
	end
	playerObj.bubbleCount = playerObj.bubbleCount - 1
	if (playerObj.bubbleCount < 1) then
		if (playerObj.bubble ~= nil) then
			transition.to(playerObj.bubble, {time=200, alpha=0, onComplete=function() 
				display.remove(playerObj.bubble)
				playerObj.bubble = nil
				end})
		end
	end
end

function useHardhat(playerObj,spikeObj)
	runtime.playSound("usehardhat")
	local pX, pY = playerObj:getLinearVelocity()
	if (spikeObj.spiketype == "horizontal") then
		playerObj.xScale = -playerObj.xScale
		if (playerObj.bombshield ~= nil) then
			playerObj.bombshield.xScale = playerObj.xScale
		end
		if (playerObj.hardhat ~= nil) then
			playerObj.hardhat.xScale = playerObj.xScale
		end
		if (playerObj.bubble ~= nil) then
			playerObj.bubble.xScale = playerObj.xScale
		end
		if (playerObj.laser ~= nil) then
			playerObj.laser.xScale = playerObj.xScale
		end
	end
	playerObj.hardhatCount = playerObj.hardhatCount - 1
	if (playerObj.hardhatCount < 1) then
		if (playerObj.hardhat ~= nil) then
			transition.to(playerObj.hardhat, {time=200, alpha=0, onComplete=function() 
				display.remove(playerObj.hardhat)
				playerObj.hardhat = nil
				end})
		end
	end
end

function useBombshield(playerObj,spikeObj)
	if (playerObj ~= nil) then
		runtime.playSound("usebombshield")
		local pX, pY = playerObj:getLinearVelocity()
		if (spikeObj.spiketype == "horizontal") then
			playerObj.xScale = -playerObj.xScale
			if (playerObj.bombshield ~= nil) then
				playerObj.bombshield.xScale = playerObj.xScale
			end
			if (playerObj.hardhat ~= nil) then
				playerObj.hardhat.xScale = playerObj.xScale
			end
			if (playerObj.bubble ~= nil) then
				playerObj.bubble.xScale = playerObj.xScale
			end
			if (playerObj.laser ~= nil) then
				playerObj.laser.xScale = playerObj.xScale
			end
		end
		playerObj.bombshieldCount = playerObj.bombshieldCount - 1
		if (playerObj.bombshieldCount < 1) then
			if (playerObj.bombshield ~= nil) then
				transition.to(playerObj.bombshield, {time=200, alpha=0, onComplete=function() 
					display.remove(playerObj.bombshield)
					playerObj.bombshield = nil
					end})
			end
		end
		if (spikeObj ~= nil) then
			if (spikeObj.spiketype == "horizontal") then
				timer.performWithDelay(30, function() explodeSpike(spikeObj) end,1 );
			end
		end
	end
end

function fireLaser(playerObj)
    if (playerObj == nil) then return; end
	local lnum = 0
	for i = 1,#lasers do   --count used on purpose to find hole in table
		if (lasers[i] == nil) then
			lnum = i
		end
	end
	if (lnum == 0) then lnum = #lasers + 1 end
	lasers[lnum] = display.newImageRect(gameGroup, "images/laser_shot.png", 320, 10)
	physics.addBody( lasers[lnum], "dynamic", { isSensor=true,filter= {categoryBits = 32, maskBits = 4} } )
	lasers[lnum].gravityScale = 0
	lasers[lnum].id = "laser"
	lasers[lnum].x = playerObj.x + 10 * playerObj.xScale
	if (playerObj.isSmall) then
		lasers[lnum].y = playerObj.y - 30
	else
		lasers[lnum].y = playerObj.y - 15
	end
	local laserEndXScale = 1
	local laserEndX = playerObj.x + 480
	lasers[lnum].anchorX = 0
	lasers[lnum].xScale = 0.5
	if (playerObj.xScale < 0) then 
		laserEndX = playerObj.x - 480
		lasers[lnum].anchorX = 1
	end

	transition.to(lasers[lnum], {time=1000, xScale=laserEndXScale, x=laserEndX, onComplete=function() 
		display.remove(lasers[lnum])
		lasers[lnum] = nil
		end})
	playerObj.laserCount = playerObj.laserCount - 1
	runtime.playSound("laser")
	if (playerObj.laserCount < 1) then
		if (playerObj.laser ~= nil) then
			-- remove the laser from the head
			transition.to(playerObj.laser, {time=200, alpha=0, onComplete=function() 
				display.remove(playerObj.laser)
				playerObj.laser = nil
				end})
		end
	end
end

function onCollision(event)
	if event.phase == "began" then
		if event.object1 and event.object2 and isGameOver == false then  -- Make sure its only called once.
		
			if (event.object1.id == "spike" and event.object2.id == "player") or (event.object1.id == "player" and event.object2.id == "spike") then	
				if (event.object1.id == "player") then
					if (event.object1.isDying == false and event.object1.noCollision == 0) then
						if (event.object1.bombshield ~= nil) then
							event.object1.noCollision = 8
							timer.performWithDelay(30, function() useBombshield(event.object1, event.object2) end,1 );
						elseif (event.object1.bubble ~= nil) then
							event.object1.noCollision = 8
							timer.performWithDelay(30, function() useBubble(event.object1, event.object2) end,1 );
						elseif (event.object1.hardhat ~= nil) then
							event.object1.noCollision = 8
							timer.performWithDelay(30, function() useHardhat(event.object1, event.object2) end,1 );
						else
							event.object1.isDying = true
							event.object1:setLinearVelocity(0,0)
							timer.performWithDelay(30, function() removePlayerStage1(event.object1.pnum, true, true) end,1 );
						end
					end
				else
					if (event.object2.isDying == false and event.object2.noCollision == 0) then
						if (event.object2.bombshield ~= nil) then
							event.object2.noCollision = 8
							timer.performWithDelay(30, function() useBombshield(event.object2, event.object1) end,1 );
						elseif (event.object2.bubble ~= nil) then
							event.object2.noCollision = 8
							timer.performWithDelay(30, function() useBubble(event.object2, event.object1) end,1 );
						elseif (event.object2.hardhat ~= nil) then
							event.object2.noCollision = 8
							timer.performWithDelay(30, function() useHardhat(event.object2, event.object1) end,1 )
						else
							event.object2.isDying = true
							event.object2:setLinearVelocity(0,0)
							timer.performWithDelay(30, function() removePlayerStage1(event.object2.pnum, true, true) end,1 );
						end
					end
				end
	
			elseif (event.object1.id == "coin" and event.object2.id == "player") or (event.object1.id == "player" and event.object2.id == "coin") then
				-- Collect the coin if we haven't died yet
				if (event.object1.id == "player") then
					if (event.object1.isDying == false) then
						if coin ~= nil then 
							runtime.playSound("collect")
							coinsCollected = coinsCollected + coinsPer
			
							local tempText = display.newText({gameGroup,text="+"..coinsPer,x=coin.x,y=coin.y,font=native.systemFontBold,fontSize=22})
							tempText:setTextColor(0.96, 0.78, 0)
							transition.to(tempText, {time=800,y=tempText.y-32,alpha=0.1,onComplete=function()
								display.remove(tempText)
								tempText = nil 
							end})
			
							display.remove(coin)
							coin = nil
						end
					end
				else
					if (event.object2.isDying == false) then
						if coin ~= nil then 
							runtime.playSound("collect")
							coinsCollected = coinsCollected + coinsPer
			
							local tempText = display.newText({gameGroup,text="+"..coinsPer,x=coin.x,y=coin.y,font=native.systemFontBold,fontSize=22})
							tempText:setTextColor(0.96, 0.78, 0)
							transition.to(tempText, {time=800,y=tempText.y-32,alpha=0.1,onComplete=function()
								display.remove(tempText)
								tempText = nil 
							end})
			
							display.remove(coin)
							coin = nil
						end						
					end
				end	
				
			elseif (event.object1.id == "powerup" and event.object2.id == "player") or (event.object1.id == "player" and event.object2.id == "powerup") then
				if powerUpPill ~= nil then 
					if (event.object1.id == "player") then
						if (event.object1.isDying == false) then
							timer.performWithDelay(90, function() handlePowerUp(event.object1,0) end,1 );
						end
					else
						if (event.object2.isDying == false) then
							timer.performWithDelay(90, function() handlePowerUp(event.object2,0) end,1 );
						end
					end				
				end
				
			elseif (event.object1.id == "spike" and event.object1.onscreen==true and event.object2.id == "laser") or (event.object1.id == "laser" and event.object2.id == "spike" and event.object2.onscreen==true) then
					if (event.object1.id == "spike") then
						timer.performWithDelay(90, function() explodeSpike(event.object1) end,1 );
					else
						timer.performWithDelay(90, function() explodeSpike(event.object2) end,1 );
					end
					
			elseif (event.object1.id == "player" and event.object2.id == "foam") or (event.object1.id == "border" and event.object2.id == "foam") then
    			 if (event.object1.id == "player") then
    			     event.object1.noCollision = 10
    			     timer.performWithDelay(800, function() fadeOutFoam(event.object1) end,1 );  
    			 else
    			     event.object2.noCollision = 10
    			     timer.performWithDelay(800, function() fadeOutFoam(event.object2) end,1 );
    			 end
    			 runtime.playSound("usefoam")
    			 
			elseif (event.object1.id == "player" and event.object2.id == "border") or (event.object1.id == "border" and event.object2.id == "player") then
				if (event.object1.id == "player") then
					if (event.object1.isDying == false and event.object1.noCollision == 0) then
						event.object1.xScale = 0 - event.object1.xScale
						event.object1.noCollision = 4
						if (event.object1.bubble ~= nil) then
							event.object1.bubble.xScale = event.object1.xScale
						end
						if (event.object1.bombshield ~= nil) then
							event.object1.bombshield.xScale = event.object1.xScale
						end
						if (event.object1.hardhat ~= nil) then
							event.object1.hardhat.xScale = event.object1.xScale
						end
						if (event.object1.laser ~= nil) then
							event.object1.laser.xScale = event.object1.xScale
						end
					end
				else
					if (event.object2.isDying == false and event.object2.noCollision == 0) then
						event.object2.xScale = 0 - event.object2.xScale
						event.object2.noCollision = 4
						if (event.object2.bubble ~= nil) then
							event.object2.bubble.xScale = event.object2.xScale
						end
						if (event.object2.bombshield ~= nil) then
							event.object2.bombshield.xScale = event.object2.xScale
						end
						if (event.object2.hardhat ~= nil) then
							event.object2.hardhat.xScale = event.object2.xScale
						end
						if (event.object2.laser ~= nil) then
							event.object2.laser.xScale = event.object2.xScale
						end
					end
				end
				timer.performWithDelay(30, function() updateScore(); swapSpikes() end,1 );			
			end
		end
	end -- phase == began
end

-----------------------------------------------
-- *** COMPOSER SCENE EVENT FUNCTIONS ***
------------------------------------------------
-- Called when the scene's view does not exist:
-- Create all your display objects here.
function scene:create( event )
	screenGroup = self.view

	-- Create and layer our groups
	bgGroup = display.newGroup()
	gameGroup = display.newGroup()
	screenGroup:insert(bgGroup)
	screenGroup:insert(gameGroup)
	languageFont = utils.getCurrentFont()
	isLaserPurchased = utils.isProductPurchased(1)

	-- Background
	background = display.newRect(bgGroup,_W*0.5,_H*0.5,_W,_H)
	background:setFillColor(unpack(runtime.backgroundColour))

	-- UI objects
	text_rect = display.newCircle(bgGroup, 0, 0, 84)
	text_rect.x = _W*0.5
	text_rect.y = _H*0.5
    text_rect:setFillColor(1)
    text_rect.alpha = 0.6

	text_score = display.newText({parent=bgGroup,text=currentScore,font=languageFont,fontSize=100})
	text_score.x = text_rect.x
	text_score.y = text_rect.y + 4
	text_score:setFillColor(unpack(runtime.backgroundColour))

	-- Create the top and bottom row of spikes
	local xStartOff = 26 
	local spikeAmount = 7
	local xOffset = math.round( (_W - (xStartOff*2) ) / (spikeAmount-1) )
	local si = 0

	for i=1, spikeAmount do 
		si = si + 1
		local x = xStartOff + ((i-1)*xOffset)
		
		local spikeImageNum = mRand(1,runtime.numSpriteModels)
		spikes_topbottom[si] = display.newImageRect(gameGroup, 'images/spikes/' .. spikeImageNum .. '.png', 40, 20)
		spikes_topbottom[si].x = x
		spikes_topbottom[si].y = mFloor(spikes_topbottom[si].height/2)
		spikes_topbottom[si].id = "spike"
		spikes_topbottom[si].spiketype = "vertical"
		spikes_topbottom[si].uid = mRand(100000,999999)
		physics.addBody( spikes_topbottom[si], "static", {shape=spikeVertices,filter= {categoryBits = 4, maskBits = 34}})

		si = si + 1
		spikeImageNum = mRand(1,runtime.numSpriteModels)
		spikes_topbottom[si] = display.newImageRect(gameGroup, 'images/spikes/' .. spikeImageNum .. '.png', 40, 20)
		spikes_topbottom[si].x = x
		spikes_topbottom[si].y = _H - mFloor(spikes_topbottom[si].height/2)
		spikes_topbottom[si].rotation = 180
		spikes_topbottom[si].id = "spike"
		spikes_topbottom[si].spiketype = "vertical"
		spikes_topbottom[si].uid = mRand(100000,999999)
		physics.addBody( spikes_topbottom[si], "static", {shape=spikeVertices,filter= {categoryBits = 4, maskBits = 34}})
	end

	-- Now make the left / right hand spikes. They are all off screen initially.
	local yStartOff = 56
	local spikeAmountY = 10
	if _H < 536 then spikeAmountY = 9 end   
	local yOffset = math.round( (_H - (yStartOff*2)) / (spikeAmountY-1) )
	local spikeBodyElement = { shape=spikeVertices, bounce=0.3, filter= { categoryBits = 4, maskBits = 34 } }
	
	for i=1, spikeAmountY do 
		local y = yStartOff + ((i-1)*yOffset)
		
		local spikeImageNum = mRand(1,runtime.numSpriteModels)
		spikes_left[i] = display.newImageRect(gameGroup, 'images/spikes/' .. spikeImageNum .. '.png', 40, 20) 
		spikes_left[i].x = -mFloor(spikes_left[i].height/2) - 4  -- Add a slight offset to avoid accidental hits
		spikes_left[i].originalx = spikes_left[i].x
		spikes_left[i].y = y
		spikes_left[i].rotation = -90
		spikes_left[i].id = "spike"
		spikes_left[i].spiketype = "horizontal"
		
		spikes_left[i].uid = mRand(1000000,9999999)
		physics.addBody( spikes_left[i], "static", spikeBodyElement)

		spikeImageNum = mRand(1,runtime.numSpriteModels)
		spikes_right[i] = display.newImageRect(gameGroup, 'images/spikes/' .. spikeImageNum .. '.png', 40, 20)
		spikes_right[i].x = _W + mFloor(spikes_right[i].height/2) + 4
		spikes_right[i].originalx = spikes_right[i].x
		spikes_right[i].y = y
		spikes_right[i].rotation = 90
		spikes_right[i].id = "spike"
		spikes_right[i].spiketype = "horizontal"
		spikes_right[i].uid = mRand(1000000,9999999)
		physics.addBody( spikes_right[i], "static", spikeBodyElement)
	end

	-- Add all the borders that will watch for collisions					
	local borderBodyElement = { bounce=0.2, filter= { categoryBits = 1, maskBits = 2 } }
	borderArray[1] = display.newRect( _W/2, 0, _W, 1 ); borderArray[1]:setFillColor(0,0,0,0)
	borderArray[1].id = "border"
	physics.addBody( borderArray[1], "static", borderBodyElement )
	gameGroup:insert(borderArray[1])
	
	borderArray[2] = display.newRect( _W/2, _H, _W, 1 ); borderArray[2]:setFillColor(0,0,0,0)
	borderArray[2].id = "border"
	physics.addBody( borderArray[2], "static", borderBodyElement )
	gameGroup:insert(borderArray[2])
	
	borderArray[3] = display.newRect( 0, _H/2, 1, _H ); borderArray[3]:setFillColor(0,0,0,0)
	borderArray[3].id = "border"
	physics.addBody( borderArray[3], "static", borderBodyElement )
	gameGroup:insert(borderArray[3])
	
	borderArray[4] = display.newRect( _W-1, _H/2, 1, _H ); borderArray[4]:setFillColor(0,0,0,0)
	borderArray[4].id = "border"
	physics.addBody( borderArray[4], "static", borderBodyElement )
	gameGroup:insert(borderArray[4])
	
	-- Set up the player's sprite
	createPlayerSprite(nil)

	if event.params.y ~= nil then 
		player[1].y = event.params.y 
		player[1]:setFrame(2)
	end
	
	local currentPlayerSprite = runtime.settings["playersprite"]
	local vproduct = utils.loadvProducts(currentPlayerSprite)
	if (vproduct[1].powerup ~= nil) then
		handlePowerUp(player[1],vproduct[1].powerup)
	end
	
	maxSpikeCount = 2
	powerupArray = utils.getAvailablePowerups()
	
	-- explosion sprite
	explosionOptions = {
		width = 40, height = 40,
		numFrames = 10,
		sheetContentWidth = 40,
		sheetContentHeight = 400
	}
	explosionSheet = graphics.newImageSheet( "images/explosionSheet.png", explosionOptions)
	explosionSprite = { name="explosion", frames={ 1,2,3,4,5,6,7,8,9,10 }, time = 500, loopCount = 1 }
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

        -- Add our background touch
        background:addEventListener("touch",backgroundTouched)

        -- Add our runtime for moving the player + coin
        Runtime:addEventListener("enterFrame",gameTick)

        -- Add our runtime for collision checks
		Runtime:addEventListener("collision",onCollision)

		-- Get the player moving
		impulsePlayer()
		physics.start()
    end
end

function scene:hide( event )
    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Called when the scene is on screen (but is about to go off screen).
        -- Insert code here to "pause" the scene.
        -- Example: stop timers, stop animation, stop audio, etc.
        physics.stop()
        
        if (isGameOver == false) then
        	gameOver(false)
        end

        -- Remove any timers and transitions
        for pnum, pobj in pairs(player) do
	        if pobj.trans ~= nil then 
				transition.cancel(pobj.trans)
				pobj.trans = nil
			end
			if (pobj.selftimer ~= nil) then
				timer.cancel(pobj.selftimer)
			end
			if (pobj.selftimer2 ~= nil) then
				timer.cancel(pobj.selftimer2)
			end
		end
        for pnum, pobj in pairs(deadfish) do
	        if pobj.trans ~= nil then 
				transition.cancel(pobj.trans)
				pobj.trans = nil
			end
		end
		
		if trailTimer ~= nil then 
			transition.cancel(trailTimer)
			trailTimer = nil 
		end
		if gravityTimer ~= nil then 
			timer.cancel(gravityTimer)
			gravityTimer = nil 
		end
		if gravityTimer2 ~= nil then 
			timer.cancel(gravityTimer2)
			gravityTimer2 = nil 
		end
		if doublerTimer ~= nil then 
			timer.cancel(doublerTimer)
			doublerTimer = nil 
		end
					
        -- Remove runtimes
        background:removeEventListener("touch",backgroundTouched)
        Runtime:removeEventListener("enterFrame",gameTick)
		Runtime:removeEventListener("onCollision",onCollision)

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
