local composer = require( "composer" )
local scene = composer.newScene()
local db = require("libraries.db")
local runtime = require("libraries.runtime")
local starfield = require("libraries.starfield")

runtime.settings["currentscene"] = "game"

local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 0 )
--physics.setDrawMode( "hybrid" )

-- Physics collision filters
local playerCFilter =     { categoryBits= 1, maskBits=54 }
local asteroidCFilter =   { categoryBits= 2, maskBits=75 }
local enemyCFilter =      { categoryBits= 4, maskBits=79 }
local laserCFilter =      { categoryBits= 8, maskBits= 6 }
local pickupCFilter =     { categoryBits=16, maskBits=65 }
local enemyLaserCFilter = { categoryBits=32, maskBits=65 }
local shieldCFilter =     { categoryBits=64, maskBits=54 }

local _W = display.contentWidth
local _H = display.contentHeight

-- Configure image sheet
local sheetOptions = {
    frames = {
        {   -- 1) asteroid 1
            x = 0,y = 0,
            width = 102,height = 85
        },
        {   -- 2) asteroid 2
            x = 0,y = 85,
            width = 90,height = 83
        },
        {   -- 3) asteroid 3
            x = 0,y = 168,
            width = 100,height = 97
        },
        {   -- 4) ship
            x = 0,y = 265,
            width = 98,height = 79
        },
        {   -- 5) laser
            x = 98,y = 265,
            width = 14,height = 40
        },
        {   -- 6) shield
            x = 0,y = 343,
            width = 133,height = 108
        },
    },
}
local objectSheet = graphics.newImageSheet( "images/gameObjects.png", sheetOptions )

-- enemy spritesheet
local enemyOptions = {
    width = 98, height = 85,
    numFrames = 4,
    sheetContentWidth = 98,
    sheetContentHeight = 340
}
local enemySheet = graphics.newImageSheet( "images/enemySheet.png", enemyOptions)

-- explosion spritesheet
local explosionOptions = {
    width = 64, height = 64,
    numFrames = 10,
    sheetContentWidth = 64,
    sheetContentHeight = 640
}
local explosionSheet = graphics.newImageSheet( "images/explosionSheet.png", explosionOptions)
local explosionSprite = { name="explosion", frames={ 1,2,3,4,5,6,7,8,9,10 }, time = 500, loopCount = 1 }

local lives = 3
local score = 0
local died = false
local laserEnergyConsume = runtime.laserEnergyConsume
local ticksUntilLaserActive = 0
local ticksUntilScroll = 0
local ticksUntilAsteroid = 0
local ticksUntilEnemy = runtime.ticksBetweenEnemySpawn
local enemiesSpawned = 0
local weaponType = 1
local shipVelocity = 0

local asteroidsTable = {}
local enemyTable = {}
local shipsRemaining = {}

local ship, asteroidLoopTimer, scoreText, energyBar, energyBarBack, shipEnergy, shield
local mainGroup, uiGroup, tapGroup, foregroundLeft, foregroundRight
local fallingItems = {}
local gemChance = 0
local weaponDropChance = 0
local dragMinY = _H * 0.7

local function handleTouchEvents(event)
    if (event.target.id == "tapLeft") then
        if event.phase == "began" then
            if (runtime.settings["controls"] == "tap") then
                runtime.keyDown["left"] = true
            end
            runtime.keyDown["space"] = true
        end
        if event.phase == "ended" then
            if (runtime.settings["controls"] == "tap") then
                runtime.keyDown["left"] = false
            end
            if (runtime.keyDown["right"] == false) then
                runtime.keyDown["space"] = false
            end
        end
        return true
    end
    if (event.target.id == "tapRight") then
        if event.phase == "began" then
            if (runtime.settings["controls"] == "tap") then
                runtime.keyDown["right"] = true
            end
            runtime.keyDown["space"] = true
        end
        if event.phase == "ended" then
            if (runtime.settings["controls"] == "tap") then
                runtime.keyDown["right"] = false
            end
            if (runtime.keyDown["left"] == false) then
                runtime.keyDown["space"] = false
            end
        end
        return true
    end
end

local function dragShip( event )

    local ship = event.target
    local phase = event.phase

    if ( "began" == phase ) then
        -- Set touch focus on the ship
        display.currentStage:setFocus( ship )
        -- Store initial offset position
        ship.touchOffsetX = event.x - ship.x
        ship.touchOffsetY = event.y - ship.y

    elseif ( "moved" == phase ) then
        -- Move the ship to the new touch position
        ship.x = event.x - ship.touchOffsetX
        if (event.y - ship.touchOffsetY > dragMinY) then
            ship.y = event.y - ship.touchOffsetY
        else
            ship.y = dragMinY
        end
        shield.x = ship.x
        shield.y = ship.y
        runtime.keyDown["space"] = true

    elseif ( "ended" == phase or "cancelled" == phase ) then
        -- Release touch focus on the ship
        display.currentStage:setFocus( nil )
        runtime.keyDown["space"] = false
    end

    return true  -- Prevents touch propagation to underlying objects
