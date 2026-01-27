-- navMesh = {{center}, {extent}, {links}},



local nodeDist = function(n1, n2)
    local x1,y1 = n1[1][1],n1[1][2]
    local x2,y2 = n2[1][1],n2[1][2]
    local dx,dy = x2-x1,y2-y1
    return math.sqrt(dx*dx+dy*dy)
end



local navMeshInside = function(navMesh, x,y, nodeID)
    local node = navMesh[nodeID]
    if node == nil then return false end
    local center,extent = node[1],node[2]
    local dx,dy = x-center[1],y-center[2]
    return math.abs(dx) <= extent[1] and math.abs(dy) <= extent[2]
end



local navMeshFind = function(navMesh, x,y)
    for idx,nm in ipairs(navMesh) do
        local center,extent = nm[1],nm[2]
        local dx,dy = x-center[1],y-center[2]
        if math.abs(dx) <= extent[1] and math.abs(dy) <= extent[2] then
            return idx
        end
    end
    return nil
end



-- Not tested, not fully implemented.
local navMeshDirTo = function(navMesh, x1,y1, x2,y2)
    local id1 = navMeshFind(navMesh, x1,y1)
    local id2 = navMeshFind(navMesh, x2,y2)

    -- Both in the same region.
    -- nil shouldn't happen if navMesh is setup proper.
    if id1 == nil or id2 == nil or id1 == id2 then
        return x2-x1,y2-y1
    end

    -- Find the full path from xy1 to xy2 using A*.
    local inf = 1000000000
    local h = function(node)
        local a,b = node[1]
        local dx,dy = a-x2,b-y2
        return dx*dx+dy*dy
    end
    local closest = function(ns, fs)
        -- TODO: prioQ
        local max = 2*inf
        local c = nil
        for n,_ in pairs(ns) do
            local d = fs[n] or inf
            if d < max then
                max = d
                c = n
            end
        end
        return c
    end

    local startNode = {{x1,y1}, {1,1}, navMesh[id1][3]}
    local pendNode = navMesh[id2]
    local endNode = {{x2,y2}, {1,1}, pendNode[3]}

    local active = {}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}

    active[startNode] = true
    gScore[startNode] = 0
    fScore[startNode] = h(start)

    local found = false
    while true do
        local node = closest(active, fScore)
        if node == endNode then
            found = true
            break
        end

        active[node] = nil
        for _,i in pairs(node[3]) do
            local neighbour = navMesh[i]

            -- Replace the last node with the final position.
            if neighbour == pendNode then
                neighbour = endNode
            end

            local tscore = (gScore[node] or inf) + nodeDist(node, neighbour)
            if tscore < (gScore[neighbour] or inf) then
                cameFrom[neighbour] = node
                gScore[neighbour] = tscore
                fscore[neighbour] = tscore + h(neighbour)
                active[neighbour] = true
            end
        end
    end

    -- Shouldn't happen.
    if not found then
        return x2-x1,y2-y1
    end

    -- Unwind the path.
    local node = endNode
    while true do
        local n = cameFrom[node]
        if n == startNode then
-- TODO
        end
        node = n
    end
end



local navMeshBuildLookup = function(navMesh, players)
    local distances = {}
    local inf = 1000000000

    -- Shouldn't be needed since we're flood filling.
    for idx,nm in ipairs(navMesh) do
        distances[idx] = inf
    end

    for pid,player in ipairs(players) do
        local pb = player.body
        local x,y = pb:getX(),pb:getY()
        local navID = navMeshFind(navMesh, x,y)
        if navID ~= nil then
            -- Flood fill.
            local batch = {}
            distances[navID] = 0

            -- Start from the links rather than the center of the current region.
            local fakeStart = {{x,y},}
            local node = navMesh[navID]
            for _,nodeID in ipairs(node[3]) do
                batch[#batch+1] = nodeID
                local nNode = navMesh[nodeID]
                distances[nodeID] = nodeDist(fakeStart, nNode)
            end

            while true do
                local nextBatch = {}
                for _,currentID in ipairs(batch) do
                    local current = navMesh[currentID]
                    local curDist = distances[currentID]
                    local links = current[3]
                    for _,neighbourID in ipairs(links) do
                        -- See if this node is closer.
                        local nNode = navMesh[neighbourID]
                        local nDist = distances[neighbourID] or inf
                        local t = curDist + nodeDist(current, nNode)
                        if nDist > t then
                            -- Update score and search from there.
                            distances[neighbourID] = t
                            nextBatch[#nextBatch+1] = neighbourID
                        end
                    end
                end
                if #nextBatch == 0 then break end
                batch = nextBatch
            end
        end
    end

    return distances
end



local navMeshQuery = function(navMesh, lookup, players, x,y)
    local navID = navMeshFind(navMesh, x,y)
    if navID == nil then
        return nil,nil
    end

    -- Finds the closest player in given node.
    local closestPlayerDir = function(nodeID)
        local closest = 1000000000
        local dx,dy = nil,nil
        for _,player in ipairs(players) do
            local b = player.body
            local tx,ty = b:getX(),b:getY()
            if player.health > 0 and navMeshInside(navMesh, tx,ty, nodeID) then
                local ax,ay = tx-x,ty-y
                local d = ax*ax+ay*ay
                if d < closest then
                    closest = d
                    dx,dy = ax,ay
                end
            end
        end
        return dx,dy
    end

    -- See if we're in the same region as a player.
    if lookup[navID] == 0 then
        return closestPlayerDir(navID)
    end

    -- Find the best neighbour.
    local fakeStart = {{x,y},}
    local node = navMesh[navID]
    local links = node[3]
    local max = 1000000000
    local bestNode = nil
    for _,nodeID in ipairs(links) do
        local nNode = navMesh[nodeID]
        local dToPlayer = lookup[nodeID]
        -- If this node contains a player then go to them.
        if dToPlayer == 0 then
            return closestPlayerDir(nodeID)
        end
        -- Otherwise add on the time it'd take to get to that node.
        dToPlayer = nodeDist(fakeStart, nNode) + dToPlayer
        if dToPlayer < max then
            max = dToPlayer
            bestNode = nNode
        end
    end

    -- Shouldn't happen.
    if bestNode == nil then
        return nil,nil
    end

    -- Finally we have a node to aim for.
    local txy = bestNode[1]
    return txy[1]-x,txy[2]-y
end



return {
    inside = navMeshInside,
    find = navMeshFind,
    --dirTo = navMeshDirTo,
    buildLookup = navMeshBuildLookup,
    query = navMeshQuery,
}
