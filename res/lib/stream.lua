--[[--
	
	Arbitrary data streams.
	
	@module stream
	@author RedPolygon
	
]]--

local stream = {}



-- DEFAULTS (for internal use)

stream.__index = stream
stream.__call = function(x, ...) return x.new(...) end

function stream:has()
	return self.source:has()
end



-- SOURCES

--- Auto-detect stream source type.
-- You can also just call `stream(data)` immediately.
-- @param data
-- @treturn Stream
function stream.new(data)
	local t = type(data)
	if t == "string" then
		return stream.string(data)
	elseif t == "table" then
		return stream.table(data)
	elseif t == "userdata" and getmetatable(data) == getmetatable(io.stdin) then
		return stream.file(data)
	else -- for generator functions or arbitrary data (numbers, booleans, userdata)
		return stream.generate(data)
	end
end



stream.string = {}

stream.string.__index = stream.string
stream.string.__tostring = function(self)
	return string.format("%s String", stream)
end

--- Stream string source.
-- When nothing is given, defaults to an empty string.
-- @function string
-- @tparam[opt] string data
-- @treturn Stream
-- @usage stream.string("hello"):totable() --> {'h','e','l','l','o'}
function stream.string.new(data)
	local self = {}
	self.data = data or ""
	self.i = 1
	
	return setmetatable(self, stream.string)
end

function stream.string:has()
	return self.i <= #self.data
end

function stream.string:get()
	if not self:has() then return end
	self.i = self.i+1
	return self.data:sub(self.i-1,self.i-1)
end

setmetatable(stream.string, stream)



stream.file = {}

stream.file.__index = stream.file
stream.file.__tostring = function(self) 
	if self.file == io.stdin then
		return string.format("%s File (stdin)", stream)
	elseif self.path then
		return string.format("%s File %q", stream, self.path)
	else
		return string.format("%s File", stream)
	end
end

--- Stream file source.
-- When `source` is a string, interprets it as a path.
-- Otherwise, `source` needs to be an already opened file.
-- @function file
-- @tparam[opt=io.stdin] string|file source
-- @treturn Stream
function stream.file.new(file)
	local self = {}
	if type(file) == "string" then
		self.path = file
		self.file = io.open(file, "rb")
	else
		self.file = file or io.stdin
	end
	self.buffer = nil
	self.started = false
	
	return setmetatable(self, stream.file)
end

function stream.file:buf()
	self.started = true
	self.buffer = self.file:read(1)
end

function stream.file:has()
	if not self.started then self:buf() end
	return self.buffer ~= nil
end

function stream.file:get()
	if not self.started then self:buf() end
	local x = self.buffer
	self:buf()
	return x
end

setmetatable(stream.file, stream)



stream.table = {}

stream.table.__index = stream.table
stream.table.__tostring = function(self)
	return string.format("%s Table", stream)
end

--- Stream table source.
-- When nothing is given, defaults to an empty table.
-- @function table
-- @tparam[opt] table data
-- @treturn Stream
-- @usage stream.table({'h','e','l','l','o'}):tostring() --> "hello"
function stream.table.new(data)
	local self = {}
	self.data = data or {}
	
	return setmetatable(self, stream.table)
end

function stream.table:has()
	return #self.data > 0
end

function stream.table:get()
	if not self:has() then return end
	return table.remove(self.data, 1)
end

setmetatable(stream.table, stream)



stream.generate = {}

stream.generate.__index = stream.generate
stream.generate.__tostring = function(self)
	if self.value then
		return string.format("%s Generate %q", stream, self.value)
	else
		return string.format("%s Generate", stream)
	end
end

--- Stream generator function or value source.
-- When `data` is a function, repeatedly calls this function for values.
-- Otherwise, yields `data` repeatedly.
-- @function generate
-- @tparam function|any data
-- @treturn Stream
-- @usage stream.generate(math.random):take(2):totable() --> {0.84018771676347, 0.39438292663544}
function stream.generate.new(fn)
	local self = {}
	if type(fn) == "function" then
		self.fn = fn
	else
		self.value = fn
		self.fn = function() return fn end
	end
	
	return setmetatable(self, stream.generate)
end

function stream.generate:has()
	return true -- TODO: implement
end

function stream.generate:get()
	return self.fn()
end

setmetatable(stream.generate, stream)



--- Stream number source.
-- Generates all integers counting up from `num`.
-- Alias for
-- 	generate(function()
-- 		num = num+1
-- 		return num-1
-- 	end)
-- @function from
-- @tparam number num
-- @treturn Stream
-- @see generate
-- @usage stream.from(1):take(5):totable() --> {1,2,3,4,5}
function stream.from(v)
	return setmetatable(stream.generate(function() v = v+1 return v-1 end), {
		__index = stream.generate,
		__tostring = function()
			return string.format("%s From %q", stream, v)
		end
	})