end

local function createAsteroid()
    local whichAsteroid = math.random(1,3)
	local newAsteroid = display.newImageRect( mainGroup, objectSheet, whichAsteroid, 102, 85 )
	local sizeScale = math.random(50,100)/100
	newAsteroid.xScale=sizeScale
	newAsteroid.yScale=sizeScale
	table.insert( asteroidsTable, newAsteroid )
	physics.addBody( newAsteroid, "dynamic", { radius=40*sizeScale, bounce=0.8, filter=asteroidCFilter } )
	newAsteroid.myName = "asteroid"

	local whereFrom = math.random( 3 )

	if ( whereFrom == 1 ) then
		-- From the left
		newAsteroid.x = -60
		newAsteroid.y = math.random( 500 )
		newAsteroid:setLinearVelocity( math.random( 40,120 ), math.random( 20,60 ) )
	elseif ( whereFrom == 2 ) then
		-- From the top
		newAsteroid.x = math.random( display.contentWidth )
		newAsteroid.y = -60
		newAsteroid:setLinearVelocity( math.random( -40,40 ), math.random( 40,120 ) )
	elseif ( whereFrom == 3 ) then
		-- From the right
		newAsteroid.x = display.contentWidth + 60
		newAsteroid.y = math.random( 500 )
		newAsteroid:setLinearVelocity( math.random( -120,-40 ), math.random( 20,60 ) )
	end

    local spinScale = 5 * sizeScale * sizeScale -- smaller asteroids need less torque to spin
	newAsteroid:applyTorque( math.random( -spinScale,spinScale ) )
end

local function updateShipsRemaining()
    for i = #shipsRemaining, 1, -1 do
        display.remove(shipsRemaining[i])
        table.remove(shipsRemaining, i)
    end
    for i = 1, (lives-1) do
        shipsRemaining[i] = display.newImageRect( mainGroup, objectSheet, 4, 98, 79 )
        shipsRemaining[i].rotation = 180
        shipsRemaining[i].xScale = 0.4
        shipsRemaining[i].yScale = 0.4
        shipsRemaining[i].x = 20 + i*40
        shipsRemaining[i].y = 30
    end
end

local function fireLaser()
	-- Play fire sound!
	runtime.playSound("laser")
	shipEnergy = shipEnergy - laserEnergyConsume

	local newLaser = display.newImageRect( mainGroup, objectSheet, 5, 14, 40 )
	physics.addBody( newLaser, "dynamic", { isSensor=true, filter=laserCFilter  } )
	newLaser.isBullet = true
	newLaser.myName = "laser"
	newLaser.x = ship.x
	newLaser.y = ship.y
	newLaser:toBack()
    transition.to( newLaser, { y=-40, time=500,
        onComplete = function() display.remove( newLaser ) end
    } )
    
    if (weaponType ==2) then
        local newLaser2 = display.newImageRect( mainGroup, objectSheet, 5, 14, 40 )
        physics.addBody( newLaser2, "dynamic", { isSensor=true, filter=laserCFilter  } )
        newLaser2.isBullet = true
        newLaser2.myName = "laser"
        newLaser2.x = ship.x-5
        newLaser2.y = ship.y
        newLaser2:toBack()
        transition.to( newLaser2, { y=-40, x=newLaser2.x-80, time=500,
            onComplete = function() display.remove( newLaser2 ) end
        } )
        
        local newLaser3 = display.newImageRect( mainGroup, objectSheet, 5, 14, 40 )
        physics.addBody( newLaser3, "dynamic", { isSensor=true, filter=laserCFilter  } )
        newLaser3.isBullet = true
        newLaser3.myName = "laser"
        newLaser3.x = ship.x + 5
        newLaser3.y = ship.y
        newLaser:toBack()
        transition.to( newLaser3, { y=-40, x=newLaser3.x+80,time=500,
            onComplete = function() display.remove( newLaser3 ) end
        } )
    end

end

local function enemyFire(enemy)
    if (enemy.x > 0 and enemy.x < _W and enemy.y > 0 and enemy.y < _H) then
        runtime.playSound("enemylaser")
    
        local newLaser = display.newImageRect(mainGroup,"images/enemyLaser.png", 16, 16)
        physics.addBody( newLaser, "static", { isSensor=true, filter=enemyLaserCFilter  } )
        newLaser.isBullet = true
        newLaser.myName = "enemylaser"
    
        newLaser.x = enemy.x
        newLaser.y = enemy.y + 16
        newLaser:toFront()
    
        transition.to( newLaser, { y=_H + 40, time=2000,
            onComplete = function() display.remove( newLaser ) end
        } )
    end
