local lvn = {}

local gb = require("gen_blocks")
local json = require("json")
local u = require("util")

--LOG = assert(io.open("LVN.log", "w"))

Value = function(op, args)
	return { op = op, args = args }
end

-- last_writes function (unchanged)
lvn.last_writes = function(instrs)
	local out = {}
	for i = 1, #instrs do
		out[i] = false
	end
	local seen = {}
	for idx = #instrs, 1, -1 do
		local instr = instrs[idx]
		if instr["dest"] then
			local dest = instr["dest"]
			if not seen[dest] then
				out[idx] = true
				seen[dest] = true
			end
		end
	end
	return out
end

-- read_first function (unchanged)
lvn.read_first = function(instrs)
	local read = {}
	local written = {}
	for _, instr in ipairs(instrs) do
		for _, arg in ipairs(instr["args"] or {}) do
			if not written[arg] then
				read[arg] = true
			end
		end
		if instr["dest"] then
			written[instr["dest"]] = true
		end
	end
	return read
end

-- lvn_block function without the Numbering class
lvn.lvn_block = function(block, lookup, canonicalize, fold)
	local fresh_counter = 0 -- Simple counter to replace Numbering

	-- Helper function to generate fresh numbers
	local function fresh()
		fresh_counter = fresh_counter + 1
		return fresh_counter
	end

	local var2num = {} -- Maps variables to their numbers
	local value2num = {}
	local num2vars = {}
	local num2const = {}

	-- Assign fresh numbers to variables in the block
	for var in pairs(lvn.read_first(block)) do
		local num = fresh()
		var2num[var] = num
		num2vars[num] = { var }
	end

	-- Process each instruction in the block
	for idx, instr in ipairs(block) do
		local last_write = lvn.last_writes(block)[idx]
		local argvars = instr["args"] or {}
		local argnums = {}

		-- Map variable names to their numbers
		for _, var in ipairs(argvars) do
			table.insert(argnums, var2num[var])
		end

		if instr["args"] then
			-- Replace args with their number representations
			instr["args"] = {}
			for _, n in ipairs(argnums) do
				table.insert(instr["args"], num2vars[n][1])
			end
		end

		if instr["dest"] then
			-- Remove the destination from num2vars
			for _, rhs in pairs(num2vars) do
				if u.table_contains(rhs, instr["dest"]) then
					u.remove_value(rhs, instr["dest"])
				end
			end
		end

		local val = nil
		if instr["dest"] and instr["args"] and (instr["op"] ~= "call") then
			-- Canonicalize and lookup value
			val = canonicalize(Value(instr["op"], argnums))
			local num = lookup(value2num, val)
			if num then
				var2num[instr["dest"]] = num
				if num2const[num] then
					-- Replace instruction with const
					instr["op"] = "const"
					instr["value"] = num2const[num]
					instr["args"] = nil
				else
					-- Replace instruction with id
					instr["op"] = "id"
					instr["args"] = { num2vars[num][1] }
					table.insert(num2vars[num], instr["dest"])
				end
				-- yes... lua does not have a continue keyword.
				goto continue
			end
		end

		-- Add new variable
		if instr["dest"] then
			local newnum = fresh()
			var2num[instr["dest"]] = newnum
			if instr["op"] == "const" then
				num2const[newnum] = instr["value"]
			end
			local var = (last_write and instr["dest"]) or ("lvn." .. tostring(newnum))
			num2vars[newnum] = { var }
			instr["dest"] = var

			-- Perform constant folding if possible
			if val then
				local const = fold(num2const, val)
				if const then
					num2const[newnum] = const
					instr["op"] = "const"
					instr["value"] = const
					instr["args"] = nil
				else
					value2num[val] = newnum
				end
			end
		end

		::continue::
	end
end

-- _lookup function
lvn._lookup = function(value2num, value)
	if value.op == "id" then
		return value.args[1]
	else
		return value2num[value]
	end
end

-- FOLDABLE_OPS table
local FOLDABLE_OPS = {
	add = function(a, b)
		return a + b
	end,
	mul = function(a, b)
		return a * b
	end,
	sub = function(a, b)
		return a - b
	end,
	div = function(a, b)
		return math.floor(a / b)
	end,
	gt = function(a, b)
		return a > b
	end,
	lt = function(a, b)
		return a < b
	end,
	ge = function(a, b)
		return a >= b
	end,
	le = function(a, b)
		return a <= b
	end,
	ne = function(a, b)
		return a ~= b
	end,
	eq = function(a, b)
		return a == b
	end,
	-- reserved lua keywords
	["or"] = function(a, b)
		return a or b
	end,
	["and"] = function(a, b)
		return a and b
	end,
	["not"] = function(a)
		return not a
	end,
}

lvn._fold = function(num2const, value)
	local op = value.op
	if FOLDABLE_OPS[op] then
		-- Try to get constant arguments
		local const_args = {}
		for _, n in ipairs(value.args) do
			if not num2const[n] then
				-- At least one argument is not a constant
				-- Handle special cases for equality checks and logical operators
				if (op == "eq" or op == "ne" or op == "le" or op == "ge") and value.args[1] == value.args[2] then
					return op ~= "ne"
				elseif op == "and" or op == "or" then
					local const_val = num2const[value.args[1]] or num2const[value.args[2]]
					if (op == "and" and not const_val) or (op == "or" and const_val) then
						return const_val
					end
				end
				return nil
			end
			-- Add to constant args if all are constants
			table.insert(const_args, num2const[n])
		end

		-- Return the result of the foldable operation
		local ok, result = pcall(FOLDABLE_OPS[op], table.unpack(const_args))
		if ok then
			return result
		else
			return nil -- ZeroDivisionError or any runtime error
		end
	end
	return nil
end

-- _canonicalize function
lvn._canonicalize = function(value)
	--LOG:write("canon " .. value.op .. "\n")
	local op = value.op
	if op == "add" or op == "mul" then
		-- Sort the arguments for commutative operations like add and mul
		table.sort(value.args)
	end
	return value
end

-- lvn function
lvn.locvalnum = function(bril, prop, canon, fold)
	prop = prop or false
	canon = canon or false
	fold = fold or false

	for _, func in ipairs(bril.functions) do
		local blocks = gb.gen_block_list(func.instrs)
		for _, block in ipairs(blocks) do
			--print(block)
			lvn.lvn_block(block, prop and lvn._lookup or function(v2n, v)
				return v2n[v]
			end, canon and lvn._canonicalize or function(v)
				return v
			end, fold and lvn._fold or function(n2c, v)
				return nil
			end)
		end
		--func.instrs = blocks
		func["instrs"] = {}
		for _, b in ipairs(blocks) do
			for _, i in ipairs(b) do
				table.insert(func["instrs"], i)
			end
		end
	end
end

--LOG:close()

return lvn
