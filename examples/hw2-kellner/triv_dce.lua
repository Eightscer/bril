local tdce = {}

--local json = require("json")
local gb = require("gen_blocks")
local u = require("util")

tdce.triv_dce_pass = function(func, dry)
	local blocks = gb.gen_block_list(func["instrs"])
	local used_vars = {}

	-- Collect used variables
	for _, b in ipairs(blocks) do
		for _, i in ipairs(b) do
			if i["args"] then
				for _, a in ipairs(i["args"]) do
					if not u.table_contains(used_vars, a) then
						table.insert(used_vars, a)
					end
				end
			end
		end
	end

	-- Remove unused instructions
	local removed = 0
	for bi, b in ipairs(blocks) do
		local trimmed = {}
		for _, i in ipairs(b) do
			if not i["dest"] or u.table_contains(used_vars, i["dest"]) then
				table.insert(trimmed, i)
			end
		end
		removed = removed + (#b - #trimmed)
		blocks[bi] = trimmed -- Replace the block with the trimmed one
	end

	if not dry then
		func["instrs"] = {}
		for _, b in ipairs(blocks) do
			for _, i in ipairs(b) do
				table.insert(func["instrs"], i)
			end
		end
	end
	return removed
end

tdce.triv_dce = function(func, passes)
	local n = 1
	local elim = tdce.triv_dce_pass(func, false)
	local total = elim
	while elim > 0 do
		if passes > 0 and n > passes then
			return total
		end
		elim = tdce.triv_dce_pass(func, false)
		total = total + elim
		n = n + 1
	end
	return total
end

--[[
local function main()
	local c
	if #arg == 1 then
		local f = assert(io.open(arg[1], "rb"))
		c = f:read("*all")
		f:close()
	elseif #arg > 1 then
		print("usage: lua triv_dce.lua [filename]")
		return
	else
		c = io.stdin:read("*all")
	end
	local txt = json.decode(c)
	for _, func in ipairs(txt["functions"]) do
		if func["name"] then
			print(func["name"] .. ":")
		else
			print("Anonymous function:")
		end
		local elim = Triv_dce(func, 0)
		print(elim .. " instruction(s) eliminated")
	end
	local f = assert(io.open("dce_out.json", "w"))
	local enc = json.encode(txt)
	f:write(enc)
	f:close()
end
--]]
-- main()

return tdce