end

local function asteroidLoop()
	-- Create new asteroid
	createAsteroid()

	-- Remove asteroids which have drifted off screen
	for i = #asteroidsTable, 1, -1 do
		local thisAsteroid = asteroidsTable[i]
		if ( thisAsteroid.x < -100 or thisAsteroid.x > _W + 100 or
			 thisAsteroid.y < -100 or thisAsteroid.y > _H + 100 )
		then
			display.remove( thisAsteroid )
			table.remove( asteroidsTable, i )
		end
	end
end

local function moveEnemy(e)
    if e ~= nil and ship ~= nil and ship.x ~= nil then
        e.busy = true
        local secondsToMove = 2
        local maxVelocity = 70
        if e.behaviour == 1 then
            -- enemy moves toward last known ship position
            -- recalculate every 2 seconds so the enemy does not directly track player all the time
            -- speed limited to 70 pixels/sec so enemy cannot cover whole screen in short time
            e.targetY = e.y + 20 + math.random(0,40)
            e.targetX = ship.x
        end
        if e.behaviour == 2 then
            -- same as 1 except the enemy pays attention if the ship is moving and 
            -- tries to anticipate projected future location
            e.targetY = e.y + 30 + math.random(0,40)
            e.targetX = ship.x
            if runtime.keyDown["left"] then e.targetX  = e.targetX + 64; end
            if runtime.keyDown["right"] then e.targetX  = e.targetX - 64; end
        end
        if e.behaviour == 3 then
            -- Set the target Y once and give the enemy 5 seconds to move the whole screen down
            e.targetY = _H + 110
            e.targetX = ship.x
            secondsToMove = 5
            maxVelocity = 300
        end
        if e.behaviour == 4 then
            -- Moves across the whole screen, regardless of where the player is
            e.targetY = e.y + 30
            if e.targetX == 0 then e.targetX = _W - e.x; end
            if (e.x < _W * 0.3) then e.targetX = _W - 45; end
            if (e.x > _W * 0.7) then e.targetX = 45; end
            secondsToMove = 1
            maxVelocity = 90
        end
        e.nextMove = 60 * secondsToMove
        if (e.targetX ~= nil and e.targetY ~= nil) then
            local xVelocity = (e.targetX - e.x) / secondsToMove
            if xVelocity > maxVelocity then xVelocity = maxVelocity; end
            if xVelocity < 0-maxVelocity then xVelocity = 0-maxVelocity; end
            local yVelocity = (e.targetY - e.y) / secondsToMove
            if yVelocity > maxVelocity then yVelocity = maxVelocity; end
            if yVelocity < 0-maxVelocity then yVelocity = 0-maxVelocity; end
            e:setLinearVelocity(xVelocity, yVelocity)
        end
        e.busy = false
    end
end

local function createEnemy()
    enemiesSpawned = enemiesSpawned + 1
    local whichEnemy = math.random(1,3)
    local newEnemy = display.newImageRect( mainGroup, enemySheet, whichEnemy, 80, 80 )
    local sizeScale = math.random(70,100)/100
    newEnemy.busy = false
    newEnemy.xScale=sizeScale
    newEnemy.yScale=sizeScale
    newEnemy.targetX, newEnemy.targetY = _W* 0.5, _H + 200
    table.insert( enemyTable, newEnemy )
    physics.addBody( newEnemy, "dynamic", { radius=40*sizeScale, bounce=0.8, filter=enemyCFilter } )
    newEnemy.isFixedRotation = true
    newEnemy.myName = "enemy"
    newEnemy:toFront()
    newEnemy.ticksSinceFiring = 0
    newEnemy.ticksBetweenShots = math.random(45, 200) - enemiesSpawned -- Newer enemies fire faster
    if newEnemy.ticksBetweenShots < 45 then newEnemy.ticksBetweenShots = 45; end
    newEnemy.nextMove = 1
    runtime.playSound("enemy" .. whichEnemy)

    local whereFrom = math.random( 3 )
    if ( whereFrom == 1 ) then
        -- From the left
        newEnemy.x = -45
        newEnemy.y = math.random( 500 )
        newEnemy:setLinearVelocity( math.random( 40,120 ), math.random( 20,60 ) )
    elseif ( whereFrom == 2 ) then
        -- From the top
        newEnemy.x = math.random( display.contentWidth )
        newEnemy.y = -45
        newEnemy:setLinearVelocity( math.random( -40,40 ), math.random( 40,120 ) )
    elseif ( whereFrom == 3 ) then
        -- From the right
        newEnemy.x = display.contentWidth + 45
        newEnemy.y = math.random( 500 )
        newEnemy:setLinearVelocity( math.random( -120,-40 ), math.random( 20,60 ) )
    end
    newEnemy.behaviour = math.random(1,4)
