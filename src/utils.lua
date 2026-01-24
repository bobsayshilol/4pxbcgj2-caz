local clamp = function(x, l, h)
    return math.max(math.min(x, h), l)
end

-- https://love2d.org/wiki/love.math.random
local shuffle = function(list)
	-- backward iteration from last to second element:
	for i = #list, 2, -1 do
		-- choose one of elements:
		local j = love.math.random(i) -- between 1 to i (both inclusive)
		-- replace both elements each other:
		list[i], list[j] = list[j], list[i]
	end
end

local sign = function(s)
    if s > 0 then return 1
    elseif s < 0 then return -1
    else return 0
    end
end

local size = function(t)
    local i = 0
    for _ in pairs(t) do i = i + 1 end
    return i
end

return {
    clamp = clamp,
    shuffle = shuffle,
    sign = sign,
    size = size,
}
