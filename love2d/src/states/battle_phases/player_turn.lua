-- Player-turn phase.
-- Shows the battle menu (FIGHT/ACT/ITEM/MERCY), runs the FIGHT target-bar
-- mini-game, and hands control back to the battle once the player has chosen.
-- ALL mutable state is (re-)initialised in enter() so the singleton is safe
-- to re-enter each turn.

local Input       = require("src.systems.input")
local Audio       = require("src.systems.audio")
local BattleMenu  = require("src.ui.battle_menu")
local DamageNumber = require("src.ui.damage_number")
local Fonts       = require("src.ui.fonts")

-- Wide zone bounds matching the dialogue-box area (same as C2 original).
local WIDE_X1, WIDE_Y1, WIDE_X2, WIDE_Y2 = 33, 251, 608, 391

-- Target-bar layout inside the wide zone.
local BAR_MARGIN   = 20                          -- horizontal inset from zone edge
local BAR_HEIGHT   = 32                          -- height of the target bar track
local CURSOR_W     = 16                          -- sweeping cursor width
local CURSOR_SPEED = 220                         -- pixels per second

-- Delay after a FIGHT swing before going to the next attack.
local POST_SWING_DELAY = 0.6

local PlayerTurn = {}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function PlayerTurn:enter(battle)
    -- Widen the combat zone instantly.
    battle.combatZone:setSize(WIDE_X1, WIDE_Y1, WIDE_X2, WIDE_Y2)

    -- Hide the heart during the menu phase.
    battle.hideHeart = true

    -- Fresh menu each turn so cursor always starts at FIGHT.
    -- Pass the battle-level items table so used state persists across turns.
    self.menu = BattleMenu.new(battle.items)

    -- Sync the button highlight on entry.
    if battle.battleUI.setSelectedButton then
        battle.battleUI:setSelectedButton(self.menu.selected)
    end

    -- Target-bar state.
    self.targetActive  = false
    self.cursorX       = 0          -- relative to bar start
    self.barWidth      = 0          -- computed in draw; set here for safety
    self.postSwingTimer = 0
    self.swingDone     = false
    self.isFinalHit    = false

    -- Damage numbers.
    self.damageNumbers = {}

    -- Load target-bar sprites (lazy, safe to call multiple times).
    if not self.targetSprite then
        local ok, img = pcall(love.graphics.newImage, "assets/sprites/target-sheet0.png")
        if ok then
            self.targetSprite = img
            self.targetSprite:setFilter("nearest", "nearest")
        end
    end
    if not self.choiceSprite then
        local ok, img = pcall(love.graphics.newImage, "assets/sprites/targetchoice-sheet0.png")
        if ok then
            self.choiceSprite = img
            self.choiceSprite:setFilter("nearest", "nearest")
        end
    end
    if not self.strikeSprite then
        local ok, img = pcall(love.graphics.newImage, "assets/sprites/strike-sheet0.png")
        if ok then
            self.strikeSprite = img
            self.strikeSprite:setFilter("nearest", "nearest")
        end
    end

    -- Strike flash state.
    self.strikeTimer  = 0
    self.showStrike   = false
end

-- Default combat zone bounds (attacks resize via their own CSV commands on enter).
local DEFAULT_X1, DEFAULT_Y1, DEFAULT_X2, DEFAULT_Y2 = 239, 226, 404, 391

function PlayerTurn:exit(battle)
    battle.hideHeart = false
    -- Restore the narrow default zone so attacks that skip their own resize
    -- do not inherit the wide player-turn area.
    battle.combatZone:setSize(DEFAULT_X1, DEFAULT_Y1, DEFAULT_X2, DEFAULT_Y2)
end

-- ---------------------------------------------------------------------------
-- Input handling
-- ---------------------------------------------------------------------------

