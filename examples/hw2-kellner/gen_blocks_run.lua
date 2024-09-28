local gb = require("gen_blocks")
local u = require("util")

local j = u.load_json_file(io.stdin)
for _, func in ipairs(j["functions"]) do
	if func["name"] then
		print(func["name"] .. ":")
	else
		print("Anonymous function:")
	end
	local blocks = gb.gen_block_list(func["instrs"])
	gb.print_block_list(blocks)
end
