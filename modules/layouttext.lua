local awful = require("awful")
local wibox = require("wibox")

local bm = require("better-lua-modules.src")

---@class SkyyySi.modern-wibar.modules.layouttext : SkyyySi.better-lua-module
local module = bm.create_module {
	name = "SkyyySi.modern-wibar.modules.layouttext"
}

function module.new(args)
	args.on_update = args.on_update or function() end
	args.widget = wibox.widget.textbox
	local w = wibox.widget(args)

	function w:update()
		self._layout_name = tostring(awful.layout.getname(awful.layout.get(args.screen)))
		self.text = self._layout_name
		args.on_update()
	end
	w:update()

	for _, t in pairs(args.screen.tags) do
		t:connect_signal("property::selected", function()
			w:update()
		end)

		t:connect_signal("property::layout", function()
			w:update()
		end)
	end

	return w
end

function module.__mt:__call(...)
	return self.new(...)
end

return module
