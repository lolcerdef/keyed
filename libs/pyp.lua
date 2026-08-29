local pyp = {}

local function escape(s)
    return s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

function pyp.loadFile(root, path)
	return love.filesystem.read(root .. path)
end

function pyp.getSection(str, from, to, inclusive)
	from, to = escape(from), escape(to)
	local pattern = inclusive and ("(" .. from .. ".-" .. to .. ")") or (from .. "(.-)" .. to)
	return string.match(str, pattern)
end

function pyp.doReplace(str, list)
	if #list % 2 ~= 0 then 
		print('replace list needs to be even')
		return str
	end
	local find = {}
	local replace = {}
	for i, v in ipairs(list) do
		if i % 2 == 0 then
			table.insert(replace, v)
		else
			table.insert(find, v)
		end
	end
	
	for i, pattern in ipairs(find) do
		str = str:gsub(escape(pattern), replace[i])
	end
	return str
end

function pyp.doPrefix(str, list)
	if #list % 2 ~= 0 then 
		print('prefix list needs to be even')
		return str
	end
	for i = 1, #list, 2 do
		local target = list[i]
		local text = list[i + 1]
		str = str:gsub(escape(target), text .. "%0")
	end
	return str
end

function pyp.doSuffix(str, list)
	if #list % 2 ~= 0 then 
		print('suffix list needs to be even')
		return str
	end
	for i = 1, #list, 2 do
		local target = list[i]
		local text = list[i + 1]
		str = str:gsub(escape(target), "%0" .. text)
	end
	return str
end

function pyp.getString(root, entry)
	if (not root) or (root == '') then return end
	if (not entry.path) or (entry.path == '') then return end

	local fileContent = pyp.loadFile(root, entry.path)
	if not fileContent then return nil end

	local section
	if entry.from and entry.from ~= '' and entry.to and entry.to ~= '' then
		local inclusive = entry.inclusive
		if inclusive == nil then inclusive = true end
		section = pyp.getSection(fileContent, entry.from, entry.to, inclusive)
	else
		section = fileContent
	end
	
	if section then
		if entry.replace then
			section = pyp.doReplace(section, entry.replace)
		end
		if entry.prefix then
			section = pyp.doPrefix(section, entry.prefix)
		end
		if entry.suffix then
			section = pyp.doSuffix(section, entry.suffix)
		end
		if entry.before then
			section = entry.before .. '\n' .. section
		end
		if entry.after then
			section = section .. '\n' .. entry.after
		end
	else
		print('found nothing:', entry.from, "to", entry.to, "in", root .. entry.path)
		return nil
	end
	
	return section
end

function pyp.get(root, entry, chunkName)
	local str = pyp.getString(root, entry)
	if not str then
		print("no string: skipping", entry.name)
		return nil
	end
	print(str)
	
	local name = chunkName or entry.name or "pyp_chunk"
	local chunk, err = loadstring(str, name)
	if chunk then
		if entry.run then
			return chunk()
		else
			return chunk
		end
	else
		print("failed to load", entry.name, err)
		return nil
	end
end

return pyp