end

local function enemyLoop()
    -- Create new enemy
    createEnemy()

    -- Remove enemies which have drifted off screen
    for i = #enemyTable, 1, -1 do
        local thisEnemy = enemyTable[i]
        if ( thisEnemy.x < -100 or thisEnemy.x > _W + 100 or
             thisEnemy.y < -100 or thisEnemy.y > _H + 100 )
        then
            if (thisEnemy.busy == false) then
                display.remove( thisEnemy )
                table.remove( enemyTable, i )
            end
        end
        thisEnemy.nextMove = thisEnemy.nextMove - 1
        if thisEnemy.nextMove < 1 then
            moveEnemy(thisEnemy)
        end
    end
end

local function restoreShip()
	ship.isBodyActive = false
	ship.x = display.contentCenterX
	ship.y = display.contentHeight - 100
	shipEnergy = runtime.maxEnergy
    ship.hasShield = true
	shield.alpha = 1
	shield.isBodyActive = true
	shield.x = ship.x
	shield.y = ship.y

	-- Fade in the ship
	transition.to( ship, { alpha=1, time=2000,
		onComplete = function()
			ship.isBodyActive = true
			died = false
            transition.to( shield, { alpha=0, time=9000,transition=easing.inExpo,
                onComplete = function()
                    ship.hasShield = false
                    shield.isBodyActive = false
                end
            } )
		end
	} )
end


local function endGame()
	runtime.finalScore = score
	composer.removeScene( "highscores" )
	composer.gotoScene( "scenes.highscores", { time=800, effect="crossFade" } )
end

local function gameSpriteListener( event )
  if ( event.phase == "ended" ) then
    local thisSprite = event.target
    mainGroup:remove(thisSprite)
  end 
end

local function playerDied(otherObj)
    if ( died == false ) then
        died = true

        local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)  
        explosionAnimation.x = ship.x
        explosionAnimation.y = ship.y
        explosionAnimation:setSequence("explosion")
        explosionAnimation:play()
        explosionAnimation:addEventListener("sprite", gameSpriteListener)
        mainGroup:insert(explosionAnimation)
            
        -- Play explosion sound!
        runtime.playSound("explode")

        -- Update lives
        lives = lives - 1
        updateShipsRemaining()

        if ( lives == 0 ) then
            display.remove( ship )
            timer.performWithDelay( 2000, endGame )
        else
            ship.alpha = 0
            timer.performWithDelay( 1000, restoreShip )
        end
        
        if (otherObj.myName == "enemylaser") then
            transition.cancel(otherObj) 
        end
        display.remove(otherObj)
    end
end

local function playerOutOfEnergy()
    if ( died == false ) then
        died = true
        if enemiesSpawned > 10 then enemiesSpawned = 10; end
        runtime.playSound("outofenergy")
        transition.to( ship, { rotation=630, xScale=0.2, yScale=0.2, time=1500,
            onComplete = function()
                ship.rotation = 0
                ship.xScale = 1
                ship.yScale=1
                ship.alpha = 0
                if ( lives == 0 ) then
                    display.remove( ship )
                    timer.performWithDelay( 2000, endGame )
                else
                    ship.alpha = 0
                    timer.performWithDelay( 1000, restoreShip )
                end
            end
        } )

        lives = lives - 1
        updateShipsRemaining()
    end
end

