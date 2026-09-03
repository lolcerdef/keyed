local st = Gamestate:new('Keyframer')

local keyedConfig = mods.keyed.config
local function convertCol(c)
	local a = math.floor(c / 0x1000000) % 0x100
	local r = math.floor(c / 0x10000) % 0x100
	local g = math.floor(c / 0x100) % 0x100
	local b = c % 0x100
	
	return {r / 255, g / 255, b / 255, a / 255}
end

-- constant things that used to be made every frame/multiple times

-- clors :3
local BGC = 0xFF222222
local labelBGC = 0xFF1A1A1A
local rowAltC = 0xFF272727
local lineC = 0xFF3C3C3C
local lineHiC = 0xFF5A5A5A
local textC = 0xFFB0B0B0
local playC = 0xFF3AA0FF
local keyC = 0xFFE0C040
local keySelC = 0xFFFF6060
local selBoxC = 0xFF90FF4F
local selBoxFillC = 0x3390FF4F

local function eventSort(a, b)
	if a.time == b.time then
		return (a.order or 0) < (b.order or 0)
	end
	return a.time < b.time
end

local loadTheseMarkers = {
	loadCustomFont = true,
	newCanvas = true,
	--decoShader = true,
	tags = true, 
	stamp = true, 
	aft,
} -- probably more i'm forgetting rn
-- tags inset events into self.playEvents, perhaps this could be used?
-- like maybe self.playEvents get rebuilt when a tag is added/removed/modified
-- and everything else looks in this?
-- tags are probably the only thing that does this no?

