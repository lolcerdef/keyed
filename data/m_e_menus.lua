return {
	beattools = {
		{
			path = 'files/calculator.lua', name = 'Calculator', run = true, replace = {
				'mod.config.editorCalculator', 'cs.enabledModEMenus["beattools"].Calculator', "Calculate", "Calculate##keyframer",
				'mod.', 'mods.beattools.',
			}
		},
		{
			path = 'files/bookmarkList.lua', name = 'Bookmark List', run = true, replace = {
				'mod.config.bookmarkList', 'cs.enabledModEMenus["beattools"]["Bookmark List"]', '"Bookmarks', '"Bookmarks##keyframer',
				'mod.', 'mods.beattools.', 'cs:noSelection()', 'cs:clearSelection()', 'cs.selectedEvent = cs.level.events[utilitools.files.beattools.easing.getIndex(bookmark.event)]',
				'cs:selectSingle("marker", cs.level.events[utilitools.files.beattools.easing.getIndex(bookmark.event)])'
			}
		},
		{
			path = 'lovely/menu-in-editor.toml', name = 'Beattools', run = true, from = 'if mods.beattools.config.editorMenu then', to = 'imgui.End()',
				before = "return function(window_flag, inputFlag)", after = 'end\nend', replace = {'mods.beattools.config.editorMenu', 'cs.enabledModEMenus["beattools"]["Beattools"]', 'self.', 'cs.',
				's",', 's##keyframer",'}
		}
	},
	['editor-guide'] = {
		{
			path = 'editorGuide.lua', name = 'Editor Guide', run = true, replace = {
				'return eg', [[return function(window_flag, inputFlag)
if mod.config.window then
	helpers.SetNextWindowPos(60,60, window_flag)
	helpers.SetNextWindowSize(1040,600, window_flag)
	mod.config.window = imgui.Begin("Editor Guide##keyframer", true, inputFlag)
	eg.gui()
	imgui.End()
end
end]], 'mod.config.window', 'cs.enabledModEMenus["editor-guide"]["Editor Guide"]',
			}
		}
	},
	['editor-Easable-List'] = {{
		path = 'lovely/AddPallete.toml', name = 'Ease Pallete', run = true, from = 'Easables = {', to = 'imgui.End()', replace = {'imgui.Begin("Ease pallete")', 'return function()\nimgui.Begin("Ease pallete##keyframer")\nlocal self = cs', 'imgui.End()', 'imgui.End()\nend'}}
	}
}