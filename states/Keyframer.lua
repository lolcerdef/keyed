local st = Gamestate:new('Keyframer')

local function convertCol(c)
	local a = math.floor(c / 0x1000000) % 0x100
	local r = math.floor(c / 0x10000) % 0x100
	local g = math.floor(c / 0x100) % 0x100
	local b = c % 0x100
	
	return {r / 255, g / 255, b / 255, a / 255}
end

st:setInit(function(self, level, variant, beat, preloadSoundData)
	em.clear()
	
	love.keyboard.setTextInput(true)
	self.gm = em.init("GameManager") -- <- does something, not much though
	self.cmd = em.init("CommandHandler")
	self.p._actualX = self.p.x
	self.p._actualY = self.p.y
	
	self.isPlaying = false
	mouse:disableGameplay()
	love.mouse.setVisible(true)
	mouse.hidden = true
	
	self.aboveImguiCanv = love.graphics.newCanvas(1200,720)
	
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
	
	self.editorBeat = beat or 0
	self.lastEditorBeat = self.editorBeat
	self.beatSize = 40
	self.timelineScroll = 0
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
	-- id1 =  {kind = "deco", order = 2, events = {{time = 2, angle = 0, etc.}, etc.}},
	-- otherid = {kind = "textdeco", order = 3, events = {{time = 0, angle = 0, etc.}, etc.}}
	self.decos = {}
	self.selectedDecos = {}
	self.selectedKeyframes = {}
	
	self.decoObjects = {}
	
	self.markers = {}
	self.selectedMarker = nil
	self.draggingMarker = nil
	
	self.markerColors = {
		bookmark = convertCol(0xFFFFD86B),
		comment = convertCol(0xFF555555),
		tag = convertCol(0xFFF08E54),
		play = convertCol(0xFF4261FF),
		playSound = convertCol(0xFFFF4242),
		setBPM = convertCol(0xFF9B59B6),
		retime = convertCol(0xFF1ABC9C),
		showResults = convertCol(0xFF2ECC71),
		loadCustomFont = convertCol(0xFFE84393),
		advancetextdeco = convertCol(0xFFA29BFE),
		decoShader = convertCol(0xFF00CEC9),
		shader_uniform = convertCol(0xFF6C5CE7),
		newCanvas = convertCol(0xFFB8E986),
		editCanvas = convertCol(0xFF8E9B0C),
		ease = convertCol(0xFF74B9FF),
		outline = convertCol(0xFF95A5A6),
		setBgColor = convertCol(0xFFF1C40F),
		setBoolean = convertCol(0xFFFF7675),
		setColor = convertCol(0xFFD980FA),
	}
	
	local loadTheseMarkers = {
		loadCustomFont = true,
		newCanvas = true,
		decoShader = true,
		tags = true, 
	} -- probably more i'm forgetting rn
	-- tags inset events into self.playEvents, perhaps this could be used?
	-- like maybe self.playEvents get rebuilt when a tag is added/removed/modified
	-- and everything else looks in this?
	-- tags are probably the only thing that does this no?
	
	if self.level then
		self.gm:resetLevel()
		
		local decoCount = 0
		for i, v in ipairs(self.level.events) do
			decoCount = decoCount + 1
			
			--local t = v.type:lower()
			if self.markerColors[v.type] then
				table.insert(self.markers, self.level.events[i])
				
				if loadTheseMarkers[v.type] then
					if Event.onLoad[v.type](v) then
						self.drawDecos = false
					end
				end
			elseif v.type == "deco" or v.type == "textdeco" then
				if Event.onLoad[v.type](v) then
					self.drawDecos = false
				end
				if v.type == "textdeco" then
					v.text = v.textString
				end
				
				if not self.decos[v.id] then
					self.decos[v.id] = {}
					self.decos[v.id].order = decoCount
					self.decos[v.id].events = {}
					self.decos[v.id].kind = v.type
				end
				table.insert(self.decos[v.id].events, self.level.events[i])
				table.sort(self.decos[v.id].events, function(a, b)
					if a.time == b.time then
						return (a.order or 0) < (b.order or 0)
					end
					return a.time < b.time
				end)
			end
		end
	end
	
	table.sort(self.timingInfo.timingPoints, function(a, b)
		return a.beat < b.beat
	end)
	
	self.mouseStartX = nil
	self.mouseStartY = nil
	self.editMode = "none"
	self.lockedAxis = "none"
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
			print("saved")
		end,
		'save',
		'save'
	)
	self:addKeybind(function()
			
		end,
		'make keyframe',
		'i'
	)
	self:addKeybind(function()
			
		end,
		'hide deco',
		'h'
	)
	self:addKeybind(function()
			
		end,
		'move deco',
		'g'
	)
	self:addKeybind(function()
			
		end,
		'scale deco',
		'd'
	)
	self:addKeybind(function()
			
		end,
		'rotate deco',
		'r'
	)
	self:addKeybind(function()
			
		end,
		'axis x',
		'x'
	)
	self:addKeybind(function()
			
		end,
		'axis y',
		'y'
	)
	self:addKeybind(function()
			
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
		'r'
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
			end
		end,
		'start/end playback',
		'space'
	)
	self:addKeybind(function()
			self.exitDialogue = true
		end,
		'exit',
		'back'
	)