end



-- FILTERS

--- @type Stream

--- Whether the stream has data.
-- @function has
-- @treturn boolean whether the stream has data

--- Get a single value from the stream.
-- @function get
-- @return the value from the stream

stream.map = {}

stream.map.__index = stream.map
stream.map.__tostring = function(self)
	return string.format("%s -> Map", self.source)
end

--- Perform a function on every value.
-- The function will be called with every value from the source,
-- the result of this function will be passed on.
-- @function map
-- @tparam function fn
-- @treturn Stream
-- @usage stream.string("12345"):map(tonumber):totable() --> {1,2,3,4,5}
function stream.map.new(source, fn)
	local self = {}
	self.source = source
	self.fn = fn or function(...) return ... end
	
	return setmetatable(self, stream.map)
end

function stream.map:get()
	if not self.source:has() then return end
	return (self.fn( (self.source:get()) ))
end

setmetatable(stream.map, stream)



stream.forEach = {}

stream.forEach.__index = stream.forEach
stream.forEach.__tostring = function(self)
	return string.format("%s -> ForEach", self.source)
end

--- Perform a function on every value, but ignore the result.
-- @function forEach
-- @tparam function fn
-- @treturn Stream
-- @usage stream.string("123"):forEach(print):null()
-- --> 1
-- --> 2
-- --> 3
function stream.forEach.new(source, fn)
	local self = {}
	self.source = source
	self.fn = fn or function() end
	
	return setmetatable(self, stream.forEach)
end

function stream.forEach:get()
	if not self.source:has() then return end
	local x = self.source:get()
	self.fn(x)
	return x
end

setmetatable(stream.forEach, stream)



stream.filter = {}

stream.filter.__index = stream.filter
stream.filter.__tostring = function(self)
	return string.format("%s -> Filter", self.source)
end

--- Filter the stream.
-- The function will be called with every value from its source,
-- and the value will only be passed on when it returns true.
-- @function filter
-- @tparam function fn
-- @treturn Stream
-- @usage
-- stream.string("AbCdEf"):filter(stream.util.match("%l")):tostring() --> "bdf"
function stream.filter.new(source, fn)
	local self = {}
	self.source = source
	self.fn = fn or function() return true end
	self.buffer = nil
	self.started = false
	
	return setmetatable(self, stream.filter)
end

function stream.filter:buf()
	self.started = true
	
	repeat
		if not self.source:has() then self.buffer = nil return end
		self.buffer = self.source:get()
	until self.fn(self.buffer)
end

function stream.filter:has()
	if not self.started then self:buf() end
	return self.buffer ~= nil
end

function stream.filter:get()
	if not self.started then self:buf() end
	local x = self.buffer
	self:buf()
	return x
end

setmetatable(stream.filter, stream)



stream.reverse = {}

stream.reverse.__index = stream.reverse
stream.reverse.__tostring = function(self)
	return string.format("%s -> Reverse", self.source)
end

--- Reverse the stream.
-- **Warning**: this function needs to read the entire source stream
-- before it can return any value. Will not work for infinite streams.
-- @function reverse
-- @treturn Stream
-- @usage stream.string("hello"):reverse():tostring() --> "olleh"
function stream.reverse.new(source)
	local self = {}
	self.source = source
	self.data = nil
	
	return setmetatable(self, stream.reverse)
end

function stream.reverse:has()
	if self.data then
		return #self.data > 0
	else
		return self.source:has()
	end
end

function stream.reverse:init()
	self.data = {}
	while self.source:has() do
		table.insert(self.data, self.source:get())
	end
end

function stream.reverse:get()
	if not self.data then self:init() end
	return table.remove(self.data)
end

setmetatable(stream.reverse, stream)



stream.take = {}

stream.take.__index = stream.take
stream.take.__tostring = function(self)
	return string.format("%s -> Take %s", self.source, self.n)
end

--- Take the first `n` values.
-- @function take
-- @tparam[opt=1] number n
-- @treturn Stream
function stream.take.new(source, n)
	local self = {}
	self.source = source
	self.i = 0
	self.n = n or 1
	
	return setmetatable(self, stream.take)
end

function stream.take:has()
	return self.i < self.n and self.source:has()
end

function stream.take:get()
	if not self:has() then return end
	self.i = self.i+1
	return self.source:get()
end

setmetatable(stream.take, stream)

