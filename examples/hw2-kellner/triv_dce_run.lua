local tdce = require("triv_dce")
local u = require("util")

local j = u.load_json_file(io.stdin)
for _, func in ipairs(j["functions"]) do
	tdce.triv_dce(func, 0)
end
u.print_json_stdout(j)