local function gameTick()
    if ticksUntilScroll < 1 then
        starfield.scroll(1)
        ticksUntilScroll = runtime.scrollRate
    else
        ticksUntilScroll = ticksUntilScroll - 1
    end
    if ticksUntilAsteroid < 1 then
        asteroidLoop()
        ticksUntilAsteroid = runtime.ticksBetweenAsteroidSpawn + math.random(1,20)
    else
        ticksUntilAsteroid = ticksUntilAsteroid - 1
    end
    if ticksUntilEnemy < 1 then
        enemyLoop()
        -- Enemies spawn faster over time
        ticksUntilEnemy = runtime.ticksBetweenEnemySpawn + math.random(1,150) - enemiesSpawned * 5
        if ticksUntilEnemy < 40 then ticksUntilEnemy = 40; end
    else
        ticksUntilEnemy = ticksUntilEnemy - 1
    end
    if ticksUntilLaserActive > 0 then
        ticksUntilLaserActive = ticksUntilLaserActive - 1
    end
    for i = #enemyTable, 1, -1 do
        enemyTable[i].ticksSinceFiring = enemyTable[i].ticksSinceFiring + 1
        if (enemyTable[i].ticksSinceFiring > enemyTable[i].ticksBetweenShots) then
            enemyFire(enemyTable[i])
            enemyTable[i].ticksSinceFiring = 0
        end
        enemyTable[i].nextMove = enemyTable[i].nextMove - 1
        if enemyTable[i].nextMove < 1 then
            moveEnemy(enemyTable[i])
        end
    end
    if runtime.keyDown["left"] then
        shipVelocity = shipVelocity - runtime.shipAcceleration
        if shipVelocity < 0-runtime.maxShipVelocity then
            shipVelocity = 0-runtime.maxShipVelocity
        end
    end
    if runtime.keyDown["right"] then
        shipVelocity = shipVelocity + runtime.shipAcceleration
        if shipVelocity < 0-runtime.maxShipVelocity then
            shipVelocity = 0-runtime.maxShipVelocity
        end
    end
    -- not moving left or right, so slow ship down
    if runtime.keyDown["left"]==false and runtime.keyDown["right"]==false then
        shipVelocity = shipVelocity * 0.8
        if (shipVelocity > -0.01 and shipVelocity < 0.01) then
            shipVelocity = 0.0
        end
    end
    if ship ~= nil and died == false then
        ship.x = ship.x + shipVelocity
        if (ship.x + 49 > _W) then
            ship.x = _W - 49
            shipVelocity = shipVelocity * 0.5
        end
        if (ship.x < 49) then 
            ship.x = 49
            shipVelocity = shipVelocity * 0.5
        end
        shield.x = ship.x
        if runtime.keyDown["space"] or runtime.autoFire then
            if ticksUntilLaserActive == 0 then
                fireLaser()
                ticksUntilLaserActive = runtime.ticksBetweenLaserFire
            end
        end
        if shipVelocity ~= 0.0 then
            -- Move the level 3 stars in the opposite direction the ship is going
            -- And only partially as fast
            starfield.move(0-shipVelocity, 0.0, 0.3)
        end
        shipEnergy = shipEnergy - runtime.energyLossPerTick
        if (shipEnergy < 1) then
            playerOutOfEnergy()
        end
        local energyScale = shipEnergy/runtime.maxEnergy
        if (energyScale > 0) then
            energyBar.xScale = energyScale
            local hb_r = 510 * (1.0 - energyScale); if hb_r > 255 then hb_r = 255 end
            local hb_g = 510 * energyScale; if hb_g > 255 then hb_g = 255 end
            energyBar:setFillColor(hb_r/255,hb_g/255,0)
        end
    end
    
    for i,item in pairs(fallingItems) do
        item.y = item.y + item.fallSpeed
        item:rotate(item.rotateSpeed)
        if (item.fallSpeed > 0) then
            if (item.y > _H + 30) then
                display.remove(item)
                item = nil
                table.remove(fallingItems,i)
            end
        else
            if (item.y < -30) then
                display.remove(item)
                item = nil
                table.remove(fallingItems,i)
            end
        end
    end
    
end

local function adjustScore(amount)
    score = score + amount
    scoreText.text = "Score: " .. score
end

local function createGem(gx, gy, gemType)
    local newGem = display.newImageRect(mainGroup,"images/gem" .. gemType .. ".png", 30, 30)
    newGem.x, newGem.y = gx, gy
    newGem.fallSpeed = math.random(2,3)
    newGem.rotateSpeed = math.random(-5,5)
    newGem.myName = "gem"
    newGem.gemType = gemType
    physics.addBody(newGem, "static", {isSensor=true, filter=pickupCFilter })
    table.insert(fallingItems, newGem)
end

local function collectGem(obj)
    adjustScore(50)
    if (obj.gemType == 1) then
        shipEnergy = shipEnergy + runtime.energyGainPerGem
    elseif (obj.gemType == 2) then
        weaponType = 2
        ship:setFillColor(1,0.6,0.6)
        timer.performWithDelay( 10000, function() weaponType = 1; ship:setFillColor(1,1,1); end, 1 )
    end
    runtime.playSound("collect")
    for i,item in pairs(fallingItems) do
        if (item == obj) then
            table.remove(fallingItems,i)
            display.remove(obj)
            obj = nil
        end
    end
end

local function onDeviceTilt(event)
    -- Gravity is in portrait orientation on Android, iOS, and Windows Phone
    -- On tvOS, gravity is in the orientation of the device attached to the event
    local yAngle = 0
    if ( event.device ) then
        yAngle = event.yGravity * 100
    else
        yAngle = event.xGravity * 100
    end
    
    if (yAngle < runtime.settings["tiltAngleLeft"]) then
        runtime.keyDown["left"] = true
        runtime.keyDown["right"] = false        
    elseif (yAngle > runtime.settings["tiltAngleRight"]) then
        runtime.keyDown["left"] = false
        runtime.keyDown["right"] = true        
    else
        runtime.keyDown["left"] = false
        runtime.keyDown["right"] = false
    end