function PlayerTurn:keypressed(key, battle)
    -- Navigation and confirm are handled via the Input singleton in update();
    -- this callback is kept for future extensions (e.g. keyboard-repeat edge cases).
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function PlayerTurn:update(dt, battle)
    -- Update combat zone animation (if any) and Sans idle.
    battle.combatZone:update(dt)
    battle.sans:update(dt)

    -- Update damage numbers.
    for i = #self.damageNumbers, 1, -1 do
        self.damageNumbers[i]:update(dt)
        if self.damageNumbers[i].dead then
            table.remove(self.damageNumbers, i)
        end
    end

    -- Strike flash decay.
    if self.showStrike then
        self.strikeTimer = self.strikeTimer - dt
        if self.strikeTimer <= 0 then
            self.showStrike = false
        end
    end

    -- Post-swing delay: wait, then hand off to the next attack (or victory).
    if self.swingDone then
        self.postSwingTimer = self.postSwingTimer - dt
        if self.postSwingTimer <= 0 then
            self.swingDone = false
            if self.isFinalHit then
                self.isFinalHit = false
                battle:triggerVictory()
            else
                battle:onPlayerActionDone()
            end
        end
        return
    end

    -- Target bar sweep.
    if self.targetActive then
        -- Compute bar width (pixels) from current zone bounds.
        local x1, _, x2, _ = battle.combatZone:getBounds()
        local barStart = x1 + BAR_MARGIN
        local barEnd   = x2 - BAR_MARGIN
        self.barWidth  = barEnd - barStart

        self.cursorX = self.cursorX + CURSOR_SPEED * dt
        if self.cursorX + CURSOR_W >= self.barWidth then
            -- Wrap cursor back to start.
            self.cursorX = 0
        end

        -- Confirm stops the cursor and swings.
        if Input:justPressed("confirm") then
            self:doSwing(battle)
        end
        return
    end

    -- Menu navigation (only when target bar is not active and swing not done).
    if Input:justPressed("left") then
        if self.menu.level == "root" then
            self.menu:move(-1)
            self:syncButtonHighlight(battle)
            Audio:playSfx("menucursor")
        else
            self.menu:move(-1)
        end
    elseif Input:justPressed("right") then
        if self.menu.level == "root" then
            self.menu:move(1)
            self:syncButtonHighlight(battle)
            Audio:playSfx("menucursor")
        else
            self.menu:move(1)
        end
    elseif Input:justPressed("confirm") then
        local action = self.menu:confirm()
        if action then
            self:dispatchAction(action, battle)
        else
            -- Opened a sub-menu.
            Audio:playSfx("menuSelect")
        end
    elseif Input:justPressed("cancel") then
        if self.menu.level ~= "root" then
            self.menu:cancel()
            Audio:playSfx("menucursor")
        end
    end
end

-- Sync the battleUI button highlight to the current root selection.
function PlayerTurn:syncButtonHighlight(battle)
    if battle.battleUI.setSelectedButton then
        battle.battleUI:setSelectedButton(self.menu.selected)
    end
end

-- Dispatch a confirmed leaf action.
function PlayerTurn:dispatchAction(action, battle)
    if action.kind == "fight_start" then
        -- Start the target-bar sweep.
        self.targetActive = true
        self.cursorX      = 0
        Audio:playSfx("menuSelect")

    else
        -- act_check, item, spare, flee: hand off to action_resolve.
        battle.pendingAction = action
        battle:setPhase("action_resolve")
    end
end

-- Return true when Sans is asleep (sans_final has already played), meaning
-- the next FIGHT swing connects and triggers victory.
local function isFinalTurn(battle)
    return battle.sansAsleep == true
end