st:setInit(function(self, level, variant, beat, preloadSoundData)
	em.clear()
	
	love.keyboard.setTextInput(true)
	self.gm = em.init("GameManager") -- <- does something, not much though
	self.cmd = em.init("CommandHandler")
	
	self.canv = love.graphics.newCanvas(project.res.x,project.res.y)
	self.p._actualX = self.p.x
	self.p._actualY = self.p.y
	
	self.isPlaying = false
	mouse:disableGameplay()
	love.mouse.setVisible(true)
	mouse.hidden = true
	
	self.soundData = preloadSoundData
	self.timingInfo = {
		initial = {},
		timingPoints = {}
	}
	
	self.lastSaved = 0
	self.unsavedChanges = true
	
	shuv.usePalette = true
	shuv.showBadColors = true
	shuv.stateDisabled = nil
	shuv.disabledUntilNewState = false
	shuv.resetPal()
	
	self.drawHud = true
	self.showOnTop = true
	self.minLayer = nil
	self.maxLayer = nil
	
	-- negative one means main canvas, other wise would be string to get a canvas
	-- currently does nothing
	self.currentCanvas = -1
	
	self.editorBeat = beat or 0
	self.lastEditorBeat = self.editorBeat
	self.beatSize = 40
	self.timelineScroll = self.editorBeat - 50/self.beatSize
	self.timelineRowScroll = 0
	
	self.level = level or nil
	self.variant = variant
	if not self.level then
		self:leave()
		print("guh")
		return
	end
	
	self.drawDecos = true
	
	-- list of deco ids
	-- deco:id1 =  {id = "id1", kind = "deco", order = 2, events = {{time = 2, angle = 0, etc.}, etc.}},
	-- textdeco:otherid = {id = 'otherid', kind = "textdeco", order = 3, events = {{time = 0, angle = 0, etc.}, etc.}}
	self.decos = {}
	self.selectedEvents = { type = nil, events = {} }
	self.copiedEvents = { type = nil, events = {} }
	self.selectBoxActive = false
	
	self.decoObjects = {}
	
	self.timelineRows = {}
	self.rowsDirty = true
	
	self.easeVarSplitCache = {}
	
	self.markers = {}
	self.draggingMarker = nil
	self.markersByType = {}
	
	self.overlappingEventsDialogue = false
	self.overlappingEventsList = {}
	self.overlappingEventsType = nil
	
	-- i feel like some markers right now should be keyframes (for example advancetextdeco, stamps, eases, uniforms, etc.)
	-- i should really do it so that it shows the events sprite instead
	self.markerColors = {
		bookmark = 0xFFFFD86B,
		comment = 0xFF555555,
		tag = 0xFFF08E54,
		play = 0xFF4261FF,
		playSound = 0xFFFF4242,
		setBPM = 0xFF9B59B6,
		retime = 0xFF1ABC9C,
		showResults = 0xFF2ECC71,
		loadCustomFont = 0xFFE84393,
		advancetextdeco = 0xFFA29BFE,
		decoShader = 0xFF00CEC9,
		shader_uniform = 0xFF6C5CE7,
		newCanvas = 0xFFB8E986,
		editCanvas = 0xFF8E9B0C,
		ease = 0xFF74B9FF,
		outline = 0xFF95A5A6,
		setBgColor = 0xFFF1C40F,
		setBoolean = 0xFFFF7675,
		setColor = 0xFFD980FA,
		initObject = 0xFFFFFFFF,
		paddles = 0xFFB8CDFF,
		stamp = 0xFFEE5A6F,
		aft = 0xFF6AB04C,
		setJoystickColor = 0xFFFFC048,
		noise = 0xFF636E72,
		hom = 0xFFB2BEC3,
		songNameOverride = 0xFFFAB1A0,
	}
	
	self.decoTypes = {
		deco = true,
		textdeco = true,
		camera3d = true,
		deco3d = true,
	}
	
	local data = keyed_needed_data
	self.eventPalette = data.eventPalette
	
	-- hmm...
	self.loadedModEMenus = {}
	self.enabledModEMenus = helpers.copy(keyedConfig.enabledModEMenus or {})

	for k, v in pairs(data.moddedEditorMenus) do
		if mods[k] and mods[k].enabled then
			local path = mods[k].path .. '/'
			for i, entry in ipairs(v) do
				local chunk = pyp.get(path, entry, k .. '_' .. entry.name)
				if chunk then
					self.enabledModEMenus[k] = self.enabledModEMenus[k] or {}
					if self.enabledModEMenus[k][entry.name] == nil then
						self.enabledModEMenus[k][entry.name] = false
					end
					self.loadedModEMenus[k] = self.loadedModEMenus[k] or {}
					self.loadedModEMenus[k][entry.name] = chunk
				end
			end
		end
	end
	
	self.pEventDecoders = {}
	for k, v in pairs(data.paletteEventDecoders) do
		if mods[k] and mods[k].enabled then
			local path = mods[k].path .. '/'
			local chunk = pyp.get(path, v, k .. 'pEventDecoder')
			if chunk then
				table.insert(self.pEventDecoders, chunk)
			end
		end
	end
	
	if self.level then
		self:resetLoads()
	end
	
	self.mouseStartX = nil
	self.mouseStartY = nil
	self.isPanning = false
	self.placeEvent = ''
	self.editMode = "none"
	self.lockedAxis = "none"
	self.editInfo = {} -- startX/Y/Z/R/SX/SY/SZ, X/Y/Z/R/SX/SY/SZ
	-- changes to move, size, or rotate
	
	self.rateMod = 1
	
	self.beatSnapValues = { 1, 2, 3, 4, 5, 6, 8, 12, 16 }
	self.beatSnap = 2
	self.customBeatSnap = 16
	
	self.gridScale = 30
	self.pan = {0,0}
	
	self.resetwindows = false
	self.exitDialogue = false
	
	self.keybinds = {}
	
	self:addKeybind(function()
			LevelManager:saveLevel(self.level, cLevel, true, self.variant)
			self.p:hurtPulse()
			print("saved")
		end,
		'save',
		'ctrl', 'save'
	)
	self:addKeybind(function()
			local newEvents = {}
			if self.selectedEvents.type == 'keyframe' then
				local touchedKeys = {}
				local touchedDecos = {}
				for i, v in ipairs(self:getEList(self.selectedEvents)) do
					table.insert(newEvents, {type = v.type, time = self.editorBeat, angle = v.angle, id = v.id})
					local key = v.type .. ":" .. v.id
					if not touchedKeys[key] then
						touchedKeys[key] = true
						table.insert(touchedDecos, {type = v.type, id = v.id})
					end
				end
				
				if #newEvents > 1 then
					self.cmd:startGroup()
					self.cmd:executeNew(cmd.CreateMultiple,newEvents)
					self.cmd:endGroup("Made "..#newEvents.." keyframes")
				elseif #newEvents == 1 then
					self.cmd:executeNew(cmd.CreateEvent, newEvents[1])
				else
					print("make what keyframe?")
				end
				
				for _, d in ipairs(touchedDecos) do
					self:resetDecoEvents(d.type, d.id)
				end
				
				local newSelection = { type = 'keyframe', events = {} }
				for key in pairs(touchedKeys) do
					local deco = self.decos[key]
					if deco then
						for _, ev in ipairs(deco.events) do
							if ev.time == self.editorBeat then
								newSelection.events[ev] = true
							end
						end
					end
				end
				self.selectedEvents = newSelection
			elseif self.selectedEvents.type == 'marker' then
				local touchedTypes = {}
				for i, v in ipairs(self:getEList(self.selectedEvents)) do
					if v.type ~= 'play' and v.type ~= 'showResults' then
						local copy = helpers.copy(v)
						copy.time = self.editorBeat
						table.insert(newEvents, copy)
						touchedTypes[v.type] = true
					end
				end
				
				if #newEvents > 1 then
					self.cmd:executeNew(cmd.CreateMultiple,newEvents)
				elseif #newEvents == 1 then
					self.cmd:executeNew(cmd.CreateEvent, newEvents[1])
				else
					print("make what events?")
				end
				
				self:resetMarkers()
				
				local newSelection = { type = 'marker', events = {} }
				for _, m in ipairs(self.markers) do
					if touchedTypes[m.type] and m.time == self.editorBeat then
						newSelection.events[m] = true
					end
				end
				
				self.selectedEvents = newSelection
			else
				print("nothing selected?")
			end
		end,
		'make selected event',
		'i'
	)
	self:addKeybind(function()
			self:deleteSelectedEvents()
			self:rebuildDecoObjects()
		end,
		'delete selected event',
		'delete'
	)
	self:addKeybind(function()
			if self.selectedEvents.type ~= 'keyframe' then 
				print("hide what?")
				return
			end
			
			self.cmd:startGroup()
			local selected = self:getEList(self.selectedEvents)
			local hide = true
			if maininput:down("shift") then hide = false end
			for i, v in ipairs(selected) do
				self.cmd:executeNew(cmd.ModifyKeys, v, {hide = hide})
			end
			self.cmd:endGroup("Made "..#selected.." keyframes "..(hide and "hide" or "unhide"))
		end,
		'hide deco',
		'h'
	)
	
	local function setEditInfo()
		local list = self:getEList(self.selectedEvents)
		local endBeat = -math.huge
		for _, ev in ipairs(list) do
			local evEnd = ev.time + (ev.duration or 0)
			if evEnd > endBeat then
				endBeat = evEnd
			end
		end
		self.editorBeat = endBeat
		
		self:updateDecos()
		
		local deco, eventRef
		for _, ev in ipairs(list) do
			local key = ev.type .. ":" .. ev.id
			local d = self.decoObjects[key]
			if d then
				deco = d
				eventRef = ev
				break
			end
		end
		
		self.editInfo = {
			multiEdit = (#list > 1),
			startMouseX = mouse.rx + self.pan[1],
			startMouseY = mouse.ry + self.pan[2],
			startX = deco and deco.x or 300,
			startY = deco and deco.y or 180,
			startZ = deco and deco.z or nil,
			startR = deco and deco.r or 0,
			startSX = deco and deco.sx or 1,
			startSY = deco and deco.sy or 1,
			startSZ = deco and deco.sz or nil,
			decoRef = deco,
			eventRef = eventRef,
			shuvState = self.editInfo.shuvState or shuv.usePalette
		}
		shuv.usePalette = false
	end
	self:addKeybind(function()
			if self.isPlaying then return end
			if self.selectedEvents.type ~= 'keyframe' then 
				print("move what?")
				return
			end
			setEditInfo()
			self.editMode = "move"
		end,
		'move deco',
		'g'
	)
	self:addKeybind(function()
			if maininput:down("ctrl") or self.isPlaying then return end
			if self.selectedEvents.type ~= 'keyframe' then 
				print("scale what?")
				return
			end
			setEditInfo()
			self.editMode = "scale"
		end,
		'scale deco',
		's'
	)
	self:addKeybind(function()
			if maininput:down('ctrl') or maininput:down('shift') or self.isPlaying then return end
			if self.selectedEvents.type ~= 'keyframe' then 
				print("rotate what?")
				return
			end
			setEditInfo()
			self.editMode = "rotate"
		end,
		'rotate deco',
		'r'
	)
	self:addKeybind(function()
			self.lockedAxis = (self.editMode ~= 'none' and --need a check for 3d when we get there
				self.lockedAxis ~= "x") and "x" or "none"
		end,
		'axis x',
		'x'
	)
	self:addKeybind(function()
			self.lockedAxis = (self.editMode ~= 'none' and 
				self.lockedAxis ~= "y") and "y" or "none"
		end,
		'axis y',
		'y'
	)
	self:addKeybind(function()
			self.lockedAxis = (self.editMode ~= 'none' and 
				self.lockedAxis ~= "z") and "z" or "none"
		end,
		'axis z',
		'z'
	)
	self:addKeybind(function()
			self.resetwindows = true
		end,
		'reset window positions',
		'ctrl', 'r'
	)
	self:addKeybind(function()
			self.pan = {0,0}
		end,
		'reset pan position',
		'shift', 'r'
	)
	self:addKeybind(function() -- this perhaps sucks, doesn't play when editorBeat is before the play event
			self.isPlaying = not self.isPlaying
			if self.isPlaying and self.soundData then
				local volume = (savedata.options.audio.musicvolume/10)
				self.source = lovebpm.newTrack()
					:load(self.soundData)
					:setTiming(self.timingInfo)
					:setVolume(volume)
					:play()
					:on("end", function() log("song finished!!!!!!!!!!") end)
				self.source:setBeat(self.editorBeat--[[ - self:getRetimeOffset(self.editorBeat)]])
				
				if self.rateMod then
					self.source:setPitch(self.rateMod)
				end
			elseif self.soundData and self.source.isPlaying then
				self.source:stop()
			else
				self.unchangedEditorBeat = self.editorBeat
			end
		end,
		'start/end playback',
		'space'
	)
	self:addKeybind(function()
			if self.editMode == "none" then
				self.exitDialogue = true
			else
				self.editMode = "none"
				self.lockedAxis = "none"
				shuv.usePalette = self.editInfo.shuvState
			end
		end,
		'exit',
		'back'
	)
	self:addKeybind(function() 
		self.cmd:undo()
		self:resetLoads()
		self:rebuildDecoObjects()
	end,
	'undo','ctrl','z')

	self:addKeybind(function()
		self.cmd:redo()
		self:resetLoads()
		self:rebuildDecoObjects()
	end,
	'redo','ctrl','y')
	
	self:addKeybind(function()
		self.copiedEvents = helpers.copy(self.selectedEvents)
	end,'copy selected','ctrl','c')
	self:addKeybind(function()
		local sourceEvents = self:getEList(self.copiedEvents)
		if #sourceEvents == 0 then
			print('paste what events?')
			return
		end
		
		local events = {}
		for i, ev in ipairs(sourceEvents) do
			events[i] = helpers.copy(ev)
		end
		
		local smallestTime = math.huge
		for i, ev in ipairs(events) do
			if ev.time < smallestTime then
				smallestTime = ev.time
			end
		end
		local beatDiff = self.editorBeat - smallestTime
		for i, ev in ipairs(events) do
			ev.time = ev.time + beatDiff
		end
		
		if #events > 1 then
			self.cmd:startGroup()
			self.cmd:executeNew(cmd.CreateMultiple, events)
			self.cmd:endGroup("Pasted "..#events.." events")
		else
			self.cmd:executeNew(cmd.CreateEvent, events[1])
		end
		
		local pasteType = self.copiedEvents.type
		local newSelection = { type = pasteType, events = {} }
		if pasteType == 'keyframe' then
			local wanted = {}
			for _, ev in ipairs(events) do
				wanted[ev.type] = wanted[ev.type] or {}
				wanted[ev.type][ev.id] = wanted[ev.type][ev.id] or {}
				wanted[ev.type][ev.id][ev.time] = (wanted[ev.type][ev.id][ev.time] or 0) + 1
			end
			for eType, byId in pairs(wanted) do
				for eId, byTime in pairs(byId) do
					self:resetDecoEvents(eType, eId)
					
					local deco = self.decos[eType .. ":" .. eId]
					if deco then
						for _, dEv in ipairs(deco.events) do
							local count = byTime[dEv.time]
							if count and count > 0 then
								newSelection.events[dEv] = true
								byTime[dEv.time] = count - 1
							end
						end
					end
				end
			end
		elseif pasteType == 'marker' then
			self:resetMarkers()
			
			local wanted = {}
			for _, ev in ipairs(events) do
				wanted[ev.type] = wanted[ev.type] or {}
				wanted[ev.type][ev.time] = (wanted[ev.type][ev.time] or 0) + 1
			end
			for _, m in ipairs(self.markers) do
				local byTime = wanted[m.type]
				local count = byTime and byTime[m.time]
				if count and count > 0 then
					newSelection.events[m] = true
					byTime[m.time] = count - 1
				end
			end
		end
		self.selectedEvents = newSelection
	end,'paste selected','ctrl','v')
	
	self:addKeybind(function() 
		self.rateMod = math.max(self.rateMod - 0.1, 0.25) 
		if self.source and self.isPlaying then
			self.source:setPitch(self.rateMod)
		end
	end, 'speedmod DOWN', 'shift', 'leftbracket')
	self:addKeybind(function() 
		self.rateMod = math.min(self.rateMod + 0.1, 2)
		if self.source and self.isPlaying then
			self.source:setPitch(self.rateMod)
		end
	end, 'speedmod UP', 'shift', 'rightbracket' )
	
	self:addKeybind(function()
		self:confirmEdit()
	end,
	'confirm edit','enter')
	
	self:rebuildDecoObjects()
end)

function st:commitDragTimes()
	if not self.dragStartTimes then return end
	
	local changed = {}
	for ev, startTime in pairs(self.dragStartTimes) do
		if ev.time ~= startTime then
			changed[#changed + 1] = { ev = ev, newTime = ev.time }
			ev.time = startTime
		end
	end
	
	if #changed > 0 then
		if #changed > 1 then
			self.cmd:startGroup()
			for _, c in ipairs(changed) do
				self.cmd:executeNew(cmd.ModifyKeys, c.ev, { time = c.newTime })
			end
			self.cmd:endGroup("Moved "..#changed.." events")
		else
			self.cmd:executeNew(cmd.ModifyKeys, changed[1].ev, { time = changed[1].newTime })
		end
		
		for _, r in ipairs(self.timelineRows) do
			table.sort(r.events, eventSort)
		end
		table.sort(self.markers, eventSort)
	end
	
	self.dragStartTimes = nil
end

function st:confirmEdit() -- i honestly don't know if i actually want to do multiselect
	if self.editMode == "none" then return end
	
	self.editMode = "none"
	self.lockedAxis = "none"
	shuv.usePalette = self.editInfo.shuvState
	local properties = {'x', 'y', 'z', 'r', 'sx', 'sy', 'sz'}
	local changes = {}
	for _, v in ipairs(properties) do
		if self.editInfo[v] then
			changes[v] = self.editInfo[v]
		end
	end
	self.cmd:executeNew(cmd.ModifyKeys, self.editInfo.eventRef, changes)
	--bbp.utils.printTable(self.editInfo.eventRef)
end

function st:resetMarkers()
	self.gm:resetLevel()
	self.markers = {}
	self.markersByType = {}
	self.timingInfo.timingPoints = {}
	
	for _, v in ipairs(self.level.events) do
		if self.markerColors[v.type] then
			table.insert(self.markers, v)
			
			if loadTheseMarkers[v.type] then
				if Event.onLoad[v.type](v) then
					self.drawDecos = false
				end
			end
			if v.type == 'play' then
				self.timingInfo.initial = {bpm = v.bpm, timeOffsetSeconds = v.offset, beatOffset = v.time}
			elseif v.type == 'setBPM' then
				table.insert(self.timingInfo.timingPoints, {beat = v.time, bpm = v.bpm or 100})
			end
		end
	end
	
	table.sort(self.markers, eventSort)
	table.sort(self.timingInfo.timingPoints, function(a, b) return a.beat < b.beat end)
	for _, m in ipairs(self.markers) do
		if not self.markersByType[m.type] then
			self.markersByType[m.type] = {}
		end
		table.insert(self.markersByType[m.type], m)
	end
end

function st:resetDecos()
	self.decos = {}
	
	local index = 0
	for _, v in ipairs(self.level.events) do
		index = index + 1
		
		if v.type == "deco" or v.type == "textdeco" then
			if Event.onLoad[v.type](v) then
				self.drawDecos = false
			end
			if v.type == "textdeco" then
				v.text = v.textString
			end
			
			local key = v.type .. ":" .. v.id
			if not self.decos[key] then
				self.decos[key] = { order = index, events = {}, kind = v.type, id = v.id }
			end
			table.insert(self.decos[key].events, v)
			table.sort(self.decos[key].events, eventSort)
		end
	end
	
	self.rowsDirty = true
end

function st:resetDecoEvents(decoType, decoId)
	local key = decoType .. ":" .. decoId
	local events = {}
	local firstIndex = nil
	
	for i, v in ipairs(self.level.events) do
		if v.type == decoType and v.id == decoId then
			if Event.onLoad[v.type](v) then
				self.drawDecos = false
			end
			if v.type == "textdeco" then
				v.text = v.textString
			end
			
			table.insert(events, v)
			firstIndex = firstIndex or i
		end
	end
	
	if #events == 0 then
		self.decos[key] = nil
		self.rowsDirty = true
		return
	end
	
	table.sort(events, eventSort)
	
	self.decos[key] = self.decos[key] or { order = firstIndex, kind = decoType, id = decoId }
	self.decos[key].events = events
	
	self.rowsDirty = true
end

function st:resetLoads()
	self:resetMarkers()
	self:resetDecos()
	self:updateCanvs()
end

function st:rebuildTimelineRows()
	local rows = {}
	for id, deco in pairs(self.decos) do
		rows[#rows + 1] = { key = id, id = deco.id, kind = deco.kind, order = deco.order or 0, events = deco.events or {} }
	end
	table.sort(rows, function(a, b) return a.order < b.order end)
	self.timelineRows = rows
	self.rowsDirty = false
end

function st:addKeybind(func, name, k1, k2, k3)
	table.insert(self.keybinds, { func = func, name = name, k1 = k1, k2 = k2, k3 = k3 })
end

function st:checkKeybinds()
	for i, v in ipairs(self.keybinds) do
		if v.k1 and v.k2 and v.k3 then
			if maininput:down(v.k1) and maininput:down(v.k2) and maininput:pressed(v.k3) then
				log('pressed keybind ' .. v.name,'editor')
				v.func()
			end
		elseif v.k1 and v.k2 then
			if maininput:down(v.k1) and maininput:pressed(v.k2) then
				log('pressed keybind ' .. v.name,'editor')
				v.func()
			end
		else
			if maininput:pressed(v.k1) then
				log('pressed keybind ' .. v.name,'editor')
				v.func()
			end
		end
	end
end

function st:leave()
	em.clear()
	self.gm:stopLevel()
	self.gm:resetLevel()
	
	if self.source and self.source.isPlaying then
		self.source:stop()
	end
	
	if savedata.options.game.customCursorInMenu and (savedata.options.game.cursorMode ~= "default") then
		love.mouse.setVisible(false)
	end
	mouse.hidden = false
	cs = bs.load("Editor")
	cs:init()
end

function st:getBeatSnapValue()
	return self.beatSnapValues[self.beatSnap] or self.customBeatSnap
end

function st:getBeatStep()
	local beatStep = 1
	if self.beatSnap ~= 0 then
		local snapValue = self:getBeatSnapValue()
		beatStep = 1 / snapValue
	end
	return beatStep
end

function st:getAngleSnapValue()
	return 16
end
function st:getAngleSnapValue()
	return 360/16
end

function st:deleteSelectedEvents()
	local list = self:getEList(self.selectedEvents)
	if #list > 0 then
		if #list > 1 then
			self.cmd:startGroup()
			self.cmd:executeNew(cmd.RemoveMultiple, list)
			self.cmd:endGroup("Deleted "..#list.." events")
		else
			self.cmd:executeNew(cmd.RemoveEvent, list[1])
		end
		
		self:clearSelection()
		self:resetLoads()
	else
		print("nothing selected?")
	end
end
function st:clearSelection()
	self.selectedEvents = { type = nil, events = {} }
end
function st:selectSingle(kind, obj)
	self.selectedEvents = { type = kind, events = { [obj] = true } }
end
function st:addSelect(kind, obj) -- im not actually sure why i seperated markers and keyframes in select
	if self.selectedEvents.type == nil then
		self.selectedEvents.type = kind
	end
	if kind ~= self.selectedEvents.type then
		print('mismatch selection kinds')
		return
	end
	self.selectedEvents.events[obj] = true
end
function st:isSelected(kind, obj)
	return self.selectedEvents.type == kind and self.selectedEvents.events[obj] == true
end
function st:getSelectedFromGroup(kind, group)
	for _, ev in ipairs(group) do
		if self:isSelected(kind, ev) then
			return ev
		end
	end
	return nil
end
function st:getFirstOfEList(list)
	local obj = next(list.events)
	return obj, list.type
end
function st:getEList(list)
	local out = {}
	for obj in pairs(list.events) do
		out[#out + 1] = obj
	end
	return out
end
function st:getEListCount(list)
	local count = 0
	for _ in pairs(list.events) do
		count = count + 1
	end
	return count
end

function st:clearMultiselectVars()
	self:clearSelection()
end

function st:playbackError(message)
	if not self.errorDialogue then
		log('Playback error: '..message,'error')
		self.errorDialogue = true		
		self.errorMessage = message
		self.errorHeader = "An error has occured during playback."
		self.isPlaying = false
		if self.source then
			self.source:stop()
		end
	end
end

function st:getRetimeOffset(beat)
	local offset = 0
	local retimes = self.markersByType.retime
	if not retimes then return offset end
	for _, m in ipairs(retimes) do
		if beat > m.time then
			offset = offset + m.offset
		end
	end
	return offset
end

function st:getBPMAtBeat(beat)
	local bpm = self.baseBpm or 100
	local bestTime = -math.huge
	
	local function scan(list)
		if not list then return end
		for _, m in ipairs(list) do
			if m.bpm and m.time <= beat then
				if m.time > bestTime then
					bestTime = m.time
					bpm = m.bpm
				end
			end
		end
	end
	scan(self.markersByType.play)
	scan(self.markersByType.setBPM)
	
	if self.rateMod then
		bpm = bpm * self.rateMod
	end
	return bpm
end

function st:setOutline()
	local bestTime = -math.huge
	local outlines = self.markersByType.outline
	if not outlines then return end
	for _, m in ipairs(outlines) do
		if m.time <= self.editorBeat then
			if m.time > bestTime then
				if m.enable == false then
					self.outline = nil
				else
					self.outline = m.color
				end
			end
		end
	end
end

function st:setBGColor()
	local color = 0
	local vcolor = nil
	local bestTime = -math.huge
	local bgColors = self.markersByType.setBgColor
	if bgColors then
		for _, m in ipairs(bgColors) do
			if m.time <= self.editorBeat then
				if m.time > bestTime then
					bestTime = m.time
					color = m.color
					vcolor = m.voidColor
				end
			end
		end
	end
	self.bgColor = color
	self.voidColor = vcolor or self.voidColor
end

function st:updateCanvs()
	self:updateStamps()
	self:updateAfts()
end

function st:updateStamps()
	local stamps = self.markersByType.stamp
	if not stamps then return end
	
	if self.editorBeat < (self.lastEditorBeat) - 0.0001 then
		for _, canv in pairs(self.vfx.stampCanvases) do
			canv:renderTo(function() love.graphics.clear() end)
		end
	end
	
	for _, m in ipairs(stamps) do
		if m.time > self.lastEditorBeat and m.time <= self.editorBeat then
			Event.onBeat.stamp(m)
		end
	end
end

function st:updateAfts()
	local afts = self.markersByType.aft
	if not afts then return end
	
	if self.editorBeat < (self.lastEditorBeat) - 0.0001 then
		for _, canv in pairs(self.vfx.aft) do
			canv.canvas:renderTo(function() love.graphics.clear() end)
		end
	end
	
	for _, m in ipairs(afts) do
		if m.time > self.lastEditorBeat and m.time <= self.editorBeat then
			Event.onBeat.aft(m)
		end
	end
end

function st:updatePlayer()
	if not self.p then
		return
	end
	local numPaddles = #self.p.paddles
	
	local paddleEvents = {}
	local easeEvents = {}
	local paddleMarkers = self.markersByType.paddles
	if paddleMarkers then
		for _, m in ipairs(paddleMarkers) do
			if m.time <= self.editorBeat then
				table.insert(paddleEvents, m)
			end
		end
	end
	local easeMarkers = self.markersByType.ease
	if easeMarkers then
		for _, m in ipairs(easeMarkers) do
			if m.time <= self.editorBeat and m.var:sub(1,2) == 'p.' then
				table.insert(easeEvents, m)
			end
		end
	end
	
	for i = 1, numPaddles do
		local paddle = self.p.paddles[i]
		for _, e in ipairs(paddleEvents) do
			if e.enabled ~= nil then
				local paddleStart, paddleEnd = e.paddle, e.paddle
				if e.paddle == 0 then
					paddleStart, paddleEnd = 1, numPaddles
				end
				if i >= paddleStart and i <= paddleEnd then
					paddle.enabled = e.enabled
				end
			end
		end
		
		for _, prop in ipairs({ { key = 'newAngle', field = 'baseAngle' }, { key = 'newWidth', field = 'paddleSize' } }) do
			local proppaddleEvents = {}
			for _, e in ipairs(paddleEvents) do
				if e[prop.key] ~= nil then
					local paddleStart, paddleEnd = e.paddle, e.paddle
					if e.paddle == 0 then
						paddleStart, paddleEnd = 1, numPaddles
					end
					if i >= paddleStart and i <= paddleEnd then
						table.insert(proppaddleEvents, e)
					end
				end
			end
			
			if #proppaddleEvents > 0 then
				local base = paddle[prop.field] or 0
				for j = 1, #proppaddleEvents - 1 do
					base = proppaddleEvents[j][prop.key]
				end

				local e = proppaddleEvents[#proppaddleEvents]
				local target = e[prop.key]
				local ease = e.ease or 'linear'
				local duration = e.duration or 0
				local t = (duration > 0)
					and helpers.clamp((self.editorBeat - e.time) / duration, 0, 1)
					or 1

				paddle[prop.field] = helpers.interpolate(base, target, t, ease)
			end
		end
		
		local heightpaddleEvents = {}
		for _, e in ipairs(paddleEvents) do
			if e.newHeight ~= nil then
				table.insert(heightpaddleEvents, e)
			end
		end
		if #heightpaddleEvents > 0 then
			local base = paddle.paddleWidth or 0
			for j = 1, #heightpaddleEvents - 1 do
				base = heightpaddleEvents[j].newHeight
			end
			
			local e = heightpaddleEvents[#heightpaddleEvents]
			local target = e.newHeight
			local ease = e.ease or 'linear'
			local duration = e.duration or 0
			local t = (duration > 0)
				and helpers.clamp((self.editorBeat - e.time) / duration, 0, 1)
				or 1
			
			paddle.paddleWidth = helpers.interpolate(base, target, t, ease)
		end
	end
	
	local function resolveEaseTarget(var)
		local varSplit = self.easeVarSplitCache[var]
		if varSplit == nil then
			local parts = {}
			local valid = true
			for v in string.gmatch(var, "([^.]+)") do
				if tonumber(v) then
					valid = false
					break
				end
				table.insert(parts, v)
			end
			if not valid or #parts < 2 then
				varSplit = false
			else
				varSplit = parts
			end
			self.easeVarSplitCache[var] = varSplit
		end
		
		if not varSplit then
			return nil, nil
		end
		
		local target = self
		for i = 1, #varSplit - 1 do
			local key = varSplit[i]
			if type(target) ~= 'table' or target[key] == nil then
				return nil, nil
			end
			target = target[key]
		end
		local field = varSplit[#varSplit]
		if type(target) ~= 'table' or type(target[field]) ~= 'number' then
			return nil, nil
		end
		return target, field
	end
	
	local instances = {}
	for _, e in ipairs(easeEvents) do
		if e.mode ~= 'setRandom' and e.mode ~= 'addRandom' then
			local repeats = e.repeats or 0
			local repeatDelay = e.repeatDelay or 1
			for r = 0, repeats do
				local t = e.time + r * repeatDelay
				if t <= self.editorBeat then
					table.insert(instances, {
						time = t, order = e.order, var = e.var, mode = e.mode,
						start = e.start, value = e.value,
						duration = e.duration, ease = e.ease,
					})
				end
			end
		end
	end
	table.sort(instances, function(a, b)
		if a.time == b.time then
			return (a.order or 0) < (b.order or 0)
		end
		return a.time < b.time
	end)
	
	local groups, groupOrder = {}, {}
	for _, inst in ipairs(instances) do
		local target, field = resolveEaseTarget(inst.var)
		if target then
			if not groups[inst.var] then
				groups[inst.var] = { target = target, field = field, events = {} }
				table.insert(groupOrder, inst.var)
			end
			table.insert(groups[inst.var].events, inst)
		end
	end
	
	for _, key in ipairs(groupOrder) do
		local group = groups[key]
		local events = group.events
		local target, field = group.target, group.field
		
		local base = target[field] or 0
		for j = 1, #events - 1 do
			local ev = events[j]
			base = (ev.mode == 'add') and (base + (ev.value or 0)) or (ev.value or base)
		end
		
		local e = events[#events]
		local startVal = e.start or base
		local endVal = (e.mode == 'add') and (startVal + (e.value or 0)) or (e.value or startVal)
		local ease = e.ease or 'linear'
		local duration = e.duration or 0
		local t = (duration > 0)
			and helpers.clamp((self.editorBeat - e.time) / duration, 0, 1)
			or 1
		
		target[field] = helpers.interpolate(startVal, endVal, t, ease)
	end
	
	self.p._actualX, self.p._actualY = self.p.x, self.p.y
end

function st:updateColorPalette()
	shuv.resetPal()
	
	local byIndex = {}
	if self.markersByType.setColor then
		for _, m in ipairs(self.markersByType.setColor) do
			local idx = m.color or 0
			byIndex[idx] = byIndex[idx] or {}
			table.insert(byIndex[idx], m)
		end
	end
	
	for idx = 0, 7 do
		local events = byIndex[idx]
		if events then
			for _, channel in ipairs({'r', 'g', 'b'}) do
				local propEvents = {}
				for _, e in ipairs(events) do
					if e[channel] ~= nil and e.time <= self.editorBeat then
						table.insert(propEvents, e)
					end
				end
				
				if #propEvents > 0 then
					local base = 0
					for i = 1, #propEvents - 1 do
						base = propEvents[i][channel]
					end
					
					local e = propEvents[#propEvents]
					local target = e[channel]
					local ease = e.ease or 'linear'
					local duration = e.duration or 0
					local t = (duration > 0)
						and helpers.clamp((self.editorBeat - e.time) / duration, 0, 1)
						or 1
					
					shuv.pal[idx][channel] = helpers.interpolate(base, target, t, ease)
				end
			end
		end
	end
end

function st:rebuildDecoObjects()
	local oldp_actualX = self.p._actualX
	local oldp_actualY = self.p._actualY
	em.clear()
	self.p = em.init('Player')
	self.p._actualX = oldp_actualX
	self.p._actualY = oldp_actualY
	self.decoObjects = {}
	self.vfx.deco = {} 
	self.vfx.textdeco = {} 
	self.renderDecos = {}
	print("KILLED EVERYTHING")
	--print(self.gm)
	--print(self.cmd)
	-- i wonder why gm is still here along with cmd
	-- oh well
end

st:setUpdate(function(self, dt)
	self:updateColorPalette()
	self:setBGColor()
	self:setOutline()
	
	self.p.x = 300
	self.p.y = 180
	self:updatePlayer()
	self.p.x = self.p._actualX - self.pan[1]
	self.p.y = self.p._actualY - self.pan[2]
	
	if self.editorBeat < (self.lastEditorBeat or self.editorBeat) - 0.0001 then
		self:updateCanvs()
		self:rebuildDecoObjects()
	end
	self.lastEditorBeat = self.editorBeat
	
	if self.isPlaying then
		self.level.bpm = self:getBPMAtBeat(self.editorBeat)
		if self.source then
			self.source:update(dt)
			self.editorBeat = self.source:getBeat() + self:getRetimeOffset(self.source:getBeat())
		else
			self.unchangedEditorBeat = self.unchangedEditorBeat + (self.level.bpm/60) * love.timer.getDelta()
			self.editorBeat = self.unchangedEditorBeat + self:getRetimeOffset(self.unchangedEditorBeat)
		end
		self.cBeat = self.editorBeat
		self.timelineScroll = self.editorBeat - 50/self.beatSize
		
		self:updateCanvs()
		for _, v in pairs(self.decoObjects) do
			v:update(dt)
		end
	end
	
	if not imgui.love.GetWantCaptureMouse() then
		if maininput:pressed("mouse3") and not self.isPanning then
			self.isPanning = true
			self.mouseStartX = mouse.rx + self.pan[1]
			self.mouseStartY = mouse.ry + self.pan[2]
		end
		if maininput:down("mouse3") and self.isPanning then
			self.pan[1] = self.mouseStartX - mouse.rx
			self.pan[2] = self.mouseStartY - mouse.ry
		end
		if maininput:released("mouse3") and self.isPanning then
			self.isPanning = false
			self.mouseStartX = nil
			self.mouseStartY = nil
		end
	end
	
	if self.placeEvent ~= '' and Event.info[self.placeEvent] then
		local ev = { type = self.placeEvent, time = self.editorBeat, angle = 0 }
		if self.decoTypes[self.placeEvent] then
			local id = 'deco'
			local n = 0
			while self.decos[self.placeEvent .. ':' .. id] do
				n = n + 1
				id = 'deco' .. n
			end
			ev.id = id
		end
		self.cmd:executeNew(cmd.CreateEvent, ev)
		
		local isMarker = self.markerColors[ev.type] ~= nil
		if isMarker then
			self:resetMarkers()
		else
			self:resetDecoEvents(ev.type, ev.id)
		end
		
		self:selectSingle(isMarker and 'marker' or 'keyframe', ev)
		self.placeEvent = ''
	elseif self.placeEvent ~= '' then
		local ev = nil
		for i, v in ipairs(self.pEventDecoders) do
			local success, result = pcall(v, self.placeEvent)
			if success then
				ev = result
			end
		end
		if type(ev) == 'table' and Event.info[ev.type] then
			self.cmd:executeNew(cmd.CreateEvent, ev)
			-- i dont expect it not to be a marker, but better safe than sorry
			local isMarker = self.markerColors[ev.type] ~= nil
			if isMarker then
				self:resetMarkers()
			else
				self:resetDecoEvents(ev.type, ev.id)
			end
			
			self:selectSingle(isMarker and 'marker' or 'keyframe', ev)
		end
		
		self.placeEvent = ''
	end
	
	if self.editMode ~= "none" and maininput:pressed('mouse1') then
		self:confirmEdit()
	end
	
	if not imgui.love.GetWantTextInput() then
		self:checkKeybinds()
	end
	
end)

function st:setModMenuEnabled(k, name, value)
	self.enabledModEMenus[k] = self.enabledModEMenus[k] or {}
	if self.enabledModEMenus[k][name] ~= value then
		self.enabledModEMenus[k][name] = value
		keyedConfig.enabledModEMenus = self.enabledModEMenus
		bbp.utils.saveConfig("keyed")
	end
end

function st:imgui()
	local inputFlag = nil
	local window_flag = 'ImGuiCond_FirstUseEver'
	if self.resetwindows then
		window_flag = 'ImGuiCond_Always'
		self.resetwindows = false
	end
	
	for k, menus in pairs(self.enabledModEMenus) do
		for name, enabled in pairs(menus) do
			if enabled then
				local chunk = self.loadedModEMenus[k] and self.loadedModEMenus[k][name]
				if chunk then
					local ok, err = pcall(chunk, window_flag, inputFlag)
					if not ok then
						print("failed to run", k, name, err)
					end
				elseif mods[k] and mods[k].enabled then
					print("no loaded chunk for", k, name, "???")
				end
			end
		end
	end
	
	helpers.SetNextWindowPos(950, 50, window_flag)
	helpers.SetNextWindowSize(250, 450, window_flag)
	imgui.Begin("Event Editor##keyframer",nil,inputFlag) -- todo: make thses use cmd.ModifyKeys
		local selectedCount = self:getEListCount(self.selectedEvents)
		if selectedCount > 1 then
			
		elseif selectedCount == 1 then
			local selectedEvent = self:getFirstOfEList(self.selectedEvents)
			imgui.Text("Editing " .. Event.info[selectedEvent.type].name)
			
			imgui.Separator()
			if not (selectedEvent.type == 'play') then
				local reloadOnChange = {
					'id',
					'text', -- for some reason it doesn't change the actual deco
					'order', -- i think thats it?
				}
				local old = helpers.copy(selectedEvent)
				
				local beatStep = 0.01
				if self.beatSnap ~= 0 then
					beatStep = 1 / self:getBeatSnapValue()
				end
				Event.property(selectedEvent, 'decimal', 'time', 'Beat to activate on', { step = beatStep })
				Event.property(selectedEvent, 'decimal', 'angle', 'Angle to activate at', { step = 1 })
				if self.variant and (not Event.info[selectedEvent.type].storeInChart) and (not Event.info[selectedEvent.type].hideVariant) then
					Event.property(selectedEvent, 'enum', 'variant', 'Make this event specific to a variant', {enum = 'variants', optional = true, default = self.variant.name})
				end
				if (not Event.info[selectedEvent.type].hideOrder) then
					Event.property(selectedEvent, 'int', 'order', 'Order to run on, lower = first', { optional = true, default = 0 })
				end
				if Event.editorProperties[selectedEvent.type] then
					Event.editorProperties[selectedEvent.type](selectedEvent)
				end
				imgui.Separator()
				
				for _, v in ipairs(reloadOnChange) do
					if old[v] ~= selectedEvent[v] and not (v == 'id' and selectedEvent[v] == '') then
						self:resetLoads()
					end
				end
				
				if imgui.Button('Delete event') then
					self:deleteSelectedEvents()
				end
			else
				imgui.Text("No.")
			end
		else
			imgui.Text("Select an event to edit it")
		end
		
	imgui.End()
	
	helpers.SetNextWindowPos(0, 50, window_flag)
	helpers.SetNextWindowSize(250, 450, window_flag)
	imgui.Begin("Event Palette ##keyframer",nil,inputFlag)
		imgui.Text("Search:")
		imgui.SameLine()
		self.paletteSearch = helpers.InputText("##paletteSearch", self.paletteSearch or '', 9999)
		
		local size =  imgui.GetContentRegionAvail()
		if imgui.BeginListBox("##palette", size) then
			self.placeEvent = helpers.BuildTree(self.eventPalette, self.placeEvent or '', self.paletteSearch)
		end
	imgui.End()
	
	helpers.SetNextWindowPos(470, 500, window_flag)
	helpers.SetNextWindowSize(730, 220, window_flag)
	imgui.Begin("Timeline ##keyframer",nil,inputFlag)
		local drawlist = imgui.GetWindowDrawList()
		
		local function snapBeat(b)
			local subdiv = self:getBeatSnapValue() or 1
			return math.floor(b * subdiv + 0.5) / subdiv
		end
		local function clampedSnap(b)
			return math.max(-8, snapBeat(math.max(-8, b)))
		end
		
		local function line(x1, y1, x2, y2, c, w)
			drawlist:AddLine({x1, y1}, {x2, y2}, c, w)
		end
		local function rect(x, y, w, h, c)
			drawlist:AddRectFilled({x, y}, {x + w, y + h}, c)
		end
		local function text(x, y, c, t)
			drawlist:AddText_Vec2({x, y}, c, t)
		end
		local function quad(x1, y1, x2, y2, x3, y3, x4, y4, c)
			drawlist:AddQuadFilled({x1, y1}, {x2, y2}, {x3, y3}, {x4, y4}, c)
		end
		local function triangle(x1, y1, x2, y2, x3, y3, c)
			drawlist:AddTriangleFilled({x1, y1}, {x2, y2}, {x3, y3}, c)
		end
		
		local winpos = imgui.GetWindowPos()
		local avail = imgui.GetContentRegionAvail()
		local cursor = imgui.GetCursorScreenPos()
		local rulerH = 24
		local labelW = 120
		local rowH = 24
		local trackX = cursor.x + labelW
		local trackAreaW = avail.x - labelW
		local tracky = cursor.y + rulerH
		
		local scroll = self.timelineScroll
		local rowScroll = self.timelineRowScroll
		
		local bottomY = cursor.y + avail.y
		local visible_rows = math.floor((avail.y - rulerH) / rowH)
		local diamondSize = 6
		
		local beatSize = self.beatSize
		local function beatToX(b) -- maybe this should go to the top of constant things that get made every frame
			return trackX + (b - scroll) * beatSize
		end
		local function xToBeat(x)
			return (x - trackX) / beatSize + scroll
		end
		local function clusterEvents(items, threshold)
			threshold = threshold or 3
			local sorted = {}
			for _, ev in ipairs(items) do table.insert(sorted, ev) end
			table.sort(sorted, function(a, b) return a.time < b.time end)
			
			local groups = {}
			local currentGroup, lastX = nil, nil
			for _, ev in ipairs(sorted) do
				local x = beatToX(ev.time)
				if currentGroup and lastX and (x - lastX) <= threshold then
					table.insert(currentGroup, ev)
				else
					currentGroup = { ev }
					table.insert(groups, currentGroup)
				end
				lastX = x
			end
			return groups
		end
		
		local function findClusterContaining(clusters, item)
			for _, group in ipairs(clusters) do
				for _, ev in ipairs(group) do
					if ev == item then return group end
				end
			end
			return nil
		end
		
		-- we are back to imgui, because i dont like above imgui
		
		--[[
		order:
		background
		alt BGC
		girdlines
		ruler ticks
		markers
		keydframes
		playhead
		]]
		
		-- rows only need to be rebuilt when self.decos actually changes
		-- (see resetDecos/resetDecoEvents setting self.rowsDirty), not on
		-- every single frame this window is drawn.
		if self.rowsDirty then
			self:rebuildTimelineRows()
		end
		local rows = self.timelineRows
		
		local total_rows_h = math.max(avail.y - rulerH, #rows * rowH)
		
		local first_beat = math.max(-8, math.floor(scroll))
		local last_beat = math.ceil(scroll + trackAreaW / beatSize)
		
		rect(cursor.x, cursor.y, avail.x, avail.y, BGC)
		rect(cursor.x, tracky, labelW, avail.y, labelBGC)
		
		
		for i, row in ipairs(rows) do
			local row_index = i - 1 - rowScroll
			if row_index >= 0 and row_index < visible_rows then
				local ry = tracky + row_index * rowH
				
				if i % 2 == 0 then
					rect(cursor.x, ry, avail.x, rowH, rowAltC)
				end
				
				line(cursor.x, ry + rowH, cursor.x + avail.x, ry + rowH, lineC, 1)
				text(cursor.x + 8, ry + rowH / 2 - 7, textC, row.id .. (row.kind == "textdeco" and " [text]" or " [norm]"))
			end
		end
		
		
		for b = first_beat, last_beat do
			local x = beatToX(b)
			if x >= trackX and x <= trackX + trackAreaW then
				line(x, tracky, x, cursor.y + avail.y, lineC, 1)
			end
		end
		
		
		for b = first_beat, last_beat do
			local x = beatToX(b)
			if x >= trackX and x <= trackX + trackAreaW then
				line(x, cursor.y, x, cursor.y + rulerH, lineHiC, 1)
				text(x + 3, cursor.y + 2, textC, string.format("%db", b))
				if beatSize > 40 then
					for q = 1, self:getBeatSnapValue() do
						local qx = beatToX(b + q * 1/self:getBeatSnapValue())
						if qx >= trackX and qx <= trackX + trackAreaW then
							line(qx, cursor.y + rulerH * 0.6, qx, cursor.y + rulerH, lineC, 1)
						end
					end
				end
			end
		end
		
		local markerClusters = clusterEvents(self.markers, 3)
		
		for _, group in ipairs(markerClusters) do
			local xSum = 0
			for _, m in ipairs(group) do xSum = xSum + beatToX(m.time) end
			local x = xSum / #group
			
			if x >= trackX - diamondSize and x <= trackX + trackAreaW + diamondSize then
				local selectedInGroup = #group > 1 and self:getSelectedFromGroup("marker", group)
				if selectedInGroup then
					group = { selectedInGroup }
				end
				if #group == 1 then
					local m = group[1]
					local mc = self.markerColors[m.type] or 0xFFFFFFFF
					local sel = self:isSelected("marker", m)
					local c = sel and keySelC or mc
					line(x, tracky, x, bottomY, c, sel and 2 or 1)
					triangle(x - 6, bottomY, x + 6, bottomY, x, bottomY - 8, c)
					
					local t = m.name or m.var or m.type
					if t == '' then t = m.type end
					text(x + 8, bottomY - 14, c, t)
					if m.duration then
						line(x, bottomY, beatToX(m.time + (m.duration or 0)), bottomY, c, 2)
					end
				else
					local sel = false
					for _, m in ipairs(group) do
						if self:isSelected("marker", m) then sel = true; break end
					end
					local c = sel and keySelC or 0xFFFFFFFF
					line(x, tracky, x, bottomY, c, sel and 2 or 1)
					triangle(x - 6, bottomY, x + 6, bottomY, x, bottomY - 8, c)
					text(x + 8, bottomY - 14, c, #group .. ' events')
				end
			end
		end
		
		for i, row in ipairs(rows) do
			local row_index = i - 1 - rowScroll
			if row_index >= 0 and row_index < visible_rows then
				local ry = tracky + row_index * rowH
				local y = ry + rowH / 2
				
				local rowClusters = clusterEvents(row.events, 3)
				
				for _, group in ipairs(rowClusters) do
					local xSum = 0
					for _, ev in ipairs(group) do xSum = xSum + beatToX(ev.time) end
					local x = xSum / #group
					
					if x >= trackX - diamondSize and x <= trackX + trackAreaW + diamondSize then
						local selectedInGroup = #group > 1 and self:getSelectedFromGroup("keyframe", group)
						if selectedInGroup then
							group = { selectedInGroup }
						end
						if #group == 1 then
							local ev = group[1]
							local endX = beatToX(ev.time + (ev.duration or 0))
							local c = self:isSelected("keyframe", ev) and keySelC or keyC
							line(x, y, endX, y, c, 2)
							quad(x, y - diamondSize, x + diamondSize, y, x, y + diamondSize, x - diamondSize, y, c)
						else
							local sel, endX = false, x
							for _, ev in ipairs(group) do
								if self:isSelected("keyframe", ev) then sel = true end
								endX = math.max(endX, beatToX(ev.time + (ev.duration or 0)))
							end
							local c = sel and keySelC or keyC
							if endX > x then
								line(x, y, endX, y, c, 2)
							end
							quad(x, y - diamondSize, x + diamondSize, y, x, y + diamondSize, x - diamondSize, y, c)
							text(x - 3, y - 6, textC, tostring(#group))
						end
					end
				end
			end
		end
		
		
		line(trackX, cursor.y, trackX, cursor.y + avail.y, lineHiC, 1)
		local px = beatToX(self.editorBeat)
		if px >= trackX and px <= trackX + trackAreaW then
			line(px, cursor.y, px, cursor.y + avail.y, playC, 2)
			triangle(px - 6, cursor.y, px + 6, cursor.y, px, cursor.y + 8, playC)
		end
		
		if self.selectBoxActive then
			local bx1, bx2 = math.min(self.selectBoxStartX, self.selectBoxEndX), math.max(self.selectBoxStartX, self.selectBoxEndX)
			local by1, by2 = math.min(self.selectBoxStartY, self.selectBoxEndY), math.max(self.selectBoxStartY, self.selectBoxEndY)
			
			rect(bx1, by1, bx2 - bx1, by2 - by1, selBoxFillC)
			line(bx1, by1, bx2, by1, selBoxC, 2) -- i know AddRect exists but :P
			line(bx1, by2, bx2, by2, selBoxC, 2)
			line(bx1, by1, bx1, by2, selBoxC, 2)
			line(bx2, by1, bx2, by2, selBoxC, 2)
		end
		
		-- fuckass controls
		local io = imgui.GetIO()
		imgui.SetCursorScreenPos({cursor.x, cursor.y})
		imgui.InvisibleButton("##timeline_input", {avail.x, avail.y})
		
		if imgui.IsItemActive() then
			local mousePos = imgui.GetMousePos()
			local mx, my = mousePos.x, mousePos.y
			
			local markerZoneTop = bottomY - 16
			local selectFunc = self.selectSingle
			if io.KeyShift and self:getEListCount(self.selectedEvents) ~= 0 then
				selectFunc = self.addSelect
			end
			
			if (my >= markerZoneTop or self.draggingMarker) and mx >= trackX - diamondSize then
				if imgui.IsMouseClicked(0) then
					local clicked_beat = xToBeat(mx)
					local closestMarker, closestDist = nil, diamondSize / beatSize + 0.05
					for _, m in ipairs(self.markers) do
						local d = math.abs(m.time - clicked_beat)
						if d < closestDist then
							closestMarker, closestDist = m, d
						end
					end
					self.draggingMarker = closestMarker
					if closestMarker then
						local markerClusters = clusterEvents(self.markers, 3)
						local group = findClusterContaining(markerClusters, closestMarker) or { closestMarker }
						
						local groupTarget = closestMarker
						if #group > 1 then
							groupTarget = self:getSelectedFromGroup("marker", group)
						end
						
						if #group > 1 and not groupTarget then
							self.draggingMarker = nil
							self.dragStartTimes = nil
							self.overlappingEventsList = group
							self.overlappingEventsType = "marker"
							self.overlappingEventsDialogue = true
						else
							self.draggingMarker = groupTarget
							local alreadyMulti = self:isSelected("marker", groupTarget) and self:getEListCount(self.selectedEvents) > 1
							if not alreadyMulti then
								selectFunc(self, "marker", groupTarget)
							end
							
							self.dragStartTimes = {}
							self.dragAnchorStartTime = groupTarget.time
							for _, ev in ipairs(self:getEList(self.selectedEvents)) do
								self.dragStartTimes[ev] = ev.time
							end
						end
					else
						self:clearSelection()
						self.dragStartTimes = nil
					end
				end
				
				if self.draggingMarker and self.dragStartTimes then
					local newTime = clampedSnap(xToBeat(mx))
					local delta = newTime - self.dragAnchorStartTime
					for ev, startTime in pairs(self.dragStartTimes) do
						ev.time = math.max(-8, startTime + delta)
					end
				end
			elseif my < tracky then
				if mx >= trackX and not self.isPlaying then
					self.editorBeat = clampedSnap(xToBeat(mx))
				end
			elseif mx >= trackX then
				local row_index = math.floor((my - tracky) / rowH) + rowScroll
				local row = rows[row_index + 1]
				
				if imgui.IsMouseClicked(0) and row then
					local clicked_beat = xToBeat(mx)
					local closest, closest_dist = nil, diamondSize / beatSize + 0.05
					for _, ev in ipairs(row.events) do
						local d = math.abs(ev.time - clicked_beat)
						if d < closest_dist then
							closest, closest_dist = ev, d
						end
					end
					if closest then
						local rowClusters = clusterEvents(row.events, 3)
						local group = findClusterContaining(rowClusters, closest) or { closest }
						
						local groupTarget = closest
						if #group > 1 then
							groupTarget = self:getSelectedFromGroup("keyframe", group)
						end
						
						if #group > 1 and not groupTarget then
							self.draggingKey = nil
							self.draggingKeyRow = nil
							self.dragStartTimes = nil
							self.overlappingEventsList = group
							self.overlappingEventsType = "keyframe"
							self.overlappingEventsDialogue = true
						else
							local alreadyMulti = self:isSelected("keyframe", groupTarget) and self:getEListCount(self.selectedEvents) > 1
							if not alreadyMulti then
								selectFunc(self, "keyframe", groupTarget)
							end
							
							self.dragStartTimes = {}
							self.dragAnchorStartTime = groupTarget.time
							for _, ev in ipairs(self:getEList(self.selectedEvents)) do
								self.dragStartTimes[ev] = ev.time
							end
							self.draggingKey = groupTarget
							self.draggingKeyRow = row
						end
					else
						self.draggingKey = nil
						self.draggingKeyRow = nil
						self.dragStartTimes = nil
						self.selectBoxActive = true
						self.selectBoxStartX, self.selectBoxStartY = mx, my
						self.selectBoxEndX, self.selectBoxEndY = mx, my
					end
				end
				if self.draggingKey and imgui.IsMouseDragging(0) and self.dragStartTimes then
					local newTime = clampedSnap(xToBeat(mx))
					local delta = newTime - self.dragAnchorStartTime
					for ev, startTime in pairs(self.dragStartTimes) do
						ev.time = math.max(-8, startTime + delta)
					end
					
					for _, r in ipairs(rows) do
						table.sort(r.events, eventSort)
					end
				elseif self.selectBoxActive and imgui.IsMouseDragging(0) then
					self.selectBoxEndX, self.selectBoxEndY = mx, my
				end
			end
		end
		
		if imgui.IsMouseReleased(0) then
			if self.selectBoxActive then
				local bx1, bx2 = math.min(self.selectBoxStartX, self.selectBoxEndX), math.max(self.selectBoxStartX, self.selectBoxEndX)
				local by1, by2 = math.min(self.selectBoxStartY, self.selectBoxEndY), math.max(self.selectBoxStartY, self.selectBoxEndY)
				local beatMin, beatMax = xToBeat(bx1), xToBeat(bx2)
				
				local boxed = {}
				for i, row in ipairs(rows) do
					local row_index = i - 1 - rowScroll
					if row_index >= 0 and row_index < visible_rows then
						local ry = tracky + row_index * rowH
						if ry + rowH >= by1 and ry <= by2 then
							for _, ev in ipairs(row.events) do
								if ev.time >= beatMin and ev.time <= beatMax then
									table.insert(boxed, ev)
								end
							end
						end
					end
				end
				
				local shiftHeld = maininput:down("shift")
				local canAdd = shiftHeld and self.selectedEvents.type == 'keyframe' and self:getEListCount(self.selectedEvents) > 0
				
				if #boxed > 0 then
					if not canAdd then
						self.selectedEvents = { type = 'keyframe', events = {} }
					end
					for _, ev in ipairs(boxed) do
						self:addSelect('keyframe', ev)
					end
				elseif not shiftHeld then
					self:clearSelection()
				end
				
				self.selectBoxActive = false
			end
			
			self:commitDragTimes()
			self.draggingKey = nil
			self.draggingKeyRow = nil
			self.draggingMarker = nil
		end
		
		if imgui.IsWindowHovered() then
			local wheel = io.MouseWheel or 0
			if wheel ~= 0 then
				if io.KeyCtrl then
					self.beatSize = math.max(10, beatSize + wheel * 10)
				elseif io.KeyShift then
					self.timelineRowScroll = math.max(0, math.min(#rows - visible_rows, rowScroll - wheel))
				else
					self.timelineScroll = math.max(-8, scroll - wheel * 0.5 * (30 / beatSize)^0.75)
				end
			end
		end
	imgui.End()
	
	helpers.SetNextWindowPos(0, 500, window_flag)
	helpers.SetNextWindowSize(250, 220, window_flag)
	imgui.Begin("Settings ##keyframer",nil,inputFlag)
		if imgui.BeginTabBar("##settingsTabs") then
			if imgui.BeginTabItem("Playback") then
				self.rateMod = helpers.SliderFloat('Playback speed (0.25x-2x)',
					self.rateMod, 0.25, 2)
				self.rateMod = math.floor(self.rateMod * 20 + 0.5) / 20
				if imgui.IsItemActive() and self.isPlaying and self.source then
					self.source:setPitch(cs.rateMod)
				end
				
				local beatSnapText = 'None'

				if imgui.Button('-##beatminus') then
					self.beatSnap = self.beatSnap - 1
				end
				imgui.SameLine()
				if imgui.Button('+##beatplus') then
					self.beatSnap = self.beatSnap + 1
				end

				if self.beatSnap == -2 then
					self.beatSnap = #self.beatSnapValues
				elseif self.beatSnap > #self.beatSnapValues then
					self.beatSnap = -1
				end

				if self.beatSnap ~= 0 then
					beatSnapText = '1/' .. self:getBeatSnapValue()
				end

				imgui.SameLine()
				if self.beatSnap == -1 then
					imgui.Text("Beat Snap: 1/")
					imgui.SameLine()
					self.customBeatSnap = helpers.InputInt('##custombeat', self.customBeatSnap)
					self.customBeatSnap = math.max(self.customBeatSnap, 1)
				else
					imgui.Text("Beat Snap: " .. beatSnapText)
				end
				
				imgui.EndTabItem()
			end
			
			if imgui.BeginTabItem("Viewport") then
				imgui.SeparatorText("General")
				shuv.usePalette = helpers.InputBool("Use Palette", shuv.usePalette or false)
				self.gridScale = helpers.InputInt("Grid Size", self.gridScale)
				
				imgui.SeparatorText("Layers")
				self.showOnTop = helpers.InputBool("Show Ontop", self.showOnTop or false)
				-- jesus christ i just wanted some funny draggy thigns now it looks like shit
				local minLayer = helpers.InputBool("Minimum Layer", not not self.minLayer or false)
				if minLayer then
					self.minLayer = self.minLayer or self.savedMinLayer or 0
					--self.minLayer = helpers.InputInt('##minlayerkeyframer', self.minLayer)
					local intRef = ffi.new("int[1]", self.minLayer)
					if imgui.DragInt('##minlayerkeyframer', intRef) then
						self.minLayer = intRef[0] 
					end
				else
					self.savedMinLayer = self.minLayer
					self.minLayer = nil
				end
				
				local maxLayer = helpers.InputBool("Maximum Layer", not not self.maxLayer or false)
				if maxLayer then
					self.maxLayer = self.maxLayer or self.savedMaxLayer or 0
					local intRef = ffi.new("int[1]", self.maxLayer)
					--self.maxLayer = helpers.InputInt('##maxlayerkeyframer', self.maxLayer)
					if imgui.DragInt('##maxlayerkeyframer', intRef) then
						self.maxLayer = intRef[0]
					end
				else
					self.savedMaxLayer = self.maxLayer
					self.maxLayer = nil
				end
				
				imgui.SeparatorText("Canvases")
				-- cs.canvas (canvas objs), cs.vfx.stampCanvases (just a canvas), and thats it
				--[[
				local canvlist = {
					Canvas = {},
					StampCanvs = {}
				}
				canvlist[1] = "Main Canvas"
				for k, _ in pairs(self.canvas) do
					table.insert(canvlist.Canvas, k)
				end
				for k, _ in pairs(self.vfx.stampCanvas) do
					table.insert(canvlist.StampCanvs, k)
				end
				
				imgui.Text("Search:")
				imgui.SameLine()
				self.canvasSearch = helpers.InputText("##canvasSearch", self.canvasSearch or '', 9999)
				
				local size =  imgui.GetContentRegionAvail()
				if imgui.BeginListBox("##palette", size) then
					self.currentCanvas = 
				end]]
				-- need to do some sort of thing like buildTree but for general stuff
				--canvases would be here probably
				
				imgui.EndTabItem()
			end
			
			if imgui.BeginTabItem("Mod Menus") then
				local any = false
				for k, menus in pairs(self.loadedModEMenus) do
					local hasEntries = false
					for _ in pairs(menus) do
						hasEntries = true
						break
					end
					
					if hasEntries then
						any = true
						if imgui.TreeNode_Str(k .. " ##modmenu_tree_" .. k) then
							for name, chunk in pairs(menus) do
								self.enabledModEMenus[k] = self.enabledModEMenus[k] or {}
								local current = self.enabledModEMenus[k][name] or false
								local newVal = helpers.InputBool(name .. " ##modmenu_" .. k .. "_" .. name, current)
								self:setModMenuEnabled(k, name, newVal)
							end
							imgui.TreePop()
						end
					end
				end
				if not any then
					imgui.Text("No mod menus found/known")
				end
				imgui.EndTabItem()
			end
				
			imgui.EndTabBar()
		end
	imgui.End()
	
	if self.overlappingEventsDialogue then
		helpers.SetNextWindowPos(190, 240, window_flag)
		helpers.SetNextWindowSize(240, 240, window_flag)
		self.overlappingEventsDialogue = imgui.Begin("Overlapping events!", true)
			imgui.Text("Select which event to select:")
			imgui.Separator()
			for i, v in ipairs(self.overlappingEventsList) do
				local info = Event.info[v.type]
				local label = info and info.name or v.type
				
				if self.overlappingEventsType == "marker" then
					local t = v.name or v.var or v.color
					if t and t ~= '' then
						label = label .. " (" .. t .. ")"
					end
				elseif v.id then
					label = label .. " [" .. v.id .. "]"
				end
				
				if imgui.Selectable_Bool(label .. "##overlap" .. i) then
					self.overlappingEventsDialogue = false
					
					local selectFunc = self.selectSingle
					if maininput:down("shift") and self:getEListCount(self.selectedEvents) ~= 0 then
						selectFunc = self.addSelect
					end
					selectFunc(self, self.overlappingEventsType, v)
				end
			end
		imgui.End()
	end
	
	if self.errorDialogue then
		helpers.SetNextWindowPos(400, 200, window_flag)
		helpers.SetNextWindowSize(400, 200, window_flag)
		self.errorDialogue = imgui.Begin(self.errorHeader, true)

		imgui.TextWrapped(self.errorMessage)

		if imgui.Button('OK') then
			self.errorDialogue = false
		end
		imgui.End()
	end
	
	local wantsLeave = false
	
	if self.exitDialogue then
		helpers.SetNextWindowPos(490, 310, window_flag)
		helpers.SetNextWindowSize(220, 100, window_flag)
		self.exitDialogue = imgui.Begin("Exit ##keyframer", true)
			imgui.Text("Do you wish to save changes?")
			if imgui.Button("Yes") then
				LevelManager:saveLevel(self.level, cLevel, true, self.variant)
				self:leave()
			end
			imgui.SameLine()
			if imgui.Button("No") then
				wantsLeave = true
			end
		imgui.End()
	end
	
	if wantsLeave then
		self:leave()
	end
end

local instantPropsDeco = {
	drawOrder = true,
	recolor = true,
}
local instantPropsText = {
	drawOrder = true,
	recolor = true,
	colour = true,
	specialcolour = true,
}

function st:updateDecoSprite(deco)
	local sprite = deco.sprite
	local template, animation, frame, speed = nil, nil, nil, nil
	
	if sprite ~= nil and sprite ~= '' and string.sub(sprite, 1, 1) ~= '@' then
		template = sprite:match("([%w/%s]+)[!@#]")
		animation = sprite:match("!(%w+)")
		frame = sprite:match("#(%w+)")
		speed = sprite:match("@(%w+)")
		
		if speed and (not animation) then
			animation = 'all'
		end
		
		local path = cLevel
		local sprField = sprite
		
		if not pcall(function()
			if not template then
				if not self.vfx.decoSprites[sprite] then
					local fpath = path..sprField
					self.vfx.decoSprites[sprite] = love.graphics.newImage(fpath)
				end
			else
				local fpath = path..template
				if not self.vfx.decoTemplates[template] then
					self.vfx.decoTemplates[template] = ez.newjson(fpath)
				end
			end
		end) then
			local filename = path..sprField
			if template then
				filename = path..template..'.json'
			end
			self:playbackError('Could not load deco file "' .. filename .. '"')
			return
		end
	end
	
	if template and self.vfx.decoTemplates[template] then
		deco.anim = self.vfx.decoTemplates[template]:instance()
		if animation then
			deco.anim:play(animation, tonumber(frame))
			deco.animSpeed = tonumber(speed)
			deco.animFrame = nil
		else
			deco.animSpeed = nil
			
			local f = frame
			if f == 'RANDOM' then
				f = ((deco.animFrame or 0) + math.random(1, self.vfx.decoTemplates[template].frames - 1)) % self.vfx.decoTemplates[template].frames
			elseif f == 'TRUERANDOM' then
				f = math.random(0, self.vfx.decoTemplates[template].frames - 1)
			end
			
			deco.animFrame = tonumber(f)
		end
	else
		deco.anim = nil
		deco.animSpeed = nil
		deco.animFrame = nil
	end
end

function st:updateAdvanceTextDecos()
	local lastTextSetTime = {}
	for k, v in pairs(self.decos) do
		if v.kind == "textdeco" then
			local latest = nil
			for _, e in ipairs(v.events) do
				if e.textString ~= nil and e.time <= self.editorBeat then
					if not latest or e.time > latest then
						latest = e.time
					end
				end
			end
			lastTextSetTime[k] = latest or -math.huge
		end
	end
	
	local advanceCount = {}
	
	local function addTrigger(rawId, triggerTime)
		local key = "textdeco:" .. rawId
		local cutoff = lastTextSetTime[key]
		if cutoff and triggerTime > cutoff then
			advanceCount[key] = (advanceCount[key] or 0) + 1
		end
	end

	local advanceMarkers = self.markersByType.advancetextdeco
	if advanceMarkers then
		for _, m in ipairs(advanceMarkers) do
			local repeats = m.repeats or 0
			local repeatDelay = m.repeatDelay or 1
			
			for i = 0, repeats do
				local t = m.time + (i * repeatDelay)
				if t <= self.editorBeat then
					helpers.targetDecosUsingSyntaxicID(function(rawId)
						addTrigger(rawId, t)
					end, m.id)
				end
			end
		end
	end
	
	for k, deco in pairs(self.decoObjects) do
		if deco.kind == "textdeco" and deco.textTable and #deco.textTable > 0 then
			local target = math.min(1 + (advanceCount[k] or 0), #deco.textTable)
			
			local text = ""
			for i = 1, target do
				text = text .. deco.textTable[i]
			end
			
			deco.textPos = target
			deco.text = text
		end
	end
end

function st:updateDecos()
	self.renderDecos = self.renderDecos or {}
	for k, v in pairs(self.decos) do -- will probably need to sort when tags are not ignored
		if #v.events == 0 or self.editorBeat < v.events[1].time then
			self.renderDecos[k] = nil
			goto continue
		end
		
		local isFirstOfID = false
		local isText = v.kind == "textdeco"
		
		if not self.decoObjects[k] then
			if isText then
				self.decoObjects[k] = em.init('TextDeco', {})
				self.decoObjects[k].kind = "textdeco"
				self.vfx.textdeco[k:sub(10)] = self.decoObjects[k]
			else
				self.decoObjects[k] = em.init('Deco', {})
				self.decoObjects[k].kind = "deco"
				self.vfx.deco[k:sub(6)] = self.decoObjects[k]
			end
			
			isFirstOfID = true
		end
		
		local deco = self.decoObjects[k]
		deco.skipUpdate = true
		deco.skipRender = false
		
		local instantProps = isText and instantPropsText or instantPropsDeco
		
		local props = isText
			and {'x','y','sx','sy','rotationinfluence','scaleinfluence','wrapLen','kx','ky','extraCharSpacing','r','kyFake',
				'ditherpercent','drawLayer','drawOrder','recolor','outline','effectCanvas','effectCanvasRaw','hide','parentid',
				'rotationMode','onlyScaleDistance','colour','justification','font','alphadither','textString','localize',
				'specialoutline','specialcolour','canvas','prefix'}
			or  {'x','y','r','sx','sy','ox','oy','kx','ky', 'rotationinfluence','scaleinfluence','uvx','uvy','uvdx','uvdy',
				 'ecRecolorR','ecRecolorG','ecRecolorB','ecRecolorA', 'sprite', 'drawLayer', 'drawOrder',
				 'recolor', 'outline', 'effectCanvas', 'effectCanvasRaw','effectCanvasType', 'hide', 'parentid', 'rotationMode',
				 'onlyScaleDistance','mirror','tiling', 'colordither','exclusiveMirror','shader', 'alphadither', 'ditherpercent'}
		
		if isFirstOfID then
			deco._baseProps = {}
			for _, p in ipairs(props) do
				deco._baseProps[p] = deco[p]
			end
			deco._trueHide = deco._baseProps['hide']
		end
		
		local spriteChanged = false
		
		for _, p in ipairs(props) do
			if (p == "uvx" or p == "uvy") and deco.tiling then
				goto nextprop
			end
			
			local propEvents = {}
			for _, e in ipairs(v.events) do
				if e[p] ~= nil and e.time <= self.editorBeat then
					table.insert(propEvents, e)
				end
			end
			if #propEvents == 0 then goto nextprop end
			
			local base = deco._baseProps[p]
			for i = 1, #propEvents - 1 do
				local e = propEvents[i]
				base = ((e.mode == "add" and type(e[p]) == "number") and not instantProps[p]) and (base + e[p]) or e[p]
			end
			
			local e = propEvents[#propEvents]
			local target = ((e.mode == "add" and type(e[p]) == "number") and not instantProps[p]) and (base + e[p]) or e[p]
			local isFirstEvent = (e == v.events[1])
			
			local ease = e.ease or "linear"
			local duration = e.duration or 0
			local t = (duration > 0 and not instantProps[p] and not isFirstEvent)
				and helpers.clamp((self.editorBeat - e.time) / duration, 0, 1)
				or 1
			
			local newValue = (type(target) == "number" and not instantProps[p]) and helpers.interpolate(base, target, t, ease) or target
			
			if p == "sprite" and newValue ~= deco.sprite then
				spriteChanged = true
			end
			
			deco._spawnTime = isFirstOfID and e.time or deco._spawnTime or 0
			deco[p] = newValue
			if p == "hide" then
				deco._trueHide = newValue
			end
			::nextprop::
		end
		
		if isText then
			deco:updateSprite()
		else
			if spriteChanged or deco.spr == nil then
				self:updateDecoSprite(deco)
				deco:updateSprite()
			end
		end
		
		-- for some reason the default cat doesn't show until you put a sprite that doesn't exist
		-- i should look deeper into it
		
		deco.hide = deco._trueHide
		if self.minLayer and deco.layer < self.minLayer then
			deco.hide = true
		end
		if self.maxLayer and self.maxLayer < deco.layer then
			deco.hide = true
		end
		if deco.drawLayer == 'ontop' then
			if self.showOnTop then
				deco.hide = deco._trueHide
			else
				deco.hide = true
			end
		end
		
		self.renderDecos[k] = deco
		::continue::
	end
	
	self:updateAdvanceTextDecos()
end

function st:drawGrid(bgc)
	if cs.gridScale and cs.gridScale > 0 then
		love.graphics.setLineWidth(1)
		local s = cs.gridScale
		
		love.graphics.setColor(math.abs(bgc.r/255 - 0.15),math.abs(bgc.g/255 - 0.15),math.abs(bgc.b/255 - 0.15), 1)
		
		local offsetX = -cs.pan[1] % s
		local offsetY = -cs.pan[2] % s
		
		for x = offsetX, 600, s do
			love.graphics.line(x, 0, x, 360)
		end
		
		for y = offsetY, 360, s do
			love.graphics.line(0, y, 600, y)
		end
	end
end

st:setFgDraw(function(self) -- this is a mess
	-- i think the grid and bg is no longer a mess
	local palette = shuv.usePalette and shuv.pal or shuv.paldefault
	local bgc = palette[cs.bgColor] or {r=255,g=255,b=255}
	local vc = palette[cs.voidColor] or {r=255,g=255,b=255}
	if self.editMode ~= 'none' then
		love.graphics.clear(vc.r/255, vc.g/255, vc.b/255)
		self:drawGrid(bgc)
	end
	
	local oldCanv = love.graphics.getCanvas()
	love.graphics.setCanvas(self.canv)
	
	color(cs.voidColor)
	love.graphics.rectangle('fill',0,0,project.res.x,project.res.y)
	
	color(cs.bgColor)
	love.graphics.rectangle('fill',-cs.pan[1],-cs.pan[2],project.res.x,project.res.y)
	self:drawGrid(bgc)
	
	love.graphics.setCanvas(oldCanv)
	
	local success, err = pcall(function()
		if self.drawDecos and self.editMode == "none" then
			love.graphics.setColor(1, 1, 1, 1)
			self:updateDecos()
			for _, v in pairs(self.renderDecos) do
				if not v.parentid or v.parentid == '' then
					v.originalX, v.originalY = v.x, v.y
					v.x, v.y = v.originalX - self.pan[1], v.originalY - self.pan[2]
				end
			end
			
			self.gm:draw()
				
			love.graphics.setCanvas(shuv.canvas)
			love.graphics.setColor(1, 1, 1, 1)

			self.gm:startOnTopShader()
			self.gm:drawCanv()
			self.gm:endOnTopShader()
			if self.vfx.onTopUI then
				self.vfx.onTopUI = true
				--self.gm:drawHud()
			end
			--[[
			love.graphics.setShader()
			for k,v in pairs(self.vfx.deco) do
				if v.drawLayer == 'ontop' then
					v:draw(true)
				end
			end
			for k,v in pairs(self.vfx.textdeco) do
				if v.drawLayer == 'ontop' then
					v:draw(true)
				end
			end]]
			
			for _, v in pairs(self.renderDecos) do
				if not v.parentid or v.parentid == '' then
					v.x, v.y = v.originalX, v.originalY
				end
			end
		elseif self.editMode == "move" then
			local deco = self.editInfo.decoRef
				deco.originalX, deco.originalY = deco.x, deco.y
				deco.x, deco.y = deco.originalX - self.pan[1], deco.originalY - self.pan[2]
			local gridScale = self.gridScale
			if maininput:down('shift') then
				gridScale = gridScale / 2
			end
			
			love.graphics.setColor(1, 1, 1, 0.5)
			deco:drawSprite()
			love.graphics.setColor(1, 1, 1, 1)
			
			local wx, wy = mouse.rx + self.pan[1], mouse.ry + self.pan[2]
			if not maininput:down('ctrl') then
				wx = math.floor(wx / gridScale + 0.5) * gridScale
				wy = math.floor(wy / gridScale + 0.5) * gridScale
			end
			
			if self.lockedAxis == 'x' then
				deco.x = wx - self.pan[1]
				self.editInfo.x = wx
				self.editInfo.y = self.editInfo.originalY
			elseif self.lockedAxis == 'y' then
				deco.y = wy - self.pan[2]
				self.editInfo.y = wy
				self.editInfo.x = self.editInfo.originalX
			else
				deco.x = wx - self.pan[1]
				self.editInfo.x = wx
				deco.y = wy - self.pan[2]
				self.editInfo.y = wy
			end
			
			deco:drawSprite()
			
				deco.x, deco.y = deco.originalX, deco.originalY
		elseif self.editMode == "scale" then
			local deco = self.editInfo.decoRef
			deco.originalX, deco.originalY = deco.x, deco.y
			deco.x, deco.y = deco.originalX - self.pan[1], deco.originalY - self.pan[2]
			
			love.graphics.setColor(1, 1, 1, 0.5)
			deco:drawSprite()
			love.graphics.setColor(1, 1, 1, 1)
			
			local rot = math.rad(self.editInfo.startR or deco.r or 0)
			local cosr, sinr = math.cos(rot), math.sin(rot)
			
			local function toLocal(dx, dy)
				return dx * cosr + dy * sinr, -dx * sinr + dy * cosr
			end
			
			local wx, wy = mouse.rx + self.pan[1], mouse.ry + self.pan[2]
			
			local startLX, startLY = toLocal(self.editInfo.startMouseX - self.editInfo.startX, self.editInfo.startMouseY - self.editInfo.startY)
			local curLX, curLY = toLocal(wx - self.editInfo.startX, wy - self.editInfo.startY)
			
			local sfx = (math.abs(startLX) > 0.0001) and (curLX / startLX) or 1
			local sfy = (math.abs(startLY) > 0.0001) and (curLY / startLY) or 1
			
			if self.lockedAxis == "x" then
				deco.sx = self.editInfo.startSX * sfx
				deco.sy = self.editInfo.startSY
			elseif self.lockedAxis == "y" then
				deco.sx = self.editInfo.startSX
				deco.sy = self.editInfo.startSY * sfy
			else
				if maininput:down('shift') then
					local sf = math.abs(curLX) > math.abs(curLY) and sfx or sfy
					deco.sx = self.editInfo.startSX * sf
					deco.sy = self.editInfo.startSY * sf
				else
					deco.sx = self.editInfo.startSX * sfx
					deco.sy = self.editInfo.startSY * sfy
				end
			end
			
			if not maininput:down('ctrl') then
				local snap = 0.1
				deco.sx = math.floor(deco.sx / snap + 0.5) * snap
				deco.sy = math.floor(deco.sy / snap + 0.5) * snap
			end
			
			deco:drawSprite()
			
			self.editInfo.sx = deco.sx
			self.editInfo.sy = deco.sy
			
			local sw, sh = deco.spr:getDimensions()
			
			love.graphics.push()
			love.graphics.translate(self.editInfo.startX - self.pan[1],self.editInfo.startY - self.pan[2])
			love.graphics.rotate(rot)
			
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.setLineWidth(1 / math.max(math.min(self.editInfo.startSX, self.editInfo.startSY), 0.0001))
			love.graphics.push()
			love.graphics.scale(self.editInfo.startSX, self.editInfo.startSY)
			love.graphics.rectangle("line", -deco.ox, -deco.oy, sw, sh)
			love.graphics.pop()
			
			love.graphics.pop()
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.setLineWidth(1)
			
			deco.x, deco.y = deco.originalX, deco.originalY
		elseif self.editMode == "rotate" then
			local deco = self.editInfo.decoRef
			deco.originalX, deco.originalY = deco.x, deco.y
			deco.x, deco.y = deco.originalX - self.pan[1], deco.originalY - self.pan[2]
			local pivotX, pivotY = self.editInfo.startX - self.pan[1], self.editInfo.startY - self.pan[2]
			local lineLen = 100
			local startRot = math.rad(self.editInfo.startR or 0)
			local origR = deco.r
			deco.r = self.editInfo.startR or 0
			
			love.graphics.setColor(1, 1, 1, 0.5)
			deco:drawSprite()
			
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.line(pivotX, pivotY, pivotX + math.cos(startRot) * lineLen, pivotY + math.sin(startRot) * lineLen)
			
			local dx, dy = mouse.rx - pivotX, mouse.ry - pivotY
			local mouseAngle = math.atan2(dy, dx)
			
			if maininput:down('shift') then
				local snap = math.rad(15)
				mouseAngle = math.floor(mouseAngle / snap + 0.5) * snap
			end
			
			deco.r = math.deg(mouseAngle)
			
			love.graphics.setColor(1, 1, 1, 1)
			deco:drawSprite()
			
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.line(pivotX, pivotY, mouse.rx, mouse.ry)
			love.graphics.setColor(1, 1, 1, 1)
			
			self.editInfo.r = deco.r
			
			deco.r = origR
			deco.x, deco.y = deco.originalX, deco.originalY
		end
	end)
	if not success then print("failed drawing deco") end
	if err then print(err) end
	
	love.graphics.setColor(.99, 0, 0)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", -self.pan[1] - 1, -self.pan[2] - 1, 602, 362)
	
	if self.editMode == 'move' then
		local x1, y1 = self.editInfo.startX - (self.lockedAxis == "x" and 600 or 0), self.editInfo.startY - (self.lockedAxis == "y" and 600 or 0)
		local x2, y2 = self.editInfo.startX + (self.lockedAxis == "x" and 600 or 0), self.editInfo.startY + (self.lockedAxis == "y" and 600 or 0)
		love.graphics.line(x1-self.pan[1],y1-self.pan[2],x2-self.pan[1],y2-self.pan[2])
	elseif self.editMode == 'scale' then
		local rot = math.rad(self.editInfo.startR or 0)
		local xdirX, xdirY = math.cos(rot) * 600, math.sin(rot) * 600
		local ydirX, ydirY = -math.sin(rot) * 600, math.cos(rot) * 600
		
		local dx, dy = 0, 0
		if self.lockedAxis == "x" then
			dx, dy = xdirX, xdirY
		elseif self.lockedAxis == "y" then
			dx, dy = ydirX, ydirY
		end
		
		if self.lockedAxis == "x" or self.lockedAxis == "y" then
			local x1, y1 = self.editInfo.startX - dx, self.editInfo.startY - dy
			local x2, y2 = self.editInfo.startX + dx, self.editInfo.startY + dy
			
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.line(x1 - self.pan[1], y1 - self.pan[2], x2 - self.pan[1], y2 - self.pan[2])
			love.graphics.setColor(1, 1, 1, 1)
		end
	end
	
	if self.editMode == "none" then
		self:imgui()
	end
end)

return st