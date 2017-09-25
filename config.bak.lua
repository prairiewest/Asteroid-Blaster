
-- config.lua
local aspectRatio
if display ~= nil then
	aspectRatio = display.pixelHeight / display.pixelWidth
else
	aspectRatio = 960 / 640
end

application =
{
    content =
    {
            width = aspectRatio > 1.5 and 320 or math.ceil(480 / aspectRatio),
            height = aspectRatio < 1.5 and 480 or math.ceil(320 * aspectRatio),
            scale = "letterbox",
			fps = 60,
			imageSuffix =
			{
				["@2x"] = 1.5,
			},
    },
    license =
    {
        google =
        {
            key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkmo7ohXVZkkUBvK+qAC2pUZQXdNvhWKqRBd1FYxZIoPedonbImYkCQmBm38atQchbOlO9puRzAE101AbwGMIhYbokeOSXkEJ6/rw0+bDrj38JF6Y0Lf7Q96K5dBuQu+mT9xr2yYusQvKovPk/3cF6/tda4C3aVo3oyJM7JqWjn9SiegmuKz+V5qy13ISPBKhf2+7Km14MY9nuBL+T7e7RBSFwxZy+jaIBJRFAYgLeetawK+xURFKZKn/31/xcSmMwiwPxEN4B83T42Dflwm+slviS72eZZepLeo8wv6kr1N6vaq/iL2KsJeZJmL1UbOhU9jdmj8piZc75LKv4P+wTwIDAQAB",
        },
    },
}
