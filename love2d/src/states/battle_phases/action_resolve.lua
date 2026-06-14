-- Action-resolve phase.
-- Displays the result of ACT / ITEM / MERCY actions as box text (typewriter via
-- Dialogue), applies any immediate effects (heal, state change), then transitions
-- to the next phase once the player dismisses the message.

local Input    = require("src.systems.input")
local Audio    = require("src.systems.audio")
local Dialogue = require("src.ui.dialogue")

-- Wide zone bounds used as the dialogue-box area.
local WIDE_X1, WIDE_Y1, WIDE_X2, WIDE_Y2 = 33, 251, 608, 391

-- Anchor point for the dialogue bubble: centered horizontally, bottom of zone.
local DLG_X = (WIDE_X1 + WIDE_X2) / 2   -- 320.5
local DLG_Y = WIDE_Y2 - 6                -- slightly above the zone border

local ActionResolve = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Compute actual HP gain capped to maxHp, apply it, return the amount healed.
local function applyHeal(battle, amount)
    local before = battle.game.hp
    battle.game.hp = math.min(battle.game.maxHp, before + amount)
    return battle.game.hp - before
end

-- Return true when the current fight turn is the spare-offer turn.
local function isSpareMoment(battle)
    if not battle.turnManager then return false end
    local turn = battle.turnManager:current()
    return turn ~= nil and turn.event == "spare_offer"
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function ActionResolve:enter(battle)
    -- Hide the heart while the box text is displayed.
    battle.hideHeart = true

    -- Widen the combat zone to match the dialogue-box area.
    battle.combatZone:setSize(WIDE_X1, WIDE_Y1, WIDE_X2, WIDE_Y2)

    -- Create a fresh Dialogue object for this message.
    self.dlg = Dialogue.new()

    -- Callback invoked after the player dismisses the message.
    -- Assigned per action kind below.
    self.onDismiss = nil

    local action = battle.pendingAction

    if action.kind == "act_check" then
        self:setupActCheck(battle)

    elseif action.kind == "item" then
        self:setupItem(action, battle)

    elseif action.kind == "spare" then
        self:setupSpare(battle)

    elseif action.kind == "flee" then
        self:setupFlee(battle)

    else
        -- Unknown action: skip the turn safely.
        self.onDismiss = function() battle:onPlayerActionDone() end
        self.dlg:show("* ...", DLG_X, DLG_Y, "white")
    end
end

function ActionResolve:setupActCheck(battle)
    self.dlg:show(
        "* SANS  1 ATK  1 DEF\n* The easiest enemy.\n* Can only deal 1 damage.",
        DLG_X, DLG_Y, "white"
    )
    self.onDismiss = function()
        battle:onPlayerActionDone()
    end
end

function ActionResolve:setupItem(action, battle)
    local item = battle.items and battle.items[action.index]

    if not item then
        -- Out-of-range index — treat as already used.
        self.dlg:show("* You have none of those left.", DLG_X, DLG_Y, "white")
        self.onDismiss = function()
            -- Return to player_turn; do not consume the turn.
            battle:setPhase("player_turn")
        end
        return
    end

    if item.used then
        self.dlg:show("* You have none of those left.", DLG_X, DLG_Y, "white")
        self.onDismiss = function()
            -- Return to player_turn; do not consume the turn.
            battle:setPhase("player_turn")
        end
        return
    end

    -- Consume the item and apply healing.
    item.used = true
    local healed = applyHeal(battle, item.heal)
    Audio:playSfx("playerHeal")

    local healedStr = tostring(healed)
    self.dlg:show(
        "* You ate the " .. item.name .. ".\n* You recovered " .. healedStr .. " HP!",
        DLG_X, DLG_Y, "white"
    )
    self.onDismiss = function()
        battle:onPlayerActionDone()
    end
end

function ActionResolve:setupSpare(battle)
    if isSpareMoment(battle) then
        -- Dunked ending: set the flag so onPlayerActionDone triggers the cutscene.
        battle.pendingEnding = "dunked"
        self.dlg:show("* ...", DLG_X, DLG_Y, "white")
        self.onDismiss = function()
            battle:onPlayerActionDone()
        end
    else
        self.dlg:show(
            "* You called for mercy.\n* ...",
            DLG_X, DLG_Y, "white"
        )
        self.onDismiss = function()
            battle:setPhase("player_turn")
        end
    end
end

function ActionResolve:setupFlee(battle)
    self.dlg:show("* You fled.", DLG_X, DLG_Y, "white")
    self.onDismiss = function()
        battle.hideHeart = false
        Audio:stopMusic()
        battle.game:setState("menu")
    end
end

function ActionResolve:exit(battle)
    battle.hideHeart = false
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function ActionResolve:keypressed(key, battle)
    -- Confirm advances or dismisses the dialogue.
    -- (Navigation is handled via the Input singleton in update.)
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function ActionResolve:update(dt, battle)
    -- Keep combat zone and Sans animating.
    battle.combatZone:update(dt)
    battle.sans:update(dt)

    -- Tick the typewriter.
    self.dlg:update(dt)

    -- Confirm input: skip typewriter if still running, dismiss when complete.
    if Input:justPressed("confirm") then
        if not self.dlg:isComplete() then
            -- Show all text immediately.
            self.dlg:skip()
        else
            -- Dismiss and execute the transition.
            self.dlg:skip()   -- deactivates the dialogue
            if self.onDismiss then
                self.onDismiss()
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function ActionResolve:draw(battle)
    -- Draw arena (heart hidden via battle.hideHeart).
    battle:drawArena()

    -- Draw the dialogue box text inside the wide zone.
    self.dlg:draw()

    love.graphics.setColor(1, 1, 1, 1)
end

return ActionResolve
