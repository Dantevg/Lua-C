local stream = require "stream"
local value = require "value"
local op = require "operator"
local base64 = require "base64"

math.randomseed(os.time())

function rot(n)
	return function(c)
		local x = value.of(c)
		if x >= "A" and x <= "Z" then
			return (x-"A"+n) % 26 + "A"
		elseif x >= "a" and x <= "z" then
			return (x-"a"+n) % 26 + "a"
		else
			return x
		end
	end
end

-- for x in stream(math.random):filter(stream.op.gt(0.5)):take(3) do
-- 	print(x)
-- end

-- for x in stream("Hello, World!"):group(stream.util.match("%l")):map(stream.string) do
-- 	print(x)
-- end

-- Rot13
print(stream("Hello, World!"):map(rot(13)):string())

-- All alphabetic characters
local alpha = stream.from(32)
	:map(string.char)
	:filter(stream.util.match("%a"))
	:take(52)
	:table()
print(table.concat(alpha))

-- Other small tests
print(stream(math.random):mapRange(0,1,1,16):mapIndex("0123456789abcdef"):take(5):string())
print(stream("Hello, World!"):stopAt("r"):string())
print(stream({1,2,3,4,5}):reduce(op.add))

-- String parsing (pretty long code in comparison to plain Lua)
local t = stream("hello=world,foo=bar")
	:splitAt(",")
	:map(function(x)
		return x
			:splitAt("=")
			:map(stream.string)
			:table()
	end)
	:table()

for _, v in ipairs(t) do
	print(table.concat(v, ", "))
end