end

local function onCollision( event )

	if ( event.phase == "began" ) then
		local obj1 = event.object1
		local obj2 = event.object2
		
		if (obj1.myName ~= "asteroid" or obj2.myName ~= "asteroid") then
		    runtime.logger("Collision: " .. obj1.myName .. " <=> " .. obj2.myName)
		end

		if ( ( obj1.myName == "laser" and obj2.myName == "asteroid" ) or
			 ( obj1.myName == "asteroid" and obj2.myName == "laser" ) )
		then
			for i = #asteroidsTable, 1, -1 do
				if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
                    local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)  
                    explosionAnimation.x = asteroidsTable[i].x
                    explosionAnimation.xScale = asteroidsTable[i].xScale
                    explosionAnimation.y = asteroidsTable[i].y
                    explosionAnimation.yScale = asteroidsTable[i].yScale
                    explosionAnimation:setSequence("explosion")
                    explosionAnimation:play()
                    explosionAnimation:addEventListener("sprite", gameSpriteListener)
                    mainGroup:insert(explosionAnimation)

                    gemChance = gemChance + 1
                    local pChance = math.random(1,gemChance)
                    if (pChance > 3) then
                        local ax = asteroidsTable[i].x -- Local var in case asteroid is gone by the time timer fires
                        local ay = asteroidsTable[i].y
                        timer.performWithDelay( 30, function() createGem(ax, ay, 1); end, 1 )
                        gemChance = 0
                    end
                    
					table.remove( asteroidsTable, i )
					break
				end
			end

            -- Remove both the laser and asteroid
            display.remove( obj1 )
            display.remove( obj2 )

            -- Play explosion sound!
            runtime.playSound("explode")
            adjustScore(runtime.pointsPerAsteroid)

        elseif ( ( obj1.myName == "laser" and obj2.myName == "enemy" ) or
             ( obj1.myName == "enemy" and obj2.myName == "laser" ) )
        then
            for i = #enemyTable, 1, -1 do
                if ( enemyTable[i] == obj1 or enemyTable[i] == obj2 ) and (enemyTable[i].busy == false) then
                    local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)  
                    explosionAnimation.x = enemyTable[i].x
                    explosionAnimation.xScale = enemyTable[i].xScale
                    explosionAnimation.y = enemyTable[i].y
                    explosionAnimation.yScale = enemyTable[i].yScale
                    explosionAnimation:setSequence("explosion")
                    explosionAnimation:play()
                    explosionAnimation:addEventListener("sprite", gameSpriteListener)
                    mainGroup:insert(explosionAnimation)

                    -- Enemies can drop weapon upgrades
                    if weaponType == 1 then
                        weaponDropChance = weaponDropChance + 1
                        local wChance = math.random(1,weaponDropChance)
                        if (wChance > 5) then
                            local ax = enemyTable[i].x -- Local var in case asteroid is gone by the time timer fires
                            local ay = enemyTable[i].y
                            timer.performWithDelay( 30, function() createGem(ax, ay, 2); end, 1 )
                            weaponDropChance = 0
                        end
                    end
                    
                    table.remove( enemyTable, i )
                    break
                end
            end

            -- Remove both the laser and enemy
            display.remove( obj1 )
            display.remove( obj2 )

            -- Play explosion sound!
            runtime.playSound("explode")
            adjustScore(runtime.pointsPerEnemy)

        elseif ( obj1.myName == "ship" and obj2.myName == "gem" )
        then
            collectGem(obj2)
            
        elseif ( obj1.myName == "gem" and obj2.myName == "ship" )
        then
            collectGem(obj1)
            
		elseif ( ( obj1.myName == "ship" and obj2.myName == "asteroid" ) or
				 ( obj1.myName == "asteroid" and obj2.myName == "ship" ) )
		then
		    if (ship.hasShield == false) then
                for i = #asteroidsTable, 1, -1 do
                    if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
                        local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)  
                        explosionAnimation.x = asteroidsTable[i].x
                        explosionAnimation.xScale = asteroidsTable[i].xScale
                        explosionAnimation.y = asteroidsTable[i].y
                        explosionAnimation.yScale = asteroidsTable[i].yScale
                        explosionAnimation:setSequence("explosion")
                        explosionAnimation:play()
                        explosionAnimation:addEventListener("sprite", gameSpriteListener)
                        mainGroup:insert(explosionAnimation)
                        table.remove( asteroidsTable, i )
                        break
                    end
                end
    		    if obj1.myName == "asteroid" then
                    playerDied(obj1)
                else
                    playerDied(obj2)
                end
            end

        elseif ( ( obj1.myName == "shield" and obj2.myName == "asteroid" ) or
                 ( obj1.myName == "asteroid" and obj2.myName == "shield" ) )
        then
            for i = #asteroidsTable, 1, -1 do
                if ( asteroidsTable[i] == obj1 or asteroidsTable[i] == obj2 ) then
                    local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)  
                    explosionAnimation.x = asteroidsTable[i].x
                    explosionAnimation.xScale = asteroidsTable[i].xScale
                    explosionAnimation.y = asteroidsTable[i].y
                    explosionAnimation.yScale = asteroidsTable[i].yScale
                    explosionAnimation:setSequence("explosion")
                    explosionAnimation:play()
                    explosionAnimation:addEventListener("sprite", gameSpriteListener)
                    mainGroup:insert(explosionAnimation)
                    table.remove( asteroidsTable, i )
                    break
                end
            end
            if obj1.myName == "asteroid" then
                transition.cancel(obj1) 
                display.remove(obj1)
            else
                transition.cancel(obj2) 
                display.remove(obj2)
            end
            adjustScore(runtime.pointsPerAsteroid)

        elseif ( ( obj1.myName == "ship" and obj2.myName == "enemy" ) or
                 ( obj1.myName == "enemy" and obj2.myName == "ship" ) )
        then
            if (ship.hasShield == false) then
                for i = #enemyTable, 1, -1 do
                    if ( enemyTable[i] == obj1 or enemyTable[i] == obj2 ) and (enemyTable[i].busy == false) then
                        local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)  
                        explosionAnimation.x = enemyTable[i].x
                        explosionAnimation.xScale = enemyTable[i].xScale
                        explosionAnimation.y = enemyTable[i].y
                        explosionAnimation.yScale = enemyTable[i].yScale
                        explosionAnimation:setSequence("explosion")
                        explosionAnimation:play()
                        explosionAnimation:addEventListener("sprite", gameSpriteListener)
                        mainGroup:insert(explosionAnimation)
                        table.remove( enemyTable, i )
                        break
                    end
                end
                if obj1.myName == "enemy" then
                    playerDied(obj1)
                else
                    playerDied(obj2)
                end
            end

        elseif ( ( obj1.myName == "shield" and obj2.myName == "enemy" ) or
                 ( obj1.myName == "enemy" and obj2.myName == "shield" ) )
        then
            for i = #enemyTable, 1, -1 do
                if ( enemyTable[i] == obj1 or enemyTable[i] == obj2 ) and (enemyTable[i].busy == false) then
                    local explosionAnimation = display.newSprite( explosionSheet, explosionSprite)  
                    explosionAnimation.x = enemyTable[i].x
                    explosionAnimation.xScale = enemyTable[i].xScale
                    explosionAnimation.y = enemyTable[i].y
                    explosionAnimation.yScale = enemyTable[i].yScale
                    explosionAnimation:setSequence("explosion")
                    explosionAnimation:play()
                    explosionAnimation:addEventListener("sprite", gameSpriteListener)
                    mainGroup:insert(explosionAnimation)
                    table.remove( enemyTable, i )
                    break
                end
            end
            if obj1.myName == "enemy" then
                transition.cancel(obj1) 
                display.remove(obj1)
            else
                transition.cancel(obj2) 
                display.remove(obj2)
            end
            adjustScore(runtime.pointsPerEnemy)

        elseif ( ( obj1.myName == "ship" and obj2.myName == "enemylaser" ) or
                 ( obj1.myName == "enemylaser" and obj2.myName == "ship" ) )
        then
            if (ship.hasShield == false) then
                if obj1.myName == "enemylaser" then
                    playerDied(obj1)
                else
                    playerDied(obj2)
                end
            else
                if obj1.myName == "enemylaser" then
                    transition.cancel(obj1) 
                    display.remove(obj1)
                else
                    transition.cancel(obj2) 
                    display.remove(obj2)
                end
            end

        elseif ( ( obj1.myName == "shield" and obj2.myName == "enemylaser" ) or
                 ( obj1.myName == "enemylaser" and obj2.myName == "shield" ) )
        then
            if (ship.hasShield == false) then
                if obj1.myName == "enemylaser" then
                    transition.cancel(obj1) 
                    display.remove(obj1)
                else
                    transition.cancel(obj2) 
                    display.remove(obj2)
                end
            end
            
		end
	end
