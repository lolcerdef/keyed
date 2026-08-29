return {
	beattools = {
		path = 'lovely/place-custom.events.toml', name = 'btPEDecoder', run = true, from = ';" then', to = 'if E', inclusive = false, before = 'return function(placeEvent)', after = 'return placingEvent\nend', replace = {'self.placeEvent', 'placeEvent', 'self.cursorBeat', 'cs.editorBeat', 'self.cursorAngle', '0'}
	},
	['editor-Easable-List'] = { --the fact that Palette was misspelled caused me great pain
		path = 'lovely/AddPallete.toml', name = 'eelPEDecoder', run = true, before = 'return function(placeEvent)', after = 'return {type = typePlace, time = cs.editorBeat, angle = 0, var = PathTotheEaseIs, value = Default, enable = Default}\nend', from = 'PathTotheEaseIs = FindPathToEase(self.placeEvent, "", Easables, PlaceEventDesc)', to = 'local typePlace = (typePallete and "setBoolean") or "ease"', replace = {'self.placeEvent', 'placeEvent'}
	}
}