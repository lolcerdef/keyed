local st = Gamestate:new('Keyframer')

st:setInit(function(self, level, variant, beat, preloadSoundData)
	love.keyboard.setTextInput(true)
	self.gm = em.init("GameManager") -- <- does fucking nothing and i can't be bothered to look into why
	self.cmd = em.init("CommandHandler")
	
	self.isPlaying = false
	mouse:disableGameplay()
	love.mouse.setVisible(true)
	mouse.hidden = true
	
	--self.returnData = returnData or nil
	self.soundData = preloadSoundData
	self.timingInfo = {
		initial = {},
		timingPoints = {}
	}
	
	self.lastSaved = 0
	self.unsavedChanges = true
	
	shuv.usePalette = false
	shuv.stateDisabled = nil
	shuv.disabledUntilNewState = false
	
	self.editorBeat = beat or 0
	self.beatSize = 40
	self.timelineScroll = 0
	self.timelineRowScroll = 0
	
	self.level = self.level or level or nil
	self.variant = variant
	--[[if self.level == nil then
		self.level = LevelManager:loadLevel(cLevel, cs.variant)
		--bbp.utils.printTable(self.level)
	end]]
	
	self.decoSprites = {}
	self.drawDecos = true
	
	-- list of deco ids
	-- id1 =  {order = 2, events = {{time = 2, angle = 0, etc.}, etc.}},
	-- otherid = {order = 2, events = {{time = 0, angle = 0, etc.}, etc.}}
	self.decos = {}
	self.selectedDecos = {}
	self.selectedKeyframes = {}
	
	self.decoObjects = {}
	
	self.markers = {}
	self.selectedMarker = nil
	self.draggingMarker = nil
	
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
	}
	
	if self.level then
		for i, v in ipairs(self.level.events) do
			local t = v.type:lower()
			-- for now just regular deco objects
			if v.type == "deco" then --(t:find("deco", 1, true) or t:find("camera", 1, true)) and not t:find("shader", 1, true) then
				if v.id == nil or v.id == "" then
					self.drawDecos = false
					self:playbackError("IDs can't be empty.")
					break
				end
				--[[
					not (string.sub(v.sprite, 1, 4) == '@aft') and 
					not (string.sub(v.sprite, 1, 6) == '@stamp') and 
					not (string.sub(v.sprite, 1, 7) == '@canvas') and 
					not love.filesystem.getInfo(cLevel .. v.sprite) then
				]]
				if v.sprite and v.sprite ~= "" then
					local path = cLevel .. v.sprite
					if love.filesystem.getInfo(path) and not self.decoSprites[v.sprite] then
						self.decoSprites[v.sprite] = love.graphics.newImage(path)
					end
				end
				--print(v.sprite)
				if not self.decos[v.id] then
					self.decos[v.id] = {}
					self.decos[v.id].order = #self.decos
					self.decos[v.id].events = {}
				end
				table.insert(self.decos[v.id].events, self.level.events[i])
				table.sort(self.decos[v.id].events, function(a, b)
					return a.time < b.time
				end)
			elseif self.markerColors[v.type] then
				table.insert(self.markers, self.level.events[i])
				if v.type == "play" then
					self.timingInfo.initial = {
						beatOffset = v.time,
						bpm = v.bpm,
						timeOffsetSeconds = v.offset
					}
					print("found play event", v.time, v.bpm, v.offset)
				elseif v.type == "setBPM" then
					table.insert(self.timingInfo.timingPoints, {beat = v.time, bpm = v.bpm})
					print("found bpm event", v.time, v.bpm)
				end
			end
			
			print(v.type)
		end
	else
		self:leave()
		print("guh")
	end
	
	table.sort(self.timingInfo.timingPoints, function(a, b)
		return a.beat < b.beat
	end)
	
	--bbp.utils.printTable(self.timingInfo)
	
	self.mouseStartX = nil
	self.mouseStartY = nil
	self.editMode = "none"
	self.lockedAxis = "none"
	-- changes to move, size, or rotate
	
	self.bpm = 100
	self.baseBpm = 100
	for _, m in ipairs(self.markers) do
		if m.type == 'play' and m.bpm then
			self.baseBpm = m.bpm
			self.bpm = m.bpm
			break
		end
	end
	
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
	self:addKeybind(function() -- this perhaps sucks
			self.isPlaying = not self.isPlaying
			if self.isPlaying and self.soundData then
				local volume = (savedata.options.audio.musicvolume/10)
				self.source = lovebpm.newTrack()
					:load(self.soundData)
					:setTiming(self.timingInfo)
					:setVolume(volume)
					:play()
					:on("end", function() log("song finished!!!!!!!!!!") end)
				self.source:setBeat(self.editorBeat)
				
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

function st:playbackError(message)
	if not self.errorDialogue then
		log('Playback error: '..message,'error')
		self.errorDialogue = true		
		self.errorMessage = message
		self.errorHeader = "An error has occured during playback."
		self.isPlaying = false
	end
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

st:setUpdate(function(self, dt)
	if self.isPlaying then
		self.bpm = self:getBPMAtBeat(self.editorBeat)
		self.editorBeat = self.editorBeat + (self.bpm/60) * love.timer.getDelta()
		self.timelineScroll = self.editorBeat - 50/self.beatSize
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
		
		local drawlist = imgui.GetWindowDrawList()
		
		local function snapBeat(b)
			local subdiv = self.beatSnapValues[self.beatSnap] or 1
			return math.floor(b * subdiv + 0.5) / subdiv
		end
		local function clampedSnap(b)
			return math.max(-8, snapBeat(math.max(-8, b)))
		end
		
		local function line(x1, y1, x2, y2, c, w)
			drawlist:AddLine({x1, y1}, {x2, y2}, c, w)
		end
		local function rect(x1, y1, x2, y2, c)
			drawlist:AddRectFilled({x1, y1}, {x2, y2}, c)
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
		
		local visible_rows = math.floor((avail.y - rulerH) / rowH)
		local diamondSize = 6
		
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
		
		local beatSize = self.beatSize
		local function beatToX(b)
			return trackX + (b - scroll) * beatSize
		end
		local function xToBeat(x)
			return (x - trackX) / beatSize + scroll
		end
		
		
		
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
		
		local first_beat = math.max(0, math.floor(scroll))
		local last_beat = math.ceil(scroll + trackAreaW / beatSize)
		
		
		rect(cursor.x, cursor.y, cursor.x + avail.x, cursor.y + avail.y, BGC)
		rect(cursor.x, tracky, cursor.x + labelW, cursor.y + avail.y, labelBGC)
		
		
		for i, row in ipairs(rows) do
			local row_index = i - 1 - rowScroll
			if row_index >= 0 and row_index < visible_rows then
				local ry = tracky + row_index * rowH
				
				if i % 2 == 0 then
					rect(cursor.x, ry, cursor.x + avail.x, ry + rowH, rowAltC)
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
					for q = 1, 3 do
						local qx = beatToX(b + q * 0.25)
						if qx >= trackX and qx <= trackX + trackAreaW then
							line(qx, cursor.y + rulerH * 0.6, qx, cursor.y + rulerH, lineC, 1)
						end
					end
				end
			end
		end
		
		
		local bottomY = cursor.y + avail.y
		for _, m in ipairs(self.markers) do
			local x = beatToX(m.time)
			if x >= trackX - diamondSize and x <= trackX + trackAreaW + diamondSize then
				local mc = self.markerColors[m.type] or 0xFFFFFFFF
				local sel = self.selectedMarker == m
				local c = sel and keySelC or mc
				line(x, tracky, x, bottomY, c, sel and 2 or 1)
				triangle(x - 6, bottomY, x + 6, bottomY, x, bottomY - 8, c)
				
				local t = m.name or m.type
				text(x + 8, bottomY - 14, c, t)
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
					self.timelineScroll = math.max(0, scroll - wheel * 0.5)
				end
			end
		end
		
	imgui.End()
	
	if self.exitDialogue then
		helpers.SetNextWindowPos(520, 310, window_flag)
		helpers.SetNextWindowSize(160, 100, window_flag)
		self.exitDialogue = imgui.Begin("Exit ##keyframer", true)
			imgui.Text("Do you wish to save changes?")
			if imgui.Button("Yes") then
				LevelManager:saveLevel(self.level, cLevel, true, self.variant)
				self:leave()
			end
			imgui.SameLine()
			if imgui.Button("No") then
				self:leave()
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
				self:leave()
			end
		end
		imgui.End()
	end
end

function st:updateDecos()
	self.renderDecos = self.renderDecos or {}
	for k, id in pairs(self.decos) do
		if #id.events == 0 or self.editorBeat < id.events[1].time then
			self.renderDecos[k] = nil
			goto continue
		end
		
		local deco = {
			drawLayer = "fg",
			drawOrder = 0,
			id = k,
			sprite = "",
			x = 300,
			y = 180,
			r = 0,
			sx = 1,
			sy = 1,
			ox = 0,
			oy = 0,
			kx = 0,
			ky = 0,
			hide = false,
			_actualOrder = 999
		}
		
		for p, _ in pairs(deco) do
			local propEvents = {}
			for _, e in ipairs(id.events) do
				if e[p] ~= nil and e.time <= self.editorBeat then
					table.insert(propEvents, e)
				end
			end
			if #propEvents == 0 then goto nextprop end
			
			local base = deco[p]
			for i = 1, #propEvents - 1 do
				local e = propEvents[i]
				if e.mode == "add" and type(e[p]) == "number" then
					base = base + e[p]
				else
					base = e[p]
				end
			end
			
			local e = propEvents[#propEvents]
			local target
			if e.mode == "add" and type(e[p]) == "number" then
				target = base + e[p]
			else
				target = e[p]
			end
			
			local ease = e.ease or "linear"
			local duration = e.duration or 0
			local t
			if duration > 0 then
				t = helpers.clamp((self.editorBeat - e.time) / duration, 0, 1)
			else
				t = 1
			end
			
			if type(target) == "number" then
				deco[p] = helpers.interpolate(base, target, t, ease)
			else
				deco[p] = target
			end
			
			::nextprop::
		end
		
		local layerBase
		if deco.drawLayer == "fg" then
			layerBase = 999
		elseif deco.drawLayer == "bg" then
			layerBase = -999
		else
			layerBase = 0
		end
		deco._actualOrder = layerBase + deco.drawOrder
		
		self.renderDecos[k] = deco
		::continue::
	end
end

st:setFgDraw(function(self)
	love.graphics.clear(1,1,1)
	
	local sw, sh = 600, 360
	
	love.graphics.setLineWidth(1)
	
	if self.gridScale and self.gridScale > 0 then
		local s = self.gridScale
		
		love.graphics.setColor(0.85, 0.85, 0.85)
		
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
		
		local sortedDecos = {}
		for _, v in pairs(self.renderDecos) do
			table.insert(sortedDecos, v)
		end
		
		table.sort(sortedDecos, function(a, b)
			local aOnTop = a.drawLayer == "ontop"
			local bOnTop = b.drawLayer == "ontop"
			if aOnTop ~= bOnTop then
				return bOnTop
			end
			if aOnTop and bOnTop then -- i know ontop layering doesn't actually work ingame but whatever
				return (a.drawOrder or 0) < (b.drawOrder or 0)
			end
			return (a._actualOrder or 0) < (b._actualOrder or 0)
		end)
		
		love.graphics.setColor(1, 1, 1)
		for _, v in ipairs(sortedDecos) do
			if not v.hide then
				local sprite = self.decoSprites[v.sprite] or sprites.cat
				love.graphics.draw(sprite, (v.x or 300) - self.pan[1], (v.y or 180) - self.pan[2], math.rad(v.r or 0), v.sx or 1, v.sy or 1, v.ox or 0, v.oy or 0, v.kx or 0, v.ky or 0)
			end
		end
	end
	
	love.graphics.setColor(1, 0, 0)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle(
		"line",
		-self.pan[1],
		-self.pan[2],
		sw,
		sh
	)

	self:imgui()
end)

return st