--- Alias for @{take}.
-- @function head
-- @see take
stream.head = stream.take



--- Take the last `n` values.
-- This is an alias for `reverse():head(n):reverse()`,
-- and as such also doesn't work for infinite streams.
-- @function tail
-- @tparam[opt=1] number n
-- @treturn Stream
-- @see reverse, head
function stream.tail(source, n)
	return setmetatable(source:reverse():head(n):reverse(), {
		__index = stream.reverse,
		__tostring = function(self)
			return string.format("%s -> Tail %d", source, n)
		end
	})
end



stream.takeWhile = {}

stream.takeWhile.__index = stream.takeWhile
stream.takeWhile.__tostring = function(self)
	return string.format("%s -> TakeWhile", self.source)
end

--- Pass the input values along until the condition isn't met.
-- Uses the function `fn` in the same way as @{filter}.
-- @function takeWhile
-- @tparam function fn
-- @treturn Stream
-- @see op
-- @usage stream.table({1,2,3,4,3,2,1})
-- 	:takeWhile(stream.op.lt(4))
-- 	:totable() --> {1,2,3}
function stream.takeWhile.new(source, fn)
	local self = {}
	self.source = source
	self.fn = fn
	self.buffer = nil
	self.started = false
	
	return setmetatable(self, stream.takeWhile)
end

function stream.takeWhile:buf()
	self.started = true
	self.buffer = self.source:get()
	if not self.fn(self.buffer) then self.buffer = nil end
end

function stream.takeWhile:has()
	if not self.started then self:buf() end
	return self.buffer ~= nil
end

function stream.takeWhile:get()
	if not self.started then self:buf() end
	if not self.buffer or not self.fn(self.buffer) then
		self.buffer = nil
		return
	end
	local x = self.buffer
	self:buf()
	return x
end

setmetatable(stream.takeWhile, stream)



stream.group = {}

stream.group.__index = stream.group
stream.group.__tostring = function(self)
	return string.format("%s -> Group", self.source)
end

--- Group values into streams.
-- Uses the function `fn` in the same way as @{filter},
-- but passes the previous value as a second parameter.
-- Returns a `Stream` of `Streams`.
-- @function group
-- @tparam function fn
-- @treturn Stream
-- @usage stream.table({1,2,1,3,2,2})
-- 	:group(function(x, prev) return not prev or x >= prev end)
-- 	:map(function(s) return s:tostring() end) -- s is a Stream here
-- 	:totable() --> {"12","13","22"}
function stream.group.new(source, fn)
	local self = {}
	self.source = source
	self.fn = fn or function() return true end
	self.buffer = nil
	
	return setmetatable(self, stream.group)
end

