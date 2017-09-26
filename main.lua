-- This project is based on a Corona Labs marketplace project
-- The original was found at: https://marketplace.coronalabs.com/asset/star-explorer

-- Copyright (c) 2017 Corona Labs Inc.
-- Code is MIT licensed and can be re-used; see https://www.coronalabs.com/links/code/license

-- See LICENSES.txt

local composer = require("composer")
composer.recycleOnSceneChange = true
local runtime = require("libraries.runtime") -- important to load this before db.lua ever gets loaded
runtime.settings["currentscene"] = "main"

display.setStatusBar( display.HiddenStatusBar ) --Hide status bar from the beginning
runtime.logger("Running on platform: " .. runtime.settings["platform"])

--handle the Android hardware buttons
local function onKeyEvent( event )
    if event.keyName == "back" then
        if (event.phase == "up") then
            if runtime.settings["currentscene"] == "menu" then
                runtime.stopBackgroundTrack()
                Runtime:removeEventListener( "key", onKeyEvent )
                native.requestExit();
            elseif runtime.settings["currentscene"] == "game" then
                timer.performWithDelay(90, function() composer.gotoScene( "scenes.menu", { effect = "crossFade", time = 400 } ); end,1 );
            elseif runtime.settings["currentscene"] == "gameConfig" then
                timer.performWithDelay(90, function() composer.gotoScene( "scenes.menu", { effect = "slideRight", time = 400 } ); end,1 );
            elseif runtime.settings["currentscene"] == "gameAbout" then
                timer.performWithDelay(90, function() composer.gotoScene( "scenes.menu", { effect = "slideLeft", time = 400 } ); end,1 );
            elseif runtime.settings["currentscene"] == "highscores" then
                timer.performWithDelay(90, function() composer.gotoScene( "scenes.menu", { effect = "crossFade", time = 400 } ); end,1 );
            end
        end
        return true;
    end
    if event.keyName == "left" or event.keyName == "right" or event.keyName == "space" then
        if event.phase == "down" then
            runtime.keyDown[event.keyName] = true
        else
            runtime.keyDown[event.keyName] = false
        end
    end
    return false; -- allow hardware to handle all other keys, including volume
end
Runtime:addEventListener( "key", onKeyEvent )

--Start the background loop
runtime.playBackgroundTrack()

-- Now change scene to go to the menu.
composer.gotoScene( "scenes.menu", "fade", 400 )
