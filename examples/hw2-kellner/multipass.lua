-- combines tdce and lvn

local json = require("json")
-- local gb = require("gen_blocks")
local tdce = require("triv_dce")
local locvn = require("loc_val_num")

local function main()
	local c = io.stdin:read("*all")
	local txt = json.decode(c)
	local dce_passes = 1
	local cycles = 10
	for i = 1, cycles, 1 do
		for j = 1, dce_passes, 1 do
			for _, func in ipairs(txt["functions"]) do
				_ = Triv_dce(func, dce_passes)
			end
			lvn(txt, true, true, true)
		end
	end
	local enc = json.encode(txt)
	io.stdout:write(enc)
end

main()
