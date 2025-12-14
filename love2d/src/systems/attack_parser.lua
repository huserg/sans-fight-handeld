-- Attack Parser
-- Parses attack CSV files from C2 export format

local AttackParser = {}

-- Command types that are currently implemented
AttackParser.implementedCommands = {
    -- Fully implemented
    "EndAttack",
    "HeartMode",
    "HeartTeleport",
    "CombatZoneResize",
    "CombatZoneResizeInstant",
    "TLPause",
    "TLResume",
    -- Partially implemented (bones)
    "BoneV",
    "BoneH",
    "BoneVRepeat",
    "BoneHRepeat",
}

-- Commands that need implementation
AttackParser.notImplementedCommands = {
    "SansAnimation",
    "SansHead",
    "SansBody",
    "SansText",
    "SansSlam",
    "BlackScreen",
    "Sound",
    "BoneStab",
    "SineBones",
    "GasterBlaster",
    "Platform",
    "BoneSlideV",
    "BoneSlideH",
    "BlueStop",
}

function AttackParser.parseCSV(content)
    local events = {}

    for line in content:gmatch("[^\r\n]+") do
        local event = AttackParser.parseLine(line)
        if event then
            table.insert(events, event)
        end
    end

    return events
end

function AttackParser.parseLine(line)
    local parts = {}
    for part in (line .. ","):gmatch("([^,]*),") do
        table.insert(parts, part)
    end

    if #parts < 2 then
        return nil
    end

    local event = {
        time = tonumber(parts[1]) or 0,
        command = parts[2],
        params = {}
    }

    -- Store remaining parameters
    for i = 3, #parts do
        local value = parts[i]
        -- Try to convert to number
        local num = tonumber(value)
        if num then
            table.insert(event.params, num)
        else
            table.insert(event.params, value)
        end
    end

    return event
end

function AttackParser.loadFromFile(path)
    local content = love.filesystem.read(path)
    if not content then
        print("Failed to load attack file: " .. path)
        return nil
    end
    return AttackParser.parseCSV(content)
end

function AttackParser.analyzeAttack(events)
    local usedCommands = {}
    local notImplemented = {}

    for _, event in ipairs(events) do
        usedCommands[event.command] = true
    end

    -- Check which commands are not implemented
    for cmd, _ in pairs(usedCommands) do
        local found = false
        for _, impl in ipairs(AttackParser.implementedCommands) do
            if cmd == impl then
                found = true
                break
            end
        end
        if not found then
            notImplemented[cmd] = true
        end
    end

    return {
        commands = usedCommands,
        notImplemented = notImplemented,
        isReady = next(notImplemented) == nil
    }
end

function AttackParser.getAttackStatus(attackName)
    local path = "attacks/" .. attackName .. ".csv"
    local events = AttackParser.loadFromFile(path)

    if not events then
        return "missing"
    end

    local analysis = AttackParser.analyzeAttack(events)
    if analysis.isReady then
        return "ready"
    else
        return "partial"
    end
end

return AttackParser
