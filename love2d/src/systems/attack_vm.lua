-- Attack VM
-- Executes the programming layer of attack CSV files: named variables
-- (read back with the $ prefix), math opcodes, and jump opcodes.
-- Pure Lua on purpose: no LOVE dependency, fully unit-testable.

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local AttackVM = {}
AttackVM.__index = AttackVM

function AttackVM.new()
    local self = setmetatable({}, AttackVM)
    self.vars = {}
    return self
end

-- "$Name" reads variable Name (0 when unset); anything else passes through
function AttackVM:resolve(param)
    if type(param) == "string" and param:sub(1, 1) == "$" then
        local value = self.vars[param:sub(2)]
        if value == nil then
            return 0
        end
        return value
    end
    return param
end

function AttackVM:num(param)
    return tonumber(self:resolve(param)) or 0
end

local function jumpAbs(target) return { type = "abs", target = target } end
local function jumpRel(offset) return { type = "rel", offset = offset } end

-- Math opcodes store into the variable named by raw params[1].
-- Jump opcodes return a descriptor consumed by the sequencer (nil = no jump).
local ops = {}

ops["SET"] = function(self, p) self.vars[p[1]] = self:resolve(p[2]) end
ops["ADD"] = function(self, p) self.vars[p[1]] = self:num(p[2]) + self:num(p[3]) end
ops["SUB"] = function(self, p) self.vars[p[1]] = self:num(p[2]) - self:num(p[3]) end
ops["MUL"] = function(self, p) self.vars[p[1]] = self:num(p[2]) * self:num(p[3]) end
ops["DIV"] = function(self, p) self.vars[p[1]] = self:num(p[2]) / self:num(p[3]) end
ops["MOD"] = function(self, p) self.vars[p[1]] = self:num(p[2]) % self:num(p[3]) end
ops["FLOOR"] = function(self, p) self.vars[p[1]] = math.floor(self:num(p[2])) end
ops["DEG"] = function(self, p) self.vars[p[1]] = math.deg(self:num(p[2])) end
ops["RAD"] = function(self, p) self.vars[p[1]] = math.rad(self:num(p[2])) end
ops["SIN"] = function(self, p) self.vars[p[1]] = math.sin(math.rad(self:num(p[2]))) end
ops["COS"] = function(self, p) self.vars[p[1]] = math.cos(math.rad(self:num(p[2]))) end

ops["ANGLE"] = function(self, p)
    local x1, y1 = self:num(p[2]), self:num(p[3])
    local x2, y2 = self:num(p[4]), self:num(p[5])
    self.vars[p[1]] = math.deg(atan2(y2 - y1, x2 - x1))
end

ops["RND"] = function(self, p)
    self.vars[p[1]] = math.random(0, math.max(0, self:num(p[2]) - 1))
end

ops["JMPABS"] = function(self, p) return jumpAbs(self:resolve(p[1])) end
ops["JMPREL"] = function(self, p) return jumpRel(self:num(p[1])) end

ops["JMPZ"] = function(self, p)
    if self:num(p[2]) == 0 then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPNZ"] = function(self, p)
    if self:num(p[2]) ~= 0 then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPE"] = function(self, p)
    if self:num(p[2]) == self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPNE"] = function(self, p)
    if self:num(p[2]) ~= self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPL"] = function(self, p)
    if self:num(p[2]) < self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPNL"] = function(self, p)
    if self:num(p[2]) >= self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPG"] = function(self, p)
    if self:num(p[2]) > self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPNG"] = function(self, p)
    if self:num(p[2]) <= self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

function AttackVM:isOp(command)
    return ops[command] ~= nil
end

function AttackVM:execute(command, params)
    return ops[command](self, params)
end

return AttackVM
