local csv = {}
function csv.parse(data)
  local lines = {}
  for line in data:gmatch("[^\r\n]+") do
    local row = {}
    for cell in (line .. ","):gmatch("([^,]*),") do
      table.insert(row, cell)
    end
    table.insert(lines, row)
  end
  return lines
end

local Script = {}
Script.__index = Script

local function toNumber(value)
  local n = tonumber(value)
  return n
end

local function resolveValue(value, vars)
  if value == nil or value == "" then return 0 end
  if type(value) == "number" then return value end
  if type(value) == "string" and value:sub(1, 1) == "$" then
    return vars[value:sub(2)] or 0
  end
  return tonumber(value) or value
end

local function atan2(y, x)
  if math.atan2 then
    return math.atan2(y, x)
  end
  return math.atan(y, x)
end

function Script.new(rawCSV, game)
  local self = setmetatable({}, Script)
  self.game = game
  self.vars = {}
  self.time = 0
  self.ip = 1
  self.instructions = {}
  self.labels = {}

  local rows = csv.parse(rawCSV)
  for idx, row in ipairs(rows) do
    local time = tonumber(row[1]) or 0
    local cmd = row[2]
    if cmd and cmd ~= "" then
      if cmd:sub(1, 1) == ":" then
        self.labels[cmd:sub(2)] = #self.instructions + 1
      end
      table.insert(self.instructions, {time = time, cmd = cmd, args = {select(3, unpack(row))}})
    end
  end
  return self
end

function Script:value(val)
  return resolveValue(val, self.vars)
end

function Script:setVar(name, value)
  self.vars[name] = value
end

function Script:jumpToLabel(label)
  local target = self.labels[label]
  if target then
    self.ip = target
    return true
  end
  return false
end

function Script:update(dt)
  self.time = self.time + dt
  while self.ip <= #self.instructions do
    local inst = self.instructions[self.ip]
    if inst.time > self.time + 1e-4 then break end
    local advanced = self:execute(inst)
    if not advanced then
      self.ip = self.ip + 1
    end
  end
end

local function numericOp(self, dest, a, b, op)
  local av, bv = self:value(a), self:value(b)
  self:setVar(dest, op(av, bv))
end

local function compare(self, a, b, fn)
  return fn(self:value(a), self:value(b))
end

function Script:execute(inst)
  local cmd = inst.cmd
  local args = inst.args
  local changed = false

  if cmd == "SET" then
    self:setVar(args[1], self:value(args[2]))
  elseif cmd == "ADD" then
    numericOp(self, args[1], args[2], args[3], function(a, b) return a + b end)
  elseif cmd == "SUB" then
    numericOp(self, args[1], args[2], args[3], function(a, b) return a - b end)
  elseif cmd == "MUL" then
    numericOp(self, args[1], args[2], args[3], function(a, b) return a * b end)
  elseif cmd == "DIV" then
    numericOp(self, args[1], args[2], args[3], function(a, b) return a / b end)
  elseif cmd == "MOD" then
    numericOp(self, args[1], args[2], args[3], function(a, b) return a % b end)
  elseif cmd == "FLOOR" then
    self:setVar(args[1], math.floor(self:value(args[2])))
  elseif cmd == "RND" then
    local max = math.max(1, math.floor(self:value(args[3])))
    self:setVar(args[2], love.math.random(0, max - 1))
  elseif cmd == "SIN" then
    self:setVar(args[1], math.sin(math.rad(self:value(args[2]))))
  elseif cmd == "COS" then
    self:setVar(args[1], math.cos(math.rad(self:value(args[2]))))
  elseif cmd == "ANGLE" then
    local x1, y1, x2, y2 = self:value(args[2]), self:value(args[3]), self:value(args[4]), self:value(args[5])
    self:setVar(args[1], atan2((y2 - y1), (x2 - x1)))
  elseif cmd == "GetHeartPos" then
    self:setVar(args[1], self.game.heart.x)
    self:setVar(args[2], self.game.heart.y)
  elseif cmd == "HeartTeleport" then
    self.game:teleportHeart(self:value(args[1]), self:value(args[2]))
  elseif cmd == "HeartMode" then
    self.game:setHeartMode(self:value(args[1]))
  elseif cmd == "HeartMaxFallSpeed" then
    self.game:setHeartMaxFallSpeed(self:value(args[1]))
  elseif cmd == "CombatZoneResize" or cmd == "CombatZoneResizeInstant" then
    self.game:resizeCombatZone(self:value(args[1]), self:value(args[2]), self:value(args[3]), self:value(args[4]))
  elseif cmd == "CombatZoneSpeed" then
    -- Ignored for now
  elseif cmd == "TLPause" then
    self.game:setTimelinePaused(true)
  elseif cmd == "TLResume" then
    self.game:setTimelinePaused(false)
  elseif cmd == "Sound" then
    -- no-op placeholder
  elseif cmd == "SansText" then
    self.game:setMessage(args[1])
  elseif cmd == "SansAnimation" or cmd == "SansBody" or cmd == "SansHead" then
    self.game:setSansPose(args[1])
    if cmd == "SansHead" then self.game:setSansHead(args[1]) end
  elseif cmd == "SansSweat" then
    self.game:setSansSweat(self:value(args[1]) ~= 0)
  elseif cmd == "SansX" then
    self.game:setSansPosition(self:value(args[1]))
  elseif cmd == "SansSlamDamage" then
    self.game:setSlamDamage(self:value(args[1]))
  elseif cmd == "BoneV" or cmd == "BoneH" then
    self.game:spawnBone({
      x = self:value(args[1]),
      y = self:value(args[2]),
      length = self:value(args[3]),
      dir = self:value(args[4]) or (cmd == "BoneH" and 1 or 0),
      speed = self:value(args[5])
    })
  elseif cmd == "BoneVRepeat" or cmd == "BoneHRepeat" then
    local count = self:value(args[6])
    local spacing = self:value(args[7])
    local dir = cmd == "BoneHRepeat" and 1 or 0
    for i = 0, count - 1 do
      local x = self:value(args[1]) + (dir == 1 and i * spacing or 0)
      local y = self:value(args[2]) + (dir == 0 and i * spacing or 0)
      self.game:spawnBone({
        x = x,
        y = y,
        length = self:value(args[3]),
        dir = self:value(args[4]),
        speed = self:value(args[5]),
      })
    end
  elseif cmd == "BoneStab" then
    local dir = self:value(args[1])
    local cz = self.game.combatZone
    local hx, hy = self.game.heart.x, self.game.heart.y
    local x, y
    if dir == 0 then -- from bottom
      x, y = hx, cz.y2
    elseif dir == 2 then -- from top
      x, y = hx, cz.y1
    elseif dir == 1 then -- from right
      x, y = cz.x2, hy
    else -- left
      x, y = cz.x1, hy
    end
    self.game:spawnBone({
      x = x,
      y = y,
      length = self:value(args[2]) * 8,
      dir = dir,
      delay = self:value(args[3]) or 0,
      stab = true,
    })
  elseif cmd == "Platform" or cmd == "PlatformRepeat" then
    local count = cmd == "PlatformRepeat" and self:value(args[5]) or 1
    local spacing = cmd == "PlatformRepeat" and self:value(args[6]) or 0
    for i = 0, count - 1 do
      self.game:spawnPlatform({
        x = self:value(args[1]) + i * spacing,
        y = self:value(args[2]),
        w = self:value(args[3]),
        dir = self:value(args[4]) or 0,
        speed = self:value(args[5]) or 0,
      })
    end
  elseif cmd == "GasterBlaster" then
    self.game:spawnGasterBlaster({
      x = self:value(args[2]),
      y = self:value(args[3]),
      tx = self:value(args[4]),
      ty = self:value(args[5]),
      angle = self:value(args[6]),
      charge = self:value(args[7]) or 0.5,
      beam = self:value(args[8]) or 0.2,
    })
  elseif cmd == "SansSlam" then
    -- shake or quick slam marker, currently treated as message
    self.game:setMessage("Slam!")
  elseif cmd == "SansRepeat" or cmd == "SansEndRepeat" then
    -- visual only
  elseif cmd == "EndAttack" then
    self.game:setMessage("Attack finished")
  elseif cmd == "JMPREL" then
    local offset = math.floor(self:value(args[1]))
    self.ip = math.max(1, self.ip + offset)
    changed = true
  elseif cmd == "JMPABS" then
    if self:jumpToLabel(args[1]) then changed = true end
  elseif cmd == "JMPZ" then
    if compare(self, args[3], 0, function(a, b) return a == b end) then
      if self:jumpToLabel(args[2]) then changed = true end
    end
  elseif cmd == "JMPNZ" then
    if compare(self, args[3], 0, function(a, b) return a ~= b end) then
      if self:jumpToLabel(args[2]) then changed = true end
    end
  elseif cmd == "JMPE" then
    if compare(self, args[2], args[3], function(a, b) return a == b end) then
      if self:jumpToLabel(args[1]) then changed = true end
    end
  elseif cmd == "JMPNE" then
    if compare(self, args[2], args[3], function(a, b) return a ~= b end) then
      if self:jumpToLabel(args[1]) then changed = true end
    end
  elseif cmd == "JMPL" then
    if compare(self, args[2], args[3], function(a, b) return a < b end) then
      if self:jumpToLabel(args[1]) then changed = true end
    end
  elseif cmd == "JMPNL" then
    if compare(self, args[2], args[3], function(a, b) return a >= b end) then
      local target = self.labels[args[1]] or self:value(args[1])
      if target then
        self.ip = target
        changed = true
      end
    end
  elseif cmd == "JMPNG" then
    if compare(self, args[2], args[3], function(a, b) return a <= b end) then
      local target = self.labels[args[1]] or self:value(args[1])
      if target then
        self.ip = target
        changed = true
      end
    end
  end

  return changed
end

return Script
