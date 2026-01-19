local clamp = function(x, l, h)
    return math.max(math.min(x, h), l)
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
    sign = sign,
    size = size,
}
