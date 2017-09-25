-- This file is responsible for drawing and animating the starfield background
M = {}

-- Layer 1 scrolls at this speed, layer 2 at twice this speed
-- The layer 3 stars have their own independent speeds
M.scrollSpeed = 1
M.numStars = 40

-- scale the background image to fit the device
M._W = display.contentWidth
M._H = display.contentHeight
M.bgImageWidth = 360
M.bgImageHeight = 720
if M._W > M.bgImageWidth then
    M.bgImageWidth = M._W
    M.bgImageHeight = M.bgImageHeight * M._W / 360
end
if M._H > M.bgImageHeight then
    M.bgImageHeight = M._H
    M.bgImageWidth = bgwidth * M._H / 720
end

-- Tables for all of the starfield objects
M.bgLayer1 = {}
M.bgLayer2 = {}
M.bgStars = {}

M.create = function(scene)
    M.bgGroup = display.newGroup()
    scene.view:insert(M.bgGroup)

    -- Add the first two layer images to the background group
    for i = 1,3 do
        M.bgLayer1[i] = display.newImageRect( M.bgGroup, "images/background/layer1.png", M.bgImageWidth, M.bgImageHeight )
        M.bgLayer1[i].x, M.bgLayer1[i].y = M._W * 0.5, M._H * 0.5 - M.bgImageHeight + (M.bgImageHeight * (i-1))
    end
    bgLayer2 = {}
    for i = 1,3 do
        M.bgLayer2[i] = display.newImageRect( M.bgGroup, "images/background/layer2.png", M.bgImageWidth, M.bgImageHeight )
        M.bgLayer2[i].x, M.bgLayer2[i].y = M._W * 0.5, M._H * 0.5 - M.bgImageHeight + (M.bgImageHeight * (i-1))
    end
    
    -- Add the individual stars for layer 3
    for i = 1, M.numStars do
        M.bgStars[i] = display.newRect(M.bgGroup,0,0,2,2)
        local opacity = math.random(30,100)/100
        M.bgStars[i]:setFillColor(1,1,1,opacity)
        M.bgStars[i].x = math.random(0,M._W)
        M.bgStars[i].y = math.random(0,M._H)
        M.bgStars[i].xScroll = math.random(-2,2)
        M.bgStars[i].yScroll = math.random(2,15)
    end  
end

-- Scroll all three layers vertically
M.scroll = function(multiplier)
    if type(multiplier) == "number" then
        local ss = M.scrollSpeed * multiplier
        local ss2 = M.scrollSpeed * multiplier * 2.5
        local mh = M._H * 1.5
        local mh2 = M._H * 2
        local mh5 = M._H*0.5
        for i = 1,3 do
            M.bgLayer1[i].y = M.bgLayer1[i].y + ss
            if M.bgLayer1[i].y > (mh) then
                M.bgLayer1[i]:translate( 0, 0 - mh2 )
            end
            M.bgLayer2[i].y = M.bgLayer2[i].y + ss2
            if M.bgLayer2[i].y > (mh) then
                M.bgLayer2[i]:translate( 0, 0 - mh2 )
            end
        end
        for i = 1,#M.bgStars do
            M.bgStars[i].x = M.bgStars[i].x + M.bgStars[i].xScroll
            M.bgStars[i].y = M.bgStars[i].y + M.bgStars[i].yScroll
            if (M.bgStars[i].x < 0 or M.bgStars[i].x > M._W or M.bgStars[i].y > M._H) then
                M.bgStars[i].x = math.random(0,M._W)
                M.bgStars[i].y = math.random(0,mh5)
                M.bgStars[i].xScroll = math.random(-3,3)
                M.bgStars[i].yScroll = math.random(2,20)            
            end
        end
    end
end

-- Move the layer 3 stars left or right
M.move = function(amount, pctLow, pctHigh)
    local percent = pctLow
    local ap = amount*percent
    local mh5 = M._H*0.5
    for i = 1,#M.bgStars do
        M.bgStars[i].x = M.bgStars[i].x + ap
        if (M.bgStars[i].x < 0 or M.bgStars[i].x > M._W or M.bgStars[i].y > M._H) then
            M.bgStars[i].x = math.random(0,M._W)
            M.bgStars[i].y = math.random(0,mh5)
            M.bgStars[i].xScroll = math.random(-3,3)
            M.bgStars[i].yScroll = math.random(2,20)            
        end
        percent = percent + 0.05
        if percent > pctHigh then percent = pctLow; end
    end
end

return M