function stream.group:get()
	local buffer = {self.buffer}
	while self.source:has() do
		local x = self.source:get()
		if self.fn(x, buffer[#buffer]) then
			table.insert(buffer, x)
		elseif #buffer > 0 then -- prevent empty groups
			self.buffer = x
			return stream.table(buffer)
		end
	end
	return stream.table(buffer)
end

setmetatable(stream.group, stream)



--- Pass all values until the value `at` is reached.
-- Alias for `takeWhile(function(x) return x ~= at end)`
-- @function stopAt
-- @param at
-- @treturn Stream
-- @see takeWhile
-- @usage stream.string("hello world"):stopAt("r"):tostring() --> "hello wo"
function stream.stopAt(source, at)
	return setmetatable(source:takeWhile(stream.op.neq(at)), {
		__index = stream.takeWhile,
		__tostring = function(self)
			return string.format("%s -> StopAt %q", source, at)
		end,
	})
end



--- Map numbers from (`min1`,`max1`) to (`min2`,`max2`).
-- Alias for
-- 	map(function(x)
-- 		return min2 + (x-min1) / (max1-min1) * (max2-min2)
-- 	end)
-- @function mapRange
-- @tparam number min1
-- @tparam number max1
-- @tparam number min2
-- @tparam number max2
-- @treturn Stream
-- @see map
-- @usage stream.generate(math.random)
-- 	:mapRange(0,1,0,10):map(math.floor)
-- 	:take(2):totable() --> {8,3}
function stream.mapRange(source, min1, max1, min2, max2)
	return setmetatable(source:map(function(x) return min2 + (x-min1)/(max1-min1)*(max2-min2) end), {
		__index = stream.map,
		__tostring = function()
			return string.format("%s -> MapRange (%d,%d) to (%d,%d)", source, min1, max1, min2, max2)
		end
	})
end

--- Map table or string indices to values.
-- @function mapIndex
-- @tparam table|string t
-- @treturn Stream
-- @see map
-- @usage stream.generate(math.random)
-- 	:mapRange(0,1,1,16):mapIndex("0123456789abcdef")
-- 	:take(5):tostring() --> "d16c2"
function stream.mapIndex(source, t)
	local f
	if type(t) == "string" then
		f = function(x) return string.sub(t, math.floor(x), math.floor(x)) end
	else
		f = function(x) return t[math.floor(x)] end
	end
	return setmetatable(source:map(f), {
		__index = stream.map,
		__tostring = function()
			return string.format("%s -> MapIndex", source)
		end
	})
end



-- SINKS

--- Discard the stream result, just pump all values.
-- @function null
function stream.null(source)
	while source:has() do
		source:get()
	end
end

--- Reduce the stream values into a single value.
-- @function reduce
-- @tparam function fn
-- @param[opt] acc
-- @return acc
-- @usage stream.table({1,2,3,4,5}):reduce(op.add) --> 15
function stream.reduce(source, fn, acc)
	if not source:has() then return acc end
	acc = acc or source:get()
	while source:has() do
		acc = fn(acc, source:get())
	end
	return acc
end

--- Reduce the stream to a table.
-- Alias for
-- 	reduce(function(a, x)
-- 		table.insert(a, x)
-- 		return a
-- 	end, {})
-- @function totable
-- @treturn table
-- @see reduce
-- @usage stream.string("hello"):totable() --> {'h','e','l','l','o'}
function stream.totable(source)
	return source:reduce(function(a, x) table.insert(a, x) return a end, {})
end

--- Reduce the stream to a string.
-- Alias for `table.concat(source:totable())`
-- @function tostring
-- @treturn string
-- @see totable
-- @usage stream.table({'h','e','l','l','o'}):tostring() --> "hello"
function stream.tostring(source)
	return table.concat(source:totable())
end

--- Get the stream length.
-- Alias for `reduce(function(a) return a+1 end, 0)`
-- @function length
-- @treturn number
-- @see reduce
-- @usage stream.string("hello world"):stopAt("r"):length() --> 8
function stream.length(source)
	return source:reduce(function(a) return a+1 end, 0)
end

--- Perform `fn` on all values, but ignore the stream result.
-- Alias for `forEach(fn):null()`
-- @function forAll
-- @tparam function fn
-- @see forEach
-- @see null
-- @usage stream.string("abc"):forAll(print)
-- --> a
-- --> b
-- --> c
function stream.forAll(source, fn)
	return source:forEach(fn):null()
end

--- Returns whether **any** of the values fit the constraint `fn`.
-- @function any
-- @tparam function fn
-- @treturn boolean
-- @see all
-- @see op
-- @usage stream.string("hello world"):any(stream.op.eq(" ")) --> true
function stream.any(source, fn)
	fn = fn or function() return true end
	while source:has() do
		if fn(source:get()) then return true end
	end
	return false
end

--- Returns whether **all** of the values fit the constraint `fn`.
-- @function all
-- @tparam function fn
-- @treturn boolean
-- @see any
-- @see op
-- @usage stream.generate(math.random):take(5):all(stream.op.gt(0.2))
-- --> true (or false, I don't know)
function stream.all(source, fn)
	fn = fn or function() return true end
	while source:has() do
		if not fn(source:get()) then return false end
	end
	return true
end



-- UTILITY FUNCTIONS

--- Utility functions.
-- @section stream.util

stream.util = {}

--- Wrapper for `string.match`.
-- @usage
-- filter(stream.util.match("%l"))
-- -- is equivalent to (but half as long as)
-- filter(function(x) return string.match(x, "%l") end)
function stream.util.match(match)
	return function(x) return string.match(x, match) end
end

--- Wrap a regular 2-parameter function into a curried variant
-- @usage
-- filter(stream.util.curry(op.eq)(1))
-- -- is equivalent to
-- filter(function(x) return op.eq(x,1) end)
function stream.util.curry(f)
	return function(b) return function(a) return f(a,b) end end
end



-- CURRIED OPERATORS

--- Operators
-- @section op

--- Curried `operator` library proxy.
-- @table stream.op
-- This table will only be present when the `operator` library is.
-- `stream.op.eq == stream.util.curry(operator.eq)`

local success, op = pcall(require, "operator")

if success then
	stream.op = setmetatable({}, {__index = function(t,k)
		return stream.util.curry(op[k])
	end})
end



-- RETURN

return setmetatable(stream, {
	__name = "Stream",
	__tostring = function() return "Stream:" end,
	__call = function(_, ...) return stream.new(...) end,
})