local console = require "console"

local trace = {}
local dotrace = false



local prettyprint = {}

local resultstyle = console.reset..console.bright
local function nop(x) return resultstyle..tostring(x) end
local function special(x)
	return string.format("%s[%s]",
		console.bright..console.fg.magenta, tostring(x))
end
local function pretty(x, long)
	local t = type(x)
	
	if prettyprint[t] and not (getmetatable(x) or {}).__tostring then
		return prettyprint[t](x, long)..resultstyle
	else
		return nop(x)..resultstyle
	end
end
local function prettykey(x)
	if type(x) == "string" and x:match("^[%a_][%w_]*$") then
		return tostring(x)
	else
		return "["..pretty(x).."]"
	end
end

prettyprint["nil"] = function(x) return console.reset..console.fg.grey..tostring(x) end
prettyprint["number"] = function(x) return console.reset..console.fg.cyan..tostring(x) end
prettyprint["string"] = function(x) return console.reset..console.fg.green..'"'..x..'"' end
prettyprint["boolean"] = function(x) return console.reset..console.fg.yellow..tostring(x) end
prettyprint["table"] = function(x, long)
	if type(x) ~= "table" and not (getmetatable(x) or {}).__pairs then
		return prettyprint.error("not a table")
	end
	if not long then return special(x) end
	
	local contents = {}
	
	if type(x) == "table" then
		for _, v in ipairs(x) do
			table.insert(contents, pretty(v))
		end
	end
	
	for k, v in pairs(x) do
		if not contents[k] then
			table.insert(contents, prettykey(k).." = "..pretty(v))
		end
	end
	
	return resultstyle.."{ "..table.concat(contents, ", ").." }"
		..(getmetatable(x) and console.fg.grey.." + mt" or "")
end
prettyprint["function"] = function(x, long)
	if type(x) ~= "function" then return prettyprint.error("not a function") end
	local d = debug.getinfo(x, "S")
	local filename = d.short_src:match("([^/]+)$")
	local str = string.format("%s[%s @ %s:%d]",
		console.bright..console.fg.magenta, tostring(x), filename, d.linedefined)
		
	if not long or d.source:sub(1,1) ~= "@" or d.source == "@stdin" then
		return str
	end
	
	local file = io.open(d.short_src)
	local contents = {}
	local i = 1
	for line in file:lines() do
		if i >= d.linedefined then
			if i > d.lastlinedefined then break end
			table.insert(contents, line)
		end
		i = i+1
	end
	file:close()
	return str..resultstyle.."\n"..table.concat(contents, "\n")
end
prettyprint["thread"] = special
prettyprint["userdata"] = special

prettyprint["error"] = function(x)
	return console.bright..console.fg.red..tostring(x)
end

prettyprint["trace"] = function(x)
	return string.format("%s (%s%s%s) %s",
		x.name or x.source, console.fg.cyan, x.namewhat, resultstyle,
		prettyprint["function"](x.func))
end



local commands = {}

function commands.table(arg)
	local tbl = _G[arg]
	if not tbl then return end
	print(prettyprint.table(tbl, true))
end

function commands.metatable(arg)
	local mt = getmetatable(_G[arg])
	if not mt then return end
	print(prettyprint.table(mt, true))
end

commands["function"] = function(arg)
	local fn = _G[arg]
	if not fn then return end
	print(prettyprint["function"](fn, true))
end

function commands.require(arg)
	local has = package.loaded[arg]
	if has then package.loaded[arg] = nil end
	local success, result = pcall(require, arg)
	if success then
		_G[arg] = result
	else
		print(prettyprint.error(result))
	end
end

function commands.trace(arg)
	if arg == "start" or arg == "on" then
		dotrace = true
	elseif arg == "stop"  or arg == "off" then
		dotrace = false
	end
end

function commands.help(arg)
	print("Available commands:")
	print("  :table, :t <table>")
	print("  :metatable, :mt <object>")
	print("  :function, :fn, :f <function>")
	print("  :require <modulename>")
	print("  :trace <on|start|off|stop>")
	print("  :help, :?")
	print("  :exit, :quit, :q")
end

function commands.exit()
	os.exit()
end

commands.t = commands.table
commands.mt = commands.metatable
commands.fn = commands["function"]
commands.f = commands["function"]
commands.m = commands.require
commands["?"] = commands.help
commands.quit = commands.exit
commands.q = commands.exit



local function onerror(err)
	print(debug.traceback(prettyprint.error(err), 2))
end

local function result(success, ...)
	debug.sethook() -- Reset debug hook
	local t = {...}
	
	-- Error case has already been handled by onerror via xpcall
	if not success then return end
	
	-- Print results
	for i = 1, select("#", ...) do
		print(pretty(t[i], true))
	end
	
	-- Print debug trace
	local level = 0
	for i = 4, #trace-3 do
		if trace[i].type == "return" then
			level = level-1
		elseif trace[i].type == "call" then
			print(resultstyle
				..string.rep("\u{2502} ", level).."\u{251c}\u{2574}"
				..prettyprint.trace(trace[i]))
			level = level+1
		end
	end
end

local function multiline(input)
	local fn, err = load(input, "=stdin", "t")
	while not fn and string.match(err, "<eof>$") do
		io.write(console.reset, "... ")
		local newinput = io.read()
		if not newinput then print() os.exit() end
		input = input.."\n"..newinput
		fn, err = load(input, "=stdin", "t")
	end
	return fn, err
end

local function hook(type)
	local d = debug.getinfo(2)
	d.type = type
	table.insert(trace, d)
end

while true do
	io.write(console.reset, "> ")
	local input = io.read()
	if not input then print() os.exit() end
	local command, args = input:match("^:(%S+)%s*(.*)$")
	if command and commands[command] then
		commands[command](args)
	else
		local fn, err = load("return "..input, "=stdin", "t")
		if not fn then fn, err = multiline(input) end
		if not fn then
			print(prettyprint.error(err))
		else
			trace = {}
			if dotrace then debug.sethook(hook, "cr") end
			result(xpcall(fn, onerror))
		end
	end
end