end

function scene:create( event )

	local sceneGroup = self.view
	starfield.create(scene)
	physics.pause()  -- Temporarily pause the physics engine

	-- Set up display groups
	mainGroup = display.newGroup()  -- Display group for the ship, asteroids, lasers, etc.
	sceneGroup:insert(mainGroup)
	uiGroup = display.newGroup()    -- Display group for UI objects like the score
	sceneGroup:insert(uiGroup)
	tapGroup = display.newGroup()  -- The clear rectangle used to listen for taps to fire the laser
	sceneGroup:insert(tapGroup)

    -- the game starts with a shield protecting the ship
    shield = display.newImageRect( mainGroup, objectSheet, 6, 133, 108 )
    shield.x = display.contentCenterX
    shield.y = display.contentHeight - 100
    physics.addBody( shield, { radius=67, isSensor=true, filter=shieldCFilter  } )
    shield.isSleepingAllowed = false
    shield.myName = "shield"
    		
	ship = display.newImageRect( mainGroup, objectSheet, 4, 98, 79 )
	ship.x = display.contentCenterX
	ship.y = display.contentHeight - 100
	ship.touchOffsetX = 0
	ship.touchOffsetY = 0
	physics.addBody( ship, { radius=30, isSensor=true, filter=playerCFilter  } )
    ship.isSleepingAllowed = false
	ship.myName = "ship"

	-- Display lives and score
	scoreText = display.newText( uiGroup, "Score: " .. score, _W - 180, 30, native.systemFont, 36 )

    --Create an energy bar below the ship
    shipEnergy = runtime.maxEnergy
    energyBarBack = display.newRect(mainGroup,0,0,_W - 4,10)
    energyBarBack.x = _W*0.5; energyBarBack.y = _H - 10
    energyBarBack:setFillColor(0.3,0.3,0.3, 0.6)
    
    energyBar = display.newRect(mainGroup,0,0,_W - 8,6)
    energyBar.anchorX = 0
    energyBar.x = 2; energyBar.y = _H - 10
    energyBar:setFillColor(0,1,0, 0.6)
    
	updateShipsRemaining()
    transition.to( shield, { alpha=0, time=9000, transition=easing.inExpo,
        onComplete = function()
            ship.hasShield = false
            shield.isBodyActive = false
        end
    } )

    if (runtime.settings["controls"] == "tilt" or runtime.settings["controls"] == "tap") then
        foregroundLeft = display.newRect(tapGroup,_W*0.25,_H*0.5,_W*0.5,_H)
        foregroundLeft.id = "tapLeft"
        foregroundLeft:setFillColor(1,1,1,0.02)
        foregroundLeft:addEventListener( "touch", handleTouchEvents )
    
        foregroundRight = display.newRect(tapGroup,_W*0.75,_H*0.5,_W*0.5,_H)
        foregroundRight.id = "tapRight"
        foregroundRight:setFillColor(1,1,1,0.02)
        foregroundRight:addEventListener( "touch", handleTouchEvents )
    end
    
    if (runtime.settings["controls"] == "tap" or runtime.settings["controls"] == "drag") then
        runtime.autoFire = true
    end
    
    runtime.logger("Controls: " .. runtime.settings["controls"])
