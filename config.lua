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
            width = aspectRatio > 1.5 and 640 or math.ceil(960 / aspectRatio),
            height = aspectRatio < 1.5 and 960 or math.ceil(640 * aspectRatio),
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
            key = "SOME_VERY_LONG_STRING",
        },
    },
}
