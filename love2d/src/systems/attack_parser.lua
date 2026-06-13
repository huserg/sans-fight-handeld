-- Attack Parser
-- Parses attack CSV files from C2 export format

local AttackParser = {}

-- Commands the sequencer executes (keep in sync with attack_sequencer.lua
-- handlers and attack_vm.lua opcodes; labels/:Name and NOP are intrinsic)
AttackParser.implementedCommands = {
    "EndAttack",
    "HeartMode",
    "HeartTeleport",
    "CombatZoneResize",
    "CombatZoneResizeInstant",
    "TLPause",
    "TLResume",
    "BoneV",
    "BoneH",
    "BoneVRepeat",
    "BoneHRepeat",
    "GasterBlaster",
    "Sound",
    "BlackScreen",
    "SansText",
    "GetHeartPos",
    "Platform",
    "PlatformRepeat",
    "BoneStab",
    "SineBones",
    "HeartMaxFallSpeed",
    "CombatZoneSpeed",
    "SansAnimation",
    "SansHead",
    "SansBody",
    "SansTorso",
    "SansSweat",
    "SansX",
    "SansRepeat",
    "SansEndRepeat",
    "SansSlam",
    "SansSlamDamage",
    -- VM opcodes
    "SET", "ADD", "SUB", "MUL", "DIV", "MOD", "FLOOR",
    "DEG", "RAD", "SIN", "COS", "ANGLE", "RND",
    "JMPABS", "JMPREL", "JMPZ", "JMPNZ",
    "JMPE", "JMPNE", "JMPL", "JMPNL", "JMPG", "JMPNG",
}

-- Commands that still need implementation
AttackParser.notImplementedCommands = {
    "BlueStop",
}

function AttackParser.parseCSV(content)
    local events = {}
    local labels = {}

    -- One event per physical line: absolute jump targets are line numbers
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        local event = AttackParser.parseLine(line)
            or { time = 0, command = "NOP", params = {} }
        table.insert(events, event)

        if event.command:sub(1, 1) == ":" then
            labels[event.command:sub(2)] = #events
        end
    end

    -- Trailing blank lines would add dead frames after EndAttack
    while #events > 0 and events[#events].command == "NOP" do
        table.remove(events, #events)
    end

    return events, labels
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
        local cmd = event.command
        if cmd ~= "NOP" and cmd:sub(1, 1) ~= ":" then
            usedCommands[cmd] = true
        end
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