end)

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

function st:getSnapValue()
	return self.beatSnapValues[self.beatSnap] or self.customBeatSnap
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
	local retimes = {}
	for _, m in ipairs(self.markers) do
		if m.type == 'retime' then
			table.insert(retimes, m)
		end
	end
	table.sort(retimes, function(a, b) return a.time < b.time end)
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
	for _, m in ipairs(self.markers) do
		if (m.type == 'play' or m.type == 'setBPM') and m.bpm and m.time <= beat then
			if m.time > bestTime then
				bestTime = m.time
				bpm = m.bpm
			end
		end
	end
	if self.rateMod then
		bpm = bpm * self.rateMod
	end
	return bpm
end

function st:setBGColor()
	local color = 0
	local vcolor = nil
	local bestTime = -math.huge
	for _, m in ipairs(self.markers) do
		if m.type == 'setBgColor' and m.time <= self.editorBeat then
			if m.time > bestTime then
				bestTime = m.time
				color = m.color
				vcolor = m.voidColor
			end
		end
	end
	self.bgColor = color
	self.voidColor = vcolor or self.voidColor
end

function st:updateColorPalette()
	shuv.resetPal()
	
	local byIndex = {}
	for _, m in ipairs(self.markers) do
		if m.type == 'setColor' then
			local idx = m.color or 0
			byIndex[idx] = byIndex[idx] or {}
			table.insert(byIndex[idx], m)
		end
	end
	
	for idx = 0, 7 do
		local events = byIndex[idx]
		if events then
			table.sort(events, function(a, b) return a.time < b.time end)
			
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
	self.renderDecos = {}
	print("KILLED EVERYTHING")
end

st:setUpdate(function(self, dt)
	self.p.x = self.p._actualX - self.pan[1]
	self.p.y = self.p._actualY - self.pan[2]
	
	self:updateColorPalette()
	self:setBGColor()
	
	if self.editorBeat < (self.lastEditorBeat or self.editorBeat) - 0.0001 then
		self:rebuildDecoObjects()
	end
	self.lastEditorBeat = self.editorBeat
	
	if self.isPlaying then
		self.source:update(dt)
		self.level.bpm = self:getBPMAtBeat(self.editorBeat)
		self.editorBeat = self.source:getBeat() + self:getRetimeOffset(self.source:getBeat())
		self.cBeat = self.editorBeat
		self.timelineScroll = self.editorBeat - 50/self.beatSize
		
		for _, v in pairs(self.decoObjects) do
			v:update(dt)
		end
	end
	
	if not imgui.love.GetWantCaptureMouse() then
		if maininput:pressed("mouse3") and self.editMode == "none" then
			self.editMode = "panning"
			self.mouseStartX = mouse.rx + self.pan[1]
			self.mouseStartY = mouse.ry + self.pan[2]
		end
		if maininput:down("mouse3") and self.editMode == "panning" then
			self.pan[1] = self.mouseStartX - mouse.rx
			self.pan[2] = self.mouseStartY - mouse.ry
		end
		if maininput:released("mouse3") and self.editMode == "panning" then
			self.editMode = "none"
			self.mouseStartX = nil
			self.mouseStartY = nil
		end
	end
	
	self:checkKeybinds()
	
end)

