local rpath = string.gsub(mods.keyed.path, '/', '.') .. '.'
local function ld(p)
	return require(rpath .. 'data.' .. p)
end

pyp = require(rpath .. 'libs.pyp')

keyed_needed_data = {
	eventPalette = ld('event_palette'),
	moddedEditorMenus = ld('m_e_menus'),
	paletteEventDecoders = ld('m_p_e_decoders'),
}

--[[
i wonder if it is possible to make it so that other modders
can have a folder called keyed_addon with a mini mod to add stuff to
keyed_needed_data or patch Keyframer itself without having to 
figure out what name the folder has
]]