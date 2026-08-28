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

function pyp.getString(root, entry)
	if (not root) or (root == '') then return end
	if (not entry.path) or (entry.path == '') then return end
	if (not entry.from) or (entry.from == '') then return end
	if (not entry.to) or (entry.to == '') then return end
	local inclusive = entry.inclusive
	if inclusive == nil then inclusive = true end
	
	local fileContent = pyp.loadFile(root, entry.path)
	local section = pyp.getSection(fileContent, entry.from, entry.to, inclusive)
	
	if section then
		if entry.replace then
			section = pyp.doReplace(section, entry.replace)
		end
		if entry.prefix then
			section = entry.prefix .. '\n' .. section
		end
		if entry.suffix then
			section = section .. '\n' .. entry.suffix
		end
	else
		print('found nothing:', entry.from, "to", entry.to, "in", root .. entry.path)
		return nil
	end
	
	return section
end

function pyp.get(root, entry, chunkName)
	local etype = entry.type or "fromto"
	local name = chunkName or entry.name or "pyp_chunk"
	if etype == "require" then
		if (not root) or (root == '') then return end
		if (not entry.path) or (entry.path == '') then return end
		local str = pyp.loadFile(root, entry.path)
		if not str then
			print("no file content: skipping", entry.name)
			return nil
		end
		
		if entry.replace then
			str = pyp.doReplace(str, entry.replace)
		end
		if entry.prefix then
			str = entry.prefix .. '\n' .. str
		end
		if entry.suffix then
			str = str .. '\n' .. entry.suffix
		end
		
		local chunk, err = loadstring(str, name)
		if chunk then
			return chunk()
		else
			print("failed to load", entry.name, err)
			return nil
		end
	end
	
	local str = pyp.getString(root, entry)
	if not str then
		print("no string: skipping", entry.name)
		return nil
	end
	
	local chunk, err = loadstring(str, name)
	if chunk then
		return chunk
	else
		print("failed to load", entry.name, err)
		return nil
	end
end

return pyp