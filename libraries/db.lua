local M = {}

local sqlite3 = require("sqlite3")
local runtime = require("libraries.runtime")

--------------------------------------------
-- DATABASE 
--------------------------------------------
M.init = function()
	local db = sqlite3.open(runtime.dbPath)

	local playerSetup = [[
		CREATE TABLE IF NOT EXISTS settings (
			key TEXT,
			value TEXT,
			vtype TEXT
		);
	]]
	db:exec(playerSetup)

	for row in db:nrows("SELECT max(value) as dbversion FROM settings where key = 'dbversion';") do
		local dbversion = row.dbversion
		if not (dbversion) then
			local datasetup = [[
				BEGIN TRANSACTION;

				INSERT INTO settings (key,value,vtype) VALUES 
					('dbversion','1.0','f'),
					('bgvolume','0.40','f'),
					('fxvolume','0.70','f'),
					('highscore','0','i'),
					('gamesplayed','0','i');
					
				COMMIT;
			]];
			db:exec( datasetup );
			dbversion = 1.0
			runtime.logger("[DB] created db version " .. dbversion)
		else
			dbversion = tonumber(dbversion)
		end

	end
	
	-- load settings
	for row in db:nrows("SELECT key, value, vtype FROM settings;") do
		if row.vtype == 'f' then
			runtime.settings[row.key] = tonumber(row.value)
		elseif row.vtype == 'i' then
			runtime.settings[row.key] = tonumber(row.value)
		else
			runtime.settings[row.key] = row.value
		end
	end
	runtime.logger("[DB] Loaded settings" )
	
	runtime.setChannelVolumes()

	db:close()
end

M.saveSetting = function(sName,sValue,vType)
    if vType == nil then vType = "s"; end
    local updateSQL
	if (sValue ~= nil) then
		local db = sqlite3.open(runtime.dbPath)
		local existing = false
        for row in db:nrows("SELECT key, value, vtype FROM settings where key = '" .. sName .. "';") do
            existing = true
        end
        if existing then
		  updateSQL = "UPDATE settings SET value='" .. sValue .."' WHERE key='" .. sName .. "';"
		else
		  updateSQL = "INSERT INTO settings (key,value,vtype) values ('"..sName.."','"..sValue.."','"..vType.."');"
		end
	    db:exec(updateSQL)
		db:close()
	end
	runtime.settings[sName] = sValue
	runtime.logger("Saved setting [" .. sName .. "] = " .. sValue)
end


M.init()
return M