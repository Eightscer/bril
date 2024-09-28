local gb = {}
local json = require("json")
-- local inspect = require("inspect")
-- local util = require("util")

local ctrl_flow_instrs = { "ret", "jmp", "br" }

gb.gen_block_list = function(instrs)
	local curr = {}
	local blocks = {}
	for _, i in ipairs(instrs) do
		if i["op"] then
			table.insert(curr, i)
			if table.concat(ctrl_flow_instrs, " "):find(i["op"]) then
				table.insert(blocks, curr)
				curr = {}
			end
		else
			if #curr > 0 then
				table.insert(blocks, curr)
			end
			curr = {}
			table.insert(curr, i)
		end
	end
	if #curr > 0 then
		table.insert(blocks, curr)
	end
	return blocks
end

gb.print_block_list = function(blocks)
	for _, b in ipairs(blocks) do
		if b[1]["label"] then
			print('\tBlock "' .. b[1]["label"] .. '":')
			b = { table.unpack(b, 2) } -- slice to remove the first element
		else
			print("\tAnon Block:")
		end
		for _, i in ipairs(b) do
			if i["label"] then
				-- do nothing, skip label
			else
				print("\t\t" .. json.encode(i))
			end
		end
	end
end

--[[
local function main()
	local f = assert(io.open("test.json", "rb"))
	local c = f:read("*all")
	local txt = json.decode(c)
	-- print(inspect(txt))
	f:close()
	f = assert(io.open("out.json", "w"))
	local enc = json.encode(txt)
	f:write(enc)
	-- test gen blocks
	for _, func in ipairs(txt["functions"]) do
		if func["name"] then
			print(func["name"] .. ":")
		else
			print("Anonymous function:")
		end
		local blocks = Gen_block_list(func["instrs"])
		Print_block_list(blocks)
	end
	f:close()
end
--]]
-- main()

return gb
