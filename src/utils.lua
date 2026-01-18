local clamp = function(x, l, h)
    return math.max(math.min(x, h), l)
end

local size = function(t)
    local i = 0
    for _ in pairs(t) do i = i + 1 end
    return i
end

return {
    clamp = clamp,
    size = size,
}