-- Called when confirm is pressed while the target bar is active.
function PlayerTurn:doSwing(battle)
    self.targetActive = false

    -- Play fight swing SFX.
    Audio:playSfx("playerFight")

    -- Show strike flash near Sans.
    self.showStrike  = true
    self.strikeTimer = 0.25

    local sx, sy = battle.sans.x, battle.sans.y

    if isFinalTurn(battle) then
        -- Final turn: the hit connects.  Transition to the victory ending
        -- after a short pause so the player can see the damage number.
        table.insert(self.damageNumbers, DamageNumber.new("9999", sx, sy - 40))
        self.swingDone      = true
        self.postSwingTimer = POST_SWING_DELAY
        self.isFinalHit     = true
    else
        -- All other turns result in MISS.
        table.insert(self.damageNumbers, DamageNumber.new("MISS", sx, sy - 40))
        self.swingDone      = true
        self.postSwingTimer = POST_SWING_DELAY
        self.isFinalHit     = false
    end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function PlayerTurn:draw(battle)
    -- Draw the combat zone border, Sans, entities and the bottom UI.
    -- The heart is hidden via battle.hideHeart so drawArena skips it.
    battle:drawArena()

    local x1, y1, x2, y2 = battle.combatZone:getBounds()
    local barStart = x1 + BAR_MARGIN
    local barEnd   = x2 - BAR_MARGIN
    self.barWidth  = barEnd - barStart

    -- Target bar when active.
    if self.targetActive then
        self:drawTargetBar(battle, x1, y1, x2, y2, barStart)
    end

    -- Sub-menu options text (shown inside the wide zone).
    if self.menu.level ~= "root" then
        self:drawSubMenu(battle, x1, y1, x2, y2)
    end

    -- Strike flash.
    if self.showStrike and self.strikeSprite then
        local sw, sh = self.strikeSprite:getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.strikeSprite,
            battle.sans.x, battle.sans.y - 20,
            0, 1.5, 1.5,
            sw / 2, sh / 2
        )
    end

    -- Damage numbers.
    for _, dn in ipairs(self.damageNumbers) do
        dn:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PlayerTurn:drawTargetBar(battle, x1, y1, x2, y2, barStart)
    local barY  = (y1 + y2) / 2 - BAR_HEIGHT / 2

    -- Background track.
    if self.targetSprite then
        -- Scale the target background to fill the bar width.
        local tw, th = self.targetSprite:getDimensions()
        local scaleX = self.barWidth / tw
        local scaleY = BAR_HEIGHT / th
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.targetSprite, barStart, barY, 0, scaleX, scaleY)
    else
        -- Fallback: plain dark rectangle.
        love.graphics.setColor(0.15, 0.15, 0.15, 1)
        love.graphics.rectangle("fill", barStart, barY, self.barWidth, BAR_HEIGHT)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", barStart, barY, self.barWidth, BAR_HEIGHT)
    end

    -- Sweeping cursor.
    local cursorDraw = barStart + self.cursorX
    if self.choiceSprite then
        local cw, ch = self.choiceSprite:getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.choiceSprite,
            cursorDraw, barY,
            0,
            CURSOR_W / cw,
            BAR_HEIGHT / ch
        )
    else
        -- Fallback: yellow rectangle cursor.
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.rectangle("fill", cursorDraw, barY, CURSOR_W, BAR_HEIGHT)
    end
end

function PlayerTurn:drawSubMenu(battle, x1, y1, x2, y2)
    -- Derive sub-menu option label list.
    local level = self.menu.level
    local opts = {}
    if level == "fight" then
        opts = { "Fight" }
    elseif level == "act" then
        opts = { "Check" }
    elseif level == "mercy" then
        opts = { "Spare", "Flee" }
    elseif level == "item" then
        for _, item in ipairs(self.menu.items) do
            table.insert(opts, item.name)
        end
    end

    if #opts == 0 then return end

    -- Draw options in a row inside the wide zone.
    local centerY  = (y1 + y2) / 2
    local spacing  = (x2 - x1) / (#opts + 1)
    love.graphics.setColor(1, 1, 1, 1)
    Fonts.default:setScale(1)
    for i, label in ipairs(opts) do
        local lx = x1 + spacing * i
        -- Heart marker for selected sub-item.
        if i == self.menu.subCursor then
            love.graphics.setColor(1, 0, 0, 1)
            Fonts.default:draw("> ", lx - 20, centerY, "right")
            love.graphics.setColor(1, 1, 1, 1)
        end
        Fonts.default:draw(label, lx, centerY, "center")
    end
end

return PlayerTurn
