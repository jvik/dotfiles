-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Toggle dark/light mode
wezterm.on("toggle-dark-mode", function(window, pane)
	local light_scheme = "rose-pine-dawn"
	local dark_scheme = "rose-pine"
	local overrides = window:get_config_overrides() or {}
	wezterm.log_info("Current color scheme is: ", overrides.color_scheme)
	if overrides.color_scheme == light_scheme then
		wezterm.log_info("Switching to dark scheme")
		overrides.color_scheme = dark_scheme
	else
		wezterm.log_info("Switching to light scheme")
		overrides.color_scheme = light_scheme
	end
	window:set_config_overrides(overrides)
end)

config.max_fps = 120

-- config.front_end = "Sotftware"
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"

-- color config --
config.color_scheme = "Gruvbox (Gogh)"
--config.color_scheme = "Catppuccin Frappe"
--config.color_scheme = "Catppuccin Latte"
--config.color_scheme = "rose-pine-dawn"
config.colors = {
	selection_bg = "#d2d0e7", -- litt mer kontrast enn Rosé Pine Dawn sin default
	selection_fg = "#26233a", -- mørk tekst på lys bakgrunn
}
--config.color_scheme = "Monokai (light) (terminal.sexy)"
config.force_reverse_video_cursor = true
-- config.default_cursor_style = 'BlinkingBlock' --

-- setup wsl domain --
-- config.default_domain = "WSL:Ubuntu"
-- font size --
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 12
config.hide_tab_bar_if_only_one_tab = true
config.window_close_confirmation = "NeverPrompt"

config.enable_scroll_bar = false

config.mouse_bindings = {
	-- CMD-click will open the link under the mouse cursor
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "ALT",
		action = wezterm.action.OpenLinkAtMouseCursor,
	},
}

-- quickselect --
config.quick_select_patterns = {
	-- match things that look like sha1 hashes
	-- (this is actually one of the default patterns)
	-- "\\b[\\w-]+\\b", --
	"\\b[^\\s]+\\b",
}

config.inactive_pane_hsb = {
	saturation = 0.9,
	brightness = 0.5,
}

config.alternate_buffer_wheel_scroll_speed = 30
config.use_dead_keys = false

-- keys --
config.keys = {
	-- { key = 'U', mods = 'SHIFT|ALT|CTRL', action = act.SplitVertical{ domain =  'CurrentPaneDomain' } }, --
	{ key = "-", mods = "SHIFT|ALT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "_", mods = "SHIFT|ALT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "=", mods = "SHIFT|ALT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "%", mods = "SHIFT|ALT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "+", mods = "SHIFT|ALT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "|", mods = "SHIFT|ALT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "h", mods = "SHIFT|ALT", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "SHIFT|ALT", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "SHIFT|ALT", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "SHIFT|ALT", action = act.ActivatePaneDirection("Right") },
	{ key = "h", mods = "CTRL|SHIFT|ALT", action = act.AdjustPaneSize({ "Left", 5 }) },
	{ key = "j", mods = "CTRL|SHIFT|ALT", action = act.AdjustPaneSize({ "Down", 5 }) },
	{ key = "k", mods = "CTRL|SHIFT|ALT", action = act.AdjustPaneSize({ "Up", 5 }) },
	{ key = "l", mods = "CTRL|SHIFT|ALT", action = act.AdjustPaneSize({ "Right", 5 }) },
	{ key = "q", mods = "SHIFT|CTRL", action = wezterm.action.QuickSelect },
	{ key = "PageUp", action = act.ScrollByPage(-0.5) },
	{ key = "PageDown", action = act.ScrollByPage(0.5) },
	{
		key = "W",
		mods = "SHIFT|CTRL",
		action = wezterm.action.CloseCurrentPane({ confirm = false }),
	},
	{ key = "v", mods = "CTRL", action = wezterm.action.PasteFrom("Clipboard") },
	{
		key = "v",
		mods = "SHIFT|CTRL",
		action = wezterm.action_callback(function(window, pane)
			window:perform_action(wezterm.action.SendKey({ key = "v", mods = "CTRL" }), pane)
		end),
	},
	{
		key = "V",
		mods = "SHIFT|CTRL",
		action = wezterm.action_callback(function(window, pane)
			window:perform_action(wezterm.action.SendKey({ key = "v", mods = "CTRL" }), pane)
		end),
	},
	{ key = "c", mods = "ALT", action = wezterm.action.CopyTo("ClipboardAndPrimarySelection") },
	{ key = "v", mods = "ALT", action = wezterm.action.PasteFrom("Clipboard") },
}

-- table.insert(config.keys, {
--	key = "l",
--end	mods = "CTRL",
--	action = wezterm.action({ EmitEvent = "toggle-dark-mode" }),
--})

-- and finally, return the configuration to wezterm
return config
