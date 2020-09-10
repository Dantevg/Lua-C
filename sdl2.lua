scale = 8
frame = 0

function draw(t)
	frame = frame+1
	print( math.floor(frame / t * 1000) )
	
	for x = 1, math.floor(width/scale) do
		for y = 1, math.floor(height/scale) do
			colour(math.random(255), math.random(255), math.random(255), 255)
			pixel(x-1, y-1)
		end
	end
end