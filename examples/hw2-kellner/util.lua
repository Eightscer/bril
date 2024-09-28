-- Helper functions
local util = {}
local json = require("json")

-- Check if a table contains a value
util.table_contains = function(table, element)
	for _, value in ipairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

-- Remove entry from table based on value
util.remove_value = function(tbl, val)
	for i, v in ipairs(tbl) do
		if v == val then
			table.remove(tbl, i)
			break
		end
	end
end

-- Load JSON file and decode into table
util.load_json_filename = function(filename)
	local f = assert(io.open(filename, "rb"))
	local c = f:read("*all")
	f:close()
	return json.decode(c)
end

-- Load JSON file using file descriptor
util.load_json_file = function(fd)
	return json.decode(fd:read("*all"))
end

-- Encode table into JSON and store into file
util.save_json_filename = function(filename, j)
	local f = assert(io.open(filename, "w"))
	local enc = json.encode(j)
	f:write(j)
	f:close()
end

util.print_json_stdout = function(j)
	io.stdout:write(json.encode(j))
end

return util