end


function scene:show( event )
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is still off screen (but is about to come on screen)
		Runtime:addEventListener("enterFrame",gameTick)
        if runtime.settings["platform"] == "android" then
            native.setProperty( "androidSystemUiVisibility", "immersiveSticky" )
        end
        runtime.keyDown["left"] = false
        runtime.keyDown["right"] = false
        runtime.keyDown["space"] = false

	elseif ( phase == "did" ) then
		-- Code here runs when the scene is entirely on screen
		physics.start()
		Runtime:addEventListener( "collision", onCollision )
        if system.hasEventSource("accelerometer") and runtime.settings["platform"] ~= "simulator" then
            if runtime.settings["controls"] == nil or runtime.settings["controls"] == "tilt" then
                system.setAccelerometerInterval( 100 )
                runtime.shipAcceleration = 0.2 -- Less acceleration than keyboard
                Runtime:addEventListener( "accelerometer", onDeviceTilt )
            end
        end
        if (runtime.settings["controls"] == "tap") and runtime.settings["platform"] ~= "simulator" then
            system.activate( "multitouch" )
        end
        if (runtime.settings["controls"] == "drag" or runtime.settings["controls"] == "mouse") then
            ship:addEventListener( "touch", dragShip )
        end
	end
end


function scene:hide( event )
	local phase = event.phase

	if ( phase == "will" ) then
		-- Code here runs when the scene is on screen (but is about to go off screen)
		Runtime:removeEventListener("enterFrame",gameTick)
		if runtime.settings["platform"] == "android" then
            native.setProperty( "androidSystemUiVisibility", "default" )
    		end

	elseif ( phase == "did" ) then
		-- Code here runs immediately after the scene goes entirely off screen
		Runtime:removeEventListener( "collision", onCollision )
		physics.pause()
        if system.hasEventSource("accelerometer") and runtime.settings["platform"] ~= "simulator" then
            if runtime.settings["controls"] == nil or runtime.settings["controls"] == "tilt" then
                Runtime:removeEventListener( "accelerometer", onDeviceTilt )
            end
        end
	end
end


function scene:destroy( event )
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
