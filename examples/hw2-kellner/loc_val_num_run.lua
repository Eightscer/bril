local lvn = require("loc_val_num")
local u = require("util")

local j = u.load_json_file(io.stdin)
local prop = u.table_contains(arg, "-p")
local canon = u.table_contains(arg, "-c")
local fold = u.table_contains(arg, "-f")
lvn.locvalnum(j, prop, canon, fold)
u.print_json_stdout(j)
