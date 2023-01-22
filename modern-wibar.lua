local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local lgi = require("lgi")
local dpi = beautiful.xresources.apply_dpi

local bm = require("better-lua-modules.src")

local module = bm.create_module {
	name = "SkyyySi.modern-wibar"
}

module.const = {}

module.const.modkey = modkey or "Mod4"
module.const.base_unit = dpi(8)
module.const.spacing = module.const.base_unit
module.const.font_size = " "..tostring(math.floor(module.const.base_unit+0.5))
module.const.font = (beautiful.font or "sans")..module.const.font_size
module.const.monospace_font = (beautiful.font or "monospace")..module.const.font_size
module.const.bg = "#FFFFFF"
module.const.fg = "#6000C0"
module.const.bg_hover = module.const.fg.."20"
module.const.bg_press = module.const.fg.."40"
module.const.position = "bottom"

module.battery = require("modules.battery")
module.layouttext = require("modules.layouttext")

local recolored_imagebox
do
	local _wibox_old = package.loaded.wibox
	package.loaded.wibox = nil
	local wb = require("wibox")
	recolored_imagebox = wb.widget.imagebox
	recolored_imagebox._old_set_image = recolored_imagebox.set_image
	function recolored_imagebox:set_image(img)
		if self.forced_color then
			img = gears.color.recolor_image(img, self.forced_color)
		end

		self:_old_set_image(img)
	end
	package.loaded.wibox = _wibox_old
end

local function wrapper(widget)
	return {
		{
			widget,
			margins = module.const.spacing,
			widget  = wibox.container.margin,
		},
		bg     = module.const.bg,
		fg     = module.const.fg,
		shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 2) end,
		widget = wibox.container.background,
	}
end

