local M = {}

M.dbPath = system.pathForFile("gamedata.db3", system.DocumentsDirectory)

--------------------------------------------
-- Game balancing
--------------------------------------------
M.ticksBetweenLaserFire = 12 -- how fast should autofire be
M.scrollRate = 3 -- background scrolling
M.shipAcceleration = 0.3  -- keyboard and tap use this to determine how fast to ramp up horizontal travel
M.maxShipVelocity = 20  -- the fastest the ship can travel left or right
M.energyLossPerTick = 5  -- how fast the ship consumes energy just from flying
M.laserEnergyConsume = 0 -- does firing consume any ship energy
M.maxEnergy = 12000  -- the most energy the ship can hold
M.energyGainPerGem = 1300  -- how much energy is gained by picking up an energy crystal
M.ticksBetweenAsteroidSpawn = 34  -- how many game ticks between asteroids
M.ticksBetweenEnemySpawn = 250  -- the initial enemy spawn rate (it gets faster over time)
M.pointsPerEnemy = 250  -- how many points to score for killing an enemy ship
M.pointsPerAsteroid = 100  -- how many points to score for blowing up an asteroid
M.numBackgroundTracks = 3  -- how many background tracks are in the sounds/background/ folder

--------------------------------------------
-- Other globals
--------------------------------------------
M.finalScore = 0
M.selected = nil
M.keyDown = {}
M.keyDown["left"] = false
M.keyDown["right"] = false
M.keyDown["space"] = false
M.autoFire = false  -- autofire mode will be turned on with most control schemes
M.settings = {}
M.settings["debug"] = false
M.settings["games_this_session"] = 1
M.settings["background_track"] = math.random(1, M.numBackgroundTracks)
M.settings["background_autoskip"] = false
M.settings["tiltAngleLeft"] = -4.0
M.settings["tiltAngleRight"] = 4.0

M.logger = function(msg)
    if M.settings["debug"] then
        print(msg)
    end
end

M.logger("system.getinfo platform = " .. system.getInfo("platform") )
M.logger("system.getinfo model = " .. system.getInfo("model") )

local model = system.getInfo("model")
if system.getInfo("environment") == "simulator" then
    M.settings["platform"] = "simulator"
    M.settings["showotherapps"] = true
    M.settings["otherappsurl"] = "http://www.prairiewest.net/applications.php"

else
    if string.sub(model,1,2) == "iP" or system.getInfo("targetAppStore") == "apple" or system.getInfo("platform") == "ios" then
        -- iPhone, iPod or iPad
        M.settings["platform"] = "apple"
        M.settings["showotherapps"] = true
        M.settings["otherappsurl"] = "itms-apps://itunes.com/apps/prairiewestsoftwareconsulting"
        M.settings["iOSAppId"] = ""
        
    elseif model == "WFJWI" or string.sub(model,1,2) == "KF" or string.sub(model,1,6) == "Kindle" or system.getInfo("targetAppStore") == "amazon" then
        -- Amazon
        M.settings["platform"] = "amazon"
        M.settings["showotherapps"] = true
        M.settings["otherappsurl"] = "http://www.amazon.com/s/ref=bl_sr_mobile-apps?_encoding=UTF8&field-brandtextbin=Prairie%20West%20Software%20Consulting&node=2350149011"

    elseif system.getInfo("platform") == "android" or system.getInfo("targetAppStore") == "google" then
        -- Android
        M.settings["platform"] = "android"
        M.settings["showotherapps"] = true
        M.settings["otherappsurl"] = "https://play.google.com/store/apps/developer?id=Prairie+West+Software"

    else
        M.settings["platform"] = "unknown"
        M.settings["showotherapps"] = true
        M.settings["otherappsurl"] = "http://www.prairiewest.net/applications.php"
        
    end
end

M.sounds = {}
M.sounds["gameover"] = audio.loadSound("sounds/gameover.mp3")
M.sounds["laser"] = audio.loadSound("sounds/laser.mp3")
M.sounds["explode"] = audio.loadSound("sounds/explode.mp3")
M.sounds["select"] = audio.loadSound("sounds/select.mp3")
M.sounds["collect"] = audio.loadSound("sounds/collect.mp3")
M.sounds["outofenergy"] = audio.loadSound("sounds/outofenergy.mp3")
M.sounds["enemy1"] = audio.loadSound("sounds/enemy1.mp3")
M.sounds["enemy2"] = audio.loadSound("sounds/enemy2.mp3")
M.sounds["enemy3"] = audio.loadSound("sounds/enemy3.mp3")
M.sounds["enemy4"] = audio.loadSound("sounds/enemy4.mp3")
M.sounds["enemylaser"] = audio.loadSound("sounds/enemylaser.mp3")
M.backgroundSound = nil  -- the currently playing background audio

audio.reserveChannels(1)  --Reserve first channel for sound effects

M.stopAllSounds = function()
    local c
    for c=2, 32 do
        local isChannelActive = audio.isChannelActive( c )
        if isChannelActive then
            audio.stop( c )
        end
    end
end

M.setChannelVolumes = function()
    if (M.settings["fxvolume"] == nil) then return; end
    local c
    for c=2, 32 do
        audio.setVolume( M.settings["fxvolume"], { channel=c } )
    end
    audio.setVolume( M.settings["bgvolume"], { channel=1 } )
end
    
M.playSound = function(soundName)
    if M.sounds[soundName .. ""] ~= nil then 
        timer.performWithDelay(90, function() 
            audio.play( M.sounds[soundName] )
        end)
    else
        M.logger("No sound found for: " .. soundName)
    end
end

M.disposeSounds = function()
    for i = 1, 10 do
        if audio.isChannelActive( i ) then 
            audio.stop( i )
        end
    end
    for i, s in pairs(M.sounds) do
        audio.dispose( M.sounds[i] ); M.sounds[i] = nil;
    end
end

M.playBackgroundTrack = function()
    if M.settings["bgvolume"] ~= nil then
        M.logger("Starting background track")
        if M.backgroundSound == nil then
            -- Skip to next track
            local c = (M.settings["background_track"] % M.numBackgroundTracks) + 1
            M.settings["background_track"] = c
            M.backgroundSound = audio.loadStream("sounds/background/" .. c .. ".mp3")
            audio.setVolume( M.settings["bgvolume"], { channel=1 } )
            if audio.isChannelActive( 1 ) then 
                audio.stop( 1 )
            end
            audio.play( M.backgroundSound, { channel=1, loops=0, fadein=2000, onComplete=M.doneBackgroundTrack } )
            M.settings["background_autoskip"] = true
        end
    end
end

M.stopBackgroundTrack = function()
    if audio.isChannelActive( 1 ) then 
        audio.stop( 1 )
    end
end

M.doneBackgroundTrack = function(e)
    if (M.settings["background_autoskip"]) then
        if (e.completed) then
            M.backgroundSound = nil
            M.playBackgroundTrack()
        end
    end
end

M.nextBackgroundTrack = function()
    M.settings["background_autoskip"] = false
    if audio.isChannelActive( 1 ) then 
        audio.stop( 1 )
    end
    M.backgroundSound = nil
    M.playBackgroundTrack()
end
    
return M