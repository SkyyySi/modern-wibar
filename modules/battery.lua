local bm = require("better-lua-modules.src")

---@class SkyyySi.modern-wibar.modules.battery : SkyyySi.better-lua-module
---@field has_battery boolean
---@field battery table
---@field current_charge number
---@field current_charge_percentage_string string
---@field callbacks fun(current_charge: number)[]
local module = bm.create_module {
	name = "SkyyySi.modern-wibar.modules.battery"
}

local lgi = require("lgi")

module.__properties.has_battery = {
	---@param self SkyyySi.modern-wibar.modules.battery
	---@return boolean
	get = function(self)
		return next(lgi.UPowerGlib.Client():get_devices()) ~= nil
	end,

	---@param self SkyyySi.modern-wibar.modules.battery
	---@param value boolean
	set = function(self, value)
	end,
}

module.__properties.battery = {
	---@param self SkyyySi.modern-wibar.modules.battery
	---@return table
	get = function(self)
		local devs = lgi.UPowerGlib.Client():get_devices()
		local dev = devs[1]
		for _, device in pairs(devs) do
			if device:get_object_path():match("/battery_BAT[0-9]+$") then
				dev = device
				break
			end
		end

		return dev
	end,

	---@param self SkyyySi.modern-wibar.modules.battery
	---@param value table
	set = function(self, value)
	end,
}

module.__properties.current_charge = {
	---@param self SkyyySi.modern-wibar.modules.battery
	---@return number
	get = function(self)
		if not self.has_battery then
			return 100
		end

		local dev = self.battery

		return 100 * (dev["energy"] / dev["energy-full"])
	end,

	---@param self SkyyySi.modern-wibar.modules.battery
	---@param value number
	set = function(self, value)
	end,
}

module.__properties.current_charge_percentage_string = {
	---@param self SkyyySi.modern-wibar.modules.battery
	---@return string
	get = function(self)
		local power_string = tostring(math.floor(self.current_charge + 0.5)).."%"

		while #power_string < 4 do
			power_string = " "..power_string
		end

		return power_string
	end,

	---@param self SkyyySi.modern-wibar.modules.battery
	---@param value string
	set = function(self, value)
	end,
}

---@type fun(current_charge: number)[]
module._callbacks = {}

function module:run_callbacks()
	local current_charge = module.current_charge

	for k, v in ipairs(module.callbacks) do
		v(current_charge)
	end
end

module.__properties.callbacks = {
	---@param self SkyyySi.modern-wibar.modules.battery
	---@return fun(current_charge: number)[]
	get = function(self)
		return self._callbacks
	end,

	---@param self SkyyySi.modern-wibar.modules.battery
	---@param value fun(current_charge: number)[]
	set = function(self, value)
		self._callbacks = value

		self:run_callbacks()
	end,
}

if module.has_battery then
	local dev = module.battery

	dev.on_notify = function()
		module:run_callbacks()
	end
end

return module