---@param s screen
local function create_bar(s)
	local bar = awful.wibar {
		type     = "dock",
		position = module.const.position,
		height   = module.const.base_unit * 8,
		bg       = gears.color.transparent,
	}

	local calendar_popup = awful.widget.calendar_popup.month {
		bg     = module.const.bg,
		font   = module.const.font,
		screen = s,
		style_month = {
			bg_color = module.const.bg,
			border_width = 0,
			padding = module.const.spacing,
			shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 2) end,
		},
		style_header = {
			markup = "<b>%s</b>",
			bg_color = module.const.fg,
			fg_color = module.const.bg,
			border_width = 0,
			shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit) end,
		},
		style_weekday = {
			bg_color = module.const.bg_hover,
			fg_color = module.const.fg,
			border_width = 0,
			shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit) end,
		},
		style_focus = {
			markup = "<b>%s</b>",
			bg_color = module.const.fg,
			fg_color = module.const.bg,
			border_width = 0,
			shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit) end,
		},
		style_normal = {
			bg_color = module.const.bg_hover,
			fg_color = module.const.fg,
			border_width = 0,
			shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit) end,
		},
	}
	calendar_popup.shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 2) end

	local taglist_widget = awful.widget.taglist {
		screen = s,
		filter = awful.widget.taglist.filter.all,
		style  = {
			shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 1.5) end,
			squares_sel         = gears.surface(),
			squares_unsel       = gears.surface(),
			squares_sel_empty   = gears.surface(),
			squares_unsel_empty = gears.surface(),
			squares_resize      = gears.surface(),
			bg_focus = module.const.fg,
			fg_focus = module.const.bg,
			font = module.const.font,
		},
		layout = {
			spacing = module.const.spacing,
			layout  = wibox.layout.fixed.horizontal
		},
		widget_template = {
			{
				{
					{
						id     = "text_role",
						widget = wibox.widget.textbox,
					},
					margins = dpi(4),
					widget  = wibox.container.margin,
				},
				layout = wibox.layout.fixed.horizontal,
			},
			id     = "background_role",
			widget = wibox.container.background,
			create_callback = function(self, c3, index, objects)
				local old_cursor, old_wibox

				self:connect_signal("mouse::enter", function()
					self._bg_backup = self.bg
					self._fg_backup = self.fg
					self.bg = module.const.bg_hover
					self.fg = module.const.fg

					local wb = mouse.current_wibox or {}
					old_cursor, old_wibox = wb.cursor, wb
					wb.cursor = "hand1"
				end)

				self:connect_signal("mouse::leave", function()
					if not self._skip_backup then
						self.bg = self._bg_backup or module.const.bg
						self.fg = self._fg_backup or module.const.fg
					end
					self._bg_backup = nil
					self._fg_backup = nil
					self._skip_backup = false

					old_wibox.cursor = old_cursor
					old_wibox = nil
				end)

				self:connect_signal("button::press", function()
					self._skip_backup = true
				end)
			end,
		},
		buttons = {
			awful.button({}, 1, function(t) t:view_only() end),
			awful.button({ module.const.modkey }, 1, function(t)
				if client.focus then
					client.focus:move_to_tag(t)
				end
			end),
			awful.button({}, 3, awful.tag.viewtoggle),
			awful.button({ module.const.modkey }, 3, function(t)
				if client.focus then
					client.focus:toggle_tag(t)
				end
			end),
			awful.button({}, 4, function(t) awful.tag.viewprev(t.screen) end),
			awful.button({}, 5, function(t) awful.tag.viewnext(t.screen) end),
		},
	}

	--- The device may not be a laptop, in which case
	--- we also don't need to show the charging percentage
	local battery_label_widget = module.battery.has_battery and {
		{
			id     = "battery_label_role",
			text   = "???%",
			font   = module.const.monospace_font,
			widget = wibox.widget.textbox,
		},
		left   = module.const.spacing,
		right  = module.const.spacing,
		widget = wibox.container.margin,
	} or nil

	local layout_list_popup
	do
		local layout_list_widget = awful.widget.layoutlist {
			screen      = s,
			base_layout = wibox.widget {
				--spacing = spacing,
				layout  = wibox.layout.flex.vertical,
			},
			style = {
				bg_normal = module.const.bg,
				fg_normal = module.const.fg,
				bg_selected = module.const.bg_hover,
				fg_selected = module.const.fg,
				shape          = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 1.5) end,
				shape_selected = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 1.5) end,
			},
			widget_template = {
				{
					{
						{
							{
								{
									id            = "icon_role",
									forced_height = dpi(48),
									forced_width  = dpi(48),
									forced_color  = module.const.fg,
									widget        = recolored_imagebox,
								},
								{
									id            = "text_role",
									forced_height = dpi(48),
									widget        = wibox.widget.textbox,
								},
								spacing = module.const.spacing,
								layout  = wibox.layout.fixed.horizontal,
							},
							margins = dpi(4),
							widget  = wibox.container.margin,
						},
						id     = "background_role",
						shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 1.5) end,
						widget = wibox.container.background,
					},
					margins = dpi(4),
					widget  = wibox.container.margin,
				},
				fg     = module.const.fg,
				bg     = module.const.bg,
				widget = wibox.container.background,
			},
		}

		layout_list_popup = awful.popup {
			visible        = false,
			ontop          = true,
			minimum_height = #awful.layout.layouts * dpi(48),
			maximum_height = #awful.layout.layouts * dpi(48),
			shape          = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 2) end,
			bg             = gears.color.transparent,
			widget         = {
				layout_list_widget,
				shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 2) end,
				widget = wibox.container.background,
			},
		}

		function layout_list_popup:placement_fn()
			local widget_geo = mouse.current_widget_geometry

			awful.placement.align(self, {
				margins = module.const.spacing,
				honor_workarea = true,
				position = module.const.position.."_right",
			})

			if widget_geo and widget_geo.x and widget_geo.width and self.width then
				self.x = widget_geo.x + widget_geo.width / 2 - self.width / 2 + s.geometry.x / 2
			end
		end

		function layout_list_popup:toggle()
			self.visible = not self.visible

			self:placement_fn()
		end

		layout_list_popup:connect_signal("button::press", function()
			layout_list_popup.visible = false
		end)
	end

	local aweome_icon = beautiful.theme_assets.awesome_icon(dpi(64), module.const.fg, module.const.bg)
	bar.widget = wibox.widget {
		{
			wrapper {
				{
					awful.widget.launcher {
						image = aweome_icon,
						menu  = awful.menu {
							items = {
								{ "Terminal", terminal or "xterm" },
								{ "Reload", awesome.restart },
								{ "Quit", awesome.quit },
							}
						},
					},
					shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 1.5) end,
					widget = wibox.container.background,
				},
				awful.widget.tasklist {
					screen   = s,
					filter   = awful.widget.tasklist.filter.currenttags,
					layout   = {
						spacing = module.const.spacing,
						layout  = wibox.layout.fixed.horizontal,
					},
					style = {
						shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 1.5) end,
						bg_normal = module.const.bg,
						bg_focus = module.const.fg,
						bg_urgent = "#FF0044",
					},
					widget_template = {
						{
							{
								id     = "clienticon",
								widget = awful.widget.clienticon,
							},
							margins = dpi(2),
							widget  = wibox.container.margin,
						},
						id     = "background_role",
						widget = wibox.container.background,
						create_callback = function(self, c, index, objects)
							self:get_children_by_id("clienticon")[1].client = c
						end,
					},
					buttons  = {
						awful.button({ }, 1, function (c)
							c:activate { context = "tasklist", action = "toggle_minimization" }
						end),
						awful.button({ }, 3, function() awful.menu.client_list { theme = { width = dpi(250) } } end),
						awful.button({ }, 4, function() awful.client.focus.byidx(-1) end),
						awful.button({ }, 5, function() awful.client.focus.byidx( 1) end),
					},
				},
				spacing = module.const.spacing,
				layout  = wibox.layout.fixed.horizontal,
			},
			margins = module.const.spacing,
			widget  = wibox.container.margin,
		},
		nil, -- nothing in the middle
		{ -- right side
			{
				wrapper(taglist_widget),
				wrapper {
					{
						{
							module.layouttext {
								font      = module.const.font,
								on_update = function() layout_list_popup:placement_fn() end,
								screen    = s,
							},
							left   = module.const.spacing,
							right  = module.const.spacing,
							widget = wibox.container.margin,
						},
						id     = "layout_label_background_role",
						shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 1.5) end,
						widget = wibox.container.background,
					},
					battery_label_widget,
					spacing = module.const.spacing,
					layout  = wibox.layout.fixed.horizontal,
				},
				wrapper {
					{
						{
							format = "%H:%M",
							font   = module.const.monospace_font,
							widget = wibox.widget.textclock,
						},
						left   = module.const.spacing,
						right  = module.const.spacing,
						widget = wibox.container.margin,
					},
					id     = "text_clock_background_role",
					shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, module.const.base_unit * 1.5) end,
					widget = wibox.container.background,
				},
				spacing = module.const.spacing,
				layout  = wibox.layout.fixed.horizontal,
			},
			margins = module.const.spacing,
			widget  = wibox.container.margin,
		},
		layout = wibox.layout.align.horizontal,
	}

	for _, c in ipairs(bar.widget:get_children_by_id("text_clock_background_role")) do
		local old_cursor, old_wibox

		c:connect_signal("mouse::enter", function()
			c.bg = module.const.bg_hover
			c.fg = module.const.fg

			local wb = mouse.current_wibox or {}
			old_cursor, old_wibox = wb.cursor, wb
			wb.cursor = "hand1"
		end)

		c:connect_signal("mouse::leave", function()
			c.bg = module.const.bg
			c.fg = module.const.fg

			old_wibox.cursor = old_cursor
			old_wibox = nil
		end)

		c:connect_signal("button::press", function(_,_,_,button)
			if button ~= 1 then
				return
			end

			c.bg = module.const.bg_press
		end)

		c:connect_signal("button::release", function(_,_,_,button)
			if button ~= 1 then
				return
			end

			c.bg = module.const.bg_hover

			calendar_popup:toggle()
			awful.placement.align(calendar_popup, {
				margins = module.const.spacing,
				honor_workarea = true,
				position = module.const.position.."_right",
			})
		end)
	end

	for _, c in ipairs(bar.widget:get_children_by_id("layout_label_background_role")) do
		local old_cursor, old_wibox

		c:connect_signal("mouse::enter", function()
			c.bg = module.const.bg_hover
			c.fg = module.const.fg

			local wb = mouse.current_wibox or {}
			old_cursor, old_wibox = wb.cursor, wb
			wb.cursor = "hand1"
		end)

		c:connect_signal("mouse::leave", function()
			c.bg = module.const.bg
			c.fg = module.const.fg

			old_wibox.cursor = old_cursor
			old_wibox = nil
		end)

		c:connect_signal("button::press", function(_,_,_,button)
			if not (button == 1 or button == 4 or button == 3 or button == 5) then
				return
			end

			c.bg = module.const.bg_press
		end)

		c:connect_signal("button::release", function(_,_,_,button)
			if button == 1 or button == 4 then
				awful.layout.inc(1)
			elseif button == 3 then
				layout_list_popup:toggle()
			elseif button == 5 then
				awful.layout.inc(1)
			else
				return
			end

			c.bg = module.const.bg_hover
		end)
	end

	table.insert(module.battery._callbacks, function()
		local current_charge = module.battery.current_charge_percentage_string

		for _, c in ipairs(bar.widget:get_children_by_id("battery_label_role")) do
			c.text = current_charge
		end
	end)

	module.battery:run_callbacks()

	return bar
end

return create_bar
