-- Battle menu navigation model.
-- Pure logic: new/move/confirm/cancel contain no love.* calls and are headless-testable.
-- draw() is a rendering stub that may reference love.graphics — never called by tests.

local BattleMenu = {}
BattleMenu.__index = BattleMenu

-- Sub-menu option lists, ordered by index.
local SUB_MENUS = {
    fight = { { kind = "fight_start", label = "Fight" } },
    act   = { { kind = "act_check",   label = "Check" } },
    item  = nil,   -- dynamic: derived from self.items at confirm time
    mercy = {
        { kind = "spare", label = "Spare" },
        { kind = "flee",  label = "Flee"  },
    },
}

-- Slot names indexed by root selection (1..4).
local LEVEL_BY_SLOT = { "fight", "act", "item", "mercy" }

-- Initial item inventory.
local DEFAULT_ITEMS = {
    { name = "Butterscotch Pie", heal = 99, used = false },
    { name = "Instant Noodles",  heal = 90, used = false },
    { name = "Face Steak",       heal = 60, used = false },
    { name = "Legendary Hero",   heal = 40, used = false },
}

-- Constructor.
-- @param items  optional shared item table (from battle.items); when nil, a
--               fresh deep-copy of DEFAULT_ITEMS is used so existing tests pass.
function BattleMenu.new(items)
    local self = setmetatable({}, BattleMenu)
    self.selected   = 1       -- root cursor (1=FIGHT, 2=ACT, 3=ITEM, 4=MERCY)
    self.level      = "root"  -- current menu depth
    self.subCursor  = 1       -- cursor within the active sub-menu

    if items then
        -- Use the shared battle-level item table directly (persistent per fight).
        self.items = items
    else
        -- Deep-copy the default list so each standalone instance is independent.
        self.items = {}
        for _, item in ipairs(DEFAULT_ITEMS) do
            table.insert(self.items, { name = item.name, heal = item.heal, used = item.used })
        end
    end

    return self
end

-- Returns the options table for the active sub-menu.
-- For "item", builds it dynamically from self.items.
local function getSubOptions(self)
    if self.level == "item" then
        local opts = {}
        for i, item in ipairs(self.items) do
            table.insert(opts, { kind = "item", index = i, label = item.name })
        end
        return opts
    end
    return SUB_MENUS[self.level]
end

-- Move the cursor by `dir` (+1 right/down, -1 left/up), clamped to valid range.
function BattleMenu:move(dir)
    if self.level == "root" then
        self.selected = math.max(1, math.min(4, self.selected + dir))
    else
        local opts = getSubOptions(self)
        local n = opts and #opts or 1
        self.subCursor = math.max(1, math.min(n, self.subCursor + dir))
    end
end

-- Confirm the current selection.
-- At root: open the matching sub-menu, reset sub-cursor, return nil.
-- In a sub-menu: return an action descriptor for the chosen leaf.
function BattleMenu:confirm()
    if self.level == "root" then
        self.level     = LEVEL_BY_SLOT[self.selected]
        self.subCursor = 1
        return nil
    end

    local opts   = getSubOptions(self)
    local chosen = opts and opts[self.subCursor]
    if not chosen then return nil end

    -- Build and return the action descriptor.
    if chosen.kind == "item" then
        return { kind = "item", index = chosen.index }
    end
    return { kind = chosen.kind }
end

-- Cancel: pop from a sub-level back to root. At root, do nothing.
function BattleMenu:cancel()
    if self.level ~= "root" then
        self.level     = "root"
        self.subCursor = 1
    end
end

-- Rendering stub — may reference love.graphics; never exercised by tests.
function BattleMenu:draw()
    -- Rendering implementation is a future concern.
end

return BattleMenu