function st:imgui()
	local inputFlag = nil
	local window_flag = 'ImGuiCond_FirstUseEver'
	if self.resetwindows then
		window_flag = 'ImGuiCond_Always'
		self.resetwindows = false
	end
	
	helpers.SetNextWindowPos(470, 500, window_flag)
	helpers.SetNextWindowSize(700, 200, window_flag)
	imgui.Begin("Timeline ##keyframer",nil,inputFlag)
		--local drawlist = imgui.GetWindowDrawList()
		
		local function snapBeat(b)
			local subdiv = self:getSnapValue() or 1
			return math.floor(b * subdiv + 0.5) / subdiv
		end
		local function clampedSnap(b)
			return math.max(-8, snapBeat(math.max(-8, b)))
		end
		
		local function line(x1, y1, x2, y2, c, w)
			love.graphics.setColor(c)
			love.graphics.setLineWidth(w)
			love.graphics.line(x1,y1,x2,y2)
		end
		local function rect(x, y, w, h, c)
			love.graphics.setColor(c)
			love.graphics.setLineWidth(0)
			love.graphics.rectangle("fill", x, y, w, h)
		end
		local function text(x, y, c, t, r)
			love.graphics.setColor(c)
			local r = r or 0
			love.graphics.print(t, x, y, math.rad(r))
		end
		local function quad(x1, y1, x2, y2, x3, y3, x4, y4, c)
			love.graphics.setColor(c)
			love.graphics.setLineWidth(0)
			love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)
		end
		local function triangle(x1, y1, x2, y2, x3, y3, c)
			love.graphics.setColor(c)
			love.graphics.setLineWidth(0)
			love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3)
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
		
		-- clors :3
		local BGC = convertCol(0xFF222222)
		local labelBGC = convertCol(0xFF1A1A1A)
		local rowAltC = convertCol(0xFF272727)
		local lineC = convertCol(0xFF3C3C3C)
		local lineHiC = convertCol(0xFF5A5A5A)
		local textC = convertCol(0xFFB0B0B0)
		local playC = convertCol(0xFF3AA0FF)
		local keyC = convertCol(0xFFE0C040)
		local keySelC = convertCol(0xFFFF6060)
		
		local beatSize = self.beatSize
		local function beatToX(b)
			return trackX + (b - scroll) * beatSize
		end
		local function xToBeat(x)
			return (x - trackX) / beatSize + scroll
		end
		
		--[[
		the reason why it's using love.graphics instead now
		is because i though it was a problem with imgui/love 
		not likey big drawlists and causes a crash due to 
		stack limit or something.
		It is actually caused by rtf reaching stack depth
		because when x or y scale is 0 it returns before
		doing love.graphics.pop
		
		I think i'll keep this for now though.
		]]
		
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
		
		local rows = {}
		for id, deco in pairs(self.decos) do
			rows[#rows + 1] = { id = id, order = deco.order or 0, events = deco.events or {} }
		end
		table.sort(rows, function(a, b) return a.order < b.order end)
		
		local total_rows_h = math.max(avail.y - rulerH, #rows * rowH)
		
		local first_beat = math.max(-8, math.floor(scroll))
		local last_beat = math.ceil(scroll + trackAreaW / beatSize)
		
		love.graphics.setCanvas(self.aboveImguiCanv)	
		love.graphics.clear(1,1,1,0)
		if not imgui.IsWindowCollapsed() then
			love.graphics.setFont(fonts.main)
			
			local width = math.max(0, avail.x)
			local height = math.max(0, avail.y)

			love.graphics.setScissor(cursor.x, cursor.y, width, height)
			rect(cursor.x, cursor.y, avail.x, avail.y, BGC)
			rect(cursor.x, tracky, labelW, avail.y, labelBGC)
			
			
			for i, row in ipairs(rows) do
				local row_index = i - 1 - rowScroll
				if row_index >= -8 and row_index < visible_rows then
					local ry = tracky + row_index * rowH
					
					if i % 2 == 0 then
						rect(cursor.x, ry, avail.x, rowH, rowAltC)
					end
					
					line(cursor.x, ry + rowH, cursor.x + avail.x, ry + rowH, lineC, 1)
					text(cursor.x + 8, ry + rowH / 2 - 7, textC, tostring(row.id))
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
						for q = 1, self:getSnapValue() do
							local qx = beatToX(b + q * 1/self:getSnapValue())
							if qx >= trackX and qx <= trackX + trackAreaW then
								line(qx, cursor.y + rulerH * 0.6, qx, cursor.y + rulerH, lineC, 1)
							end
						end
					end
				end
			end
			
			
			for _, m in ipairs(self.markers) do
				local x = beatToX(m.time)
				if x >= trackX and x <= trackX + trackAreaW + diamondSize then
					local mc = self.markerColors[m.type] or {1,1,1,1}
					local sel = self.selectedMarker == m
					local c = sel and keySelC or mc
					line(x, tracky, x, bottomY, c, sel and 2 or 1)
					triangle(x - 6, bottomY, x + 6, bottomY, x, bottomY - 8, c)
					
					local t = m.name or m.type
					text(x, bottomY - 7, c, t, -90)
					if m.duration then
						line(x, bottomY, beatToX(m.time + (m.duration or 0)), bottomY, c, 2)
					end
				end
			end
			
			
			for i, row in ipairs(rows) do
				local row_index = i - 1 - rowScroll
				if row_index >= 0 and row_index < visible_rows then
					local ry = tracky + row_index * rowH
					
					for _, ev in ipairs(row.events) do
						local y = ry + rowH / 2
						local x = beatToX(ev.time)
						local endX = beatToX(ev.time + (ev.duration or 0))
						local c = self.selectedKeyframes[ev] and keySelC or keyC
						
						if x >= trackX - diamondSize and x <= trackX + trackAreaW + diamondSize then
							line(x, y, endX, y, c, 2)
							quad(x, y - diamondSize, x + diamondSize, y, x, y + diamondSize, x - diamondSize, y, c)
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
			
			love.graphics.setScissor()
		end
		love.graphics.setCanvas()
		
		-- fuckass controls
		imgui.SetCursorScreenPos({cursor.x, cursor.y})
		imgui.InvisibleButton("##timeline_input", {avail.x, avail.y})
		
		if imgui.IsItemActive() then
			local mousePos = imgui.GetMousePos()
			local mx, my = mousePos.x, mousePos.y
			
			local markerZoneTop = bottomY - 16
			
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
					self.selectedMarker = closestMarker
					self.draggingMarker = closestMarker
					if closestMarker then
						self.selectedKeyframes = {}
					end
				end
				
				if self.draggingMarker then
					self.draggingMarker.time = clampedSnap(xToBeat(mx))
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
					self.selectedKeyframes = {}
					if closest then
						self.selectedKeyframes[closest] = true
						self.selectedMarker = nil
					end
					self.draggingKey = closest
					self.draggingKeyRow = closest and row or nil
				end
				if self.draggingKey and imgui.IsMouseDragging(0) then
					local newTime = clampedSnap(xToBeat(mx))
					self.draggingKey.time = newTime
					if self.draggingKeyRow then
						table.sort(self.draggingKeyRow.events, function(a, b)
							if a.time == b.time then
								return (a.order or 0) < (b.order or 0)
							end
							return a.time < b.time
						end)
					end
				end
			end
		end
		
		if imgui.IsMouseReleased(0) then
			self.draggingKey = nil
			self.draggingKeyRow = nil
			self.draggingMarker = nil
		end
		
		if imgui.IsWindowHovered() then
			local io = imgui.GetIO()
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
	
	helpers.SetNextWindowPos(270, 500, window_flag)
	helpers.SetNextWindowSize(200, 200, window_flag)
	imgui.Begin("Settings ##keyframer",nil,inputFlag)
		shuv.usePalette = helpers.InputBool("Use Palette", shuv.usePalette or false)
		
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
			beatSnapText = '1/' .. self:getSnapValue()
		end

		imgui.SameLine()
		if self.beatSnap == -1 then
			imgui.Text("Beat: 1/")
			imgui.SameLine()
			self.customBeatSnap = helpers.InputInt('##custombeat', self.customBeatSnap)
			self.customBeatSnap = math.max(self.customBeatSnap, 1)
		else
			imgui.Text("Beat: " .. beatSnapText)
		end
		
	imgui.End()
	
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
	
	if self.errorDialogue then
		helpers.SetNextWindowPos(400, 200, window_flag)
		helpers.SetNextWindowSize(400, 200, window_flag)
		self.errorDialogue = imgui.Begin(self.errorHeader, true)

		imgui.TextWrapped(self.errorMessage)

		if imgui.Button('OK') then
			self.errorDialogue = false
			if not self.drawDecos then
				wantsLeave = true
			end
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

function st:updateDecos()
	self.renderDecos = self.renderDecos or {}
	for k, v in pairs(self.decos) do
		if #v.events > 1 then
			table.sort(v.events, function(a, b)
				if a.time ~= b.time then
					return a.time < b.time
				end
				return (a.order or 0) < (b.order or 0)
			end)
		end

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
				self.vfx.textdeco[k] = self.decoObjects[k]
			else
				self.decoObjects[k] = em.init('Deco', {})
				self.decoObjects[k].kind = "deco"
				self.vfx.deco[k] = self.decoObjects[k]
			end
			
			isFirstOfID = true
		end
		
		local deco = self.decoObjects[k]
		deco.skipUpdate = true
		deco.skipRender = false
		
		local instantProps = isText and instantPropsText or instantPropsDeco
		
		local props = isText
			and {'x','y','sx','sy','rotationinfluence', 'scaleinfluence', 'wrapLen', 'kx', 'ky', 'extraCharSpacing', 'r', 'kyFake', 
				 'drawLayer', 'drawOrder', 'recolor', 'outline', 'effectCanvas', 'effectCanvasRaw','hide','parentid',
				 'rotationMode','onlyScaleDistance','colour','justification','font','textString','localize','specialoutline',
				 'specialcolour','canvas', 'alphadither', 'ditherpercent'}
			or  {'x','y','r','sx','sy','ox','oy','kx','ky', 'rotationinfluence','scaleinfluence','uvx','uvy','uvdx','uvdy',
				 'ecRecolorR','ecRecolorG','ecRecolorB','ecRecolorA', 'sprite', 'drawLayer', 'drawOrder',
				 'recolor', 'outline', 'effectCanvas', 'effectCanvasRaw','effectCanvasType', 'hide', 'parentid', 'rotationMode',
				 'onlyScaleDistance','mirror','tiling', 'colordither','exclusiveMirror','shader', 'alphadither', 'ditherpercent'}
		
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
			
			local base = deco[p]
			for i = 1, #propEvents - 1 do
				local e = propEvents[i]
				base = ((e.mode == "add" and type(e[p]) == "number") and not instantProps[p]) and (base + e[p]) or e[p]
			end
			
			local e = propEvents[#propEvents]
			local target = ((e.mode == "add" and type(e[p]) == "number") and not instantProps[p]) and (base + e[p]) or e[p]
			
			local ease = e.ease or "linear"
			local duration = e.duration or 0
			local t = (duration > 0 and not instantProps[p])
				and helpers.clamp((self.editorBeat - e.time) / duration, 0, 1)
				or 1
			
			local newValue = (type(target) == "number" and not instantProps[p]) and helpers.interpolate(base, target, t, ease) or target
			
			if p == "sprite" and newValue ~= deco.sprite then
				spriteChanged = true
			end
			
			deco._spawnTime = isFirstOfID and e.time or deco._spawnTime or 0
			deco[p] = newValue
			::nextprop::
		end
		
		if isText then
			deco:updateSprite()
		else
			if spriteChanged or deco.spr == nil then
				deco:updateSprite()
			end
		end
		
		deco:updateLayer() -- just in case
		
		self.renderDecos[k] = deco
		::continue::
	end
end

st:setFgDraw(function(self)
	local palette = shuv.usePalette and shuv.pal or shuv.paldefault
	
	local bgc = palette[self.bgColor] or {r=255,g=255,b=255}
	local vc = palette[self.voidColor] or {r=255,g=255,b=255}
	love.graphics.clear(vc.r/255, vc.g/255, vc.b/255)
	
	local sw, sh = 600, 360
	
	love.graphics.setColor(bgc.r/255, bgc.g/255, bgc.b/255)
	love.graphics.rectangle('fill',-self.pan[1],-self.pan[2],sw,sh)
	
	love.graphics.setLineWidth(1)
	
	if self.gridScale and self.gridScale > 0 then
		local s = self.gridScale
		
		love.graphics.setColor(math.abs(bgc.r/255 - 0.15),math.abs(bgc.g/255 - 0.15),math.abs(bgc.b/255 - 0.15), 1)
		
		local offsetX = -self.pan[1] % s
		local offsetY = -self.pan[2] % s
		
		for x = offsetX, sw, s do
			love.graphics.line(x, 0, x, sh)
		end
		
		for y = offsetY, sh, s do
			love.graphics.line(0, y, sw, y)
		end
	end
	
	if self.drawDecos then
		self:updateDecos()
		for _, v in pairs(self.renderDecos) do
			v.originalX, v.originalY = v.x, v.y
			v.x, v.y = v.originalX - self.pan[1], v.originalY - self.pan[2]
		end
		
		em.draw()
		
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
		end
		
		for _, v in pairs(self.renderDecos) do
			v.x, v.y = v.originalX, v.originalY
		end
	end
	
	love.graphics.setColor(1, 0, 0)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", -self.pan[1] - 1, -self.pan[2] - 1, sw + 2, sh + 2)
	
	self:imgui()
end)

return st