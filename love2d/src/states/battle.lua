-- Battle State
-- Main gameplay state with combat zone, player heart, and attacks

local Constants = require("src.core.constants")
local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local Audio = require("src.systems.audio")
local CombatZone = require("src.entities.combat_zone")
local PlayerHeart = require("src.entities.player_heart")
local Sans = require("src.entities.sans")
local BattleUI = require("src.ui.battle_ui")
local Bone = require("src.entities.bone")
local AttackSequencer = require("src.systems.attack_sequencer")

local TurnManager = require("src.systems.turn_manager")

local Battle = {
    game = nil,

    -- Entities
    combatZone = nil,
    playerHeart = nil,
    sans = nil,
    battleUI = nil,

    -- Attack state
    sequencer = nil,
    currentAttack = nil,
    attackTimer = 0,
    entities = {},

    -- Battle state
    paused = false,
    blackScreen = false,
    sansText = nil,
    hideHeart = false,

    -- Turn management (Normal / Practice only)
    turnManager = nil,

    -- Phase machine
    phase = nil,
    phaseName = nil,
    phases = {},

    -- Test spawn timer (only used when no attack loaded)
    testSpawnTimer = 0,
    useTestSpawner = false
}

function Battle:setPhase(name)
    if self.phase and self.phase.exit then self.phase:exit(self) end
    self.phaseName = name
    self.phase = self.phases[name]
    if self.phase and self.phase.enter then self.phase:enter(self) end
end

function Battle:enter(game)
    self.game = game

    -- Reset HP
    game.hp = game.maxHp

    -- Create combat zone
    self.combatZone = CombatZone.new()

    -- Create player heart
    self.playerHeart = PlayerHeart.new(self.combatZone)

    -- Create Sans (centered above the combat zone, like the original)
    self.sans = Sans.new(320, 168)

    -- Create Battle UI
    self.battleUI = BattleUI.new()

    -- Create sequencer
    self.sequencer = AttackSequencer.new(self)

    -- Clear entities
    self.entities = {}

    -- Reset attack state
    self.attackTimer = 0
    self.paused = false
    self.testSpawnTimer = 0
    self.blackScreen = false
    self.sansText = nil
    self.useTestSpawner = false

    -- Reset heart visibility flag
    self.hideHeart = false

    -- Register phases
    self.phases = {
        attack      = require("src.states.battle_phases.attack"),
        player_turn = require("src.states.battle_phases.player_turn"),
    }

    -- Start attack based on mode
    self:startBattle()
end

function Battle:startBattle()
    local mode = self.game.simulatorMode

    if mode == Constants.MODE_NORMAL or mode == Constants.MODE_PRACTICE then
        -- Create the turn manager and advance to turn 1 (intro).
        self.turnManager = TurnManager.new()
        self.turnManager:advance()

        -- Start megalovania and load the intro attack.
        Audio:playMusic("megalovania", true)
        if not self.sequencer:loadAttack("sans_intro") then
            self.useTestSpawner = true
        end
        self:setPhase("attack")

    elseif mode == Constants.MODE_ENDLESS then
        self:startEndlessMode()
        self:setPhase("attack")

    elseif mode == Constants.MODE_SINGLE then
        self:loadSingleAttack(self.game.singleAttack)
        self:setPhase("attack")
    end
end

function Battle:loadAttackSequence(name)
    -- Kept for compatibility; Normal/Practice now goes through startBattle directly.
    if self.sequencer:loadAttack("sans_intro") then
        Audio:playMusic("megalovania", true)
    else
        self.useTestSpawner = true
    end
end

function Battle:loadSingleAttack(attackName)
    if self.sequencer:loadAttack(attackName) then
        self.currentAttack = attackName
    else
        -- Fallback to test spawner if attack fails to load
        self.useTestSpawner = true
    end
end

function Battle:startEndlessMode()
    -- Endless mode - random attacks
    self.useTestSpawner = true
    Audio:playMusic("megalovania", true)
end

-- Methods called by attack sequencer
function Battle:setBlackScreen(enabled)
    self.blackScreen = enabled
end

function Battle:showSansText(text)
    self.sansText = text
    self.sansTextTimer = 2.0
end

function Battle:onAttackFinished()
    local mode = self.game.simulatorMode

    if mode == Constants.MODE_SINGLE then
        Audio:stopMusic()
        self.game:setState("menu")

    elseif mode == Constants.MODE_NORMAL or mode == Constants.MODE_PRACTICE then
        if self.turnManager:isLastTurn() then
            -- Victory handling is Task 8; for now just return to the menu.
            Audio:stopMusic()
            self.game:setState("menu")
        else
            self.turnManager:advance()
            self:setPhase("player_turn")
        end
    end
    -- Endless mode: no turn manager; let the phase handle looping.
end

-- Called by player_turn after the player has chosen an action.
-- Loads the current turn's attack and begins the attack phase.
function Battle:onPlayerActionDone()
    local turn = self.turnManager:current()
    if turn and turn.attack then
        if not self.sequencer:loadAttack(turn.attack) then
            -- Attack CSV missing — skip to next turn.
            self:onAttackFinished()
            return
        end
    end
    self:setPhase("attack")
end

function Battle:checkGameOver()
    if self.game.hp <= 0 then
        Audio:stopMusic()
        Audio:playSfx("heartShatter")
        self.game:setState("menu")
    end
end

function Battle:update(dt, game)
    self.game = game

    if self.paused then
        if Input:justPressed("confirm") or Input:justPressed("cancel") then
            self.paused = false
        end
        return
    end

    -- Return to menu on menu button
    if Input:justPressed("menu") then
        Audio:stopMusic()
        game:setState("menu")
        return
    end

    -- Toggle heart mode for testing (only when test spawner is active)
    if self.useTestSpawner and Input:justPressed("cancel") then
        if self.playerHeart.mode == Constants.HEARTMODE_RED then
            self.playerHeart:setMode(Constants.HEARTMODE_BLUE)
        else
            self.playerHeart:setMode(Constants.HEARTMODE_RED)
        end
    end

    if self.phase and self.phase.update then
        self.phase:update(dt, self)
    end
end

function Battle:draw(game)
    -- game param kept for state-interface symmetry; rendering reads self.game
    -- Draw black screen overlay if active
    if self.blackScreen then
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, 640, 480)
        return
    end

    if self.phase and self.phase.draw then
        self.phase:draw(self)
    end
end

-- Arena drawing: sans, combat zone, clipped/unclipped entities, heart, battleUI, sansText
function Battle:drawArena()
    -- Draw Sans (behind combat zone)
    self.sans:draw()
    self.sans:drawHead()

    -- Draw combat zone
    self.combatZone:draw()

    -- Draw attack entities (behind heart). Board bullets (bones) are clipped to
    -- the combat zone; blasters and other entities fire from outside, unclipped.
    local ix1, iy1, ix2, iy2 = self.combatZone:getInnerBounds()
    love.graphics.setScissor(ix1, iy1, ix2 - ix1, iy2 - iy1)
    for _, entity in ipairs(self.entities) do
        if entity.clipToZone and entity.draw then
            entity:draw()
        end
    end
    love.graphics.setScissor()

    for _, entity in ipairs(self.entities) do
        if not entity.clipToZone and entity.draw then
            entity:draw()
        end
    end

    -- Draw player heart (hidden during player-turn phase)
    if not self.hideHeart then
        self.playerHeart:draw()
    end

    -- Draw Battle UI (bottom bar with buttons and HP)
    self.battleUI:draw(self.game.hp, self.game.maxHp, self.playerHeart.karma)

    -- Draw Sans text if active
    if self.sansText then
        love.graphics.setColor(1, 1, 1)
        Fonts.sans:setScale(1)
        Fonts.sans:draw(self.sansText, 320, 100, "center")
    end
end

function Battle:updateEntities(dt)
    -- Update all attack entities
    for i = #self.entities, 1, -1 do
        local entity = self.entities[i]
        if entity.update then
            entity:update(dt)
        end

        -- Remove dead entities
        if entity.dead then
            table.remove(self.entities, i)
        end
    end
end

function Battle:checkCollisions()
    if self.playerHeart.invincible then
        return
    end

    local hx1, hy1, hx2, hy2 = self.playerHeart:getHitbox()
    local hcx, hcy = (hx1 + hx2) / 2, (hy1 + hy2) / 2

    for _, entity in ipairs(self.entities) do
        local collided = false

        -- Check for beam hitbox (Gaster Blaster)
        if entity.getBeamHitbox then
            local beam = entity:getBeamHitbox()
            if beam then
                -- Line-to-point collision with width
                collided = self:checkBeamCollision(hcx, hcy, beam)
            end
        -- Check for regular hitbox
        elseif entity.getHitbox and entity.damage then
            local ex1, ey1, ex2, ey2 = entity:getHitbox()

            -- AABB collision check
            if hx1 < ex2 and hx2 > ex1 and hy1 < ey2 and hy2 > ey1 then
                -- Check for blue bone (only hurts when moving)
                if entity.isBlue then
                    local moving = Input:isMoving()
                    if not moving then
                        goto continue
                    end
                end
                collided = true
            end
        end

        -- Apply damage if collision detected
        if collided and entity.damage then
            local damaged = self.playerHeart:damage(entity.damage)
            if damaged then
                self.game.hp = self.game.hp - entity.damage
                Audio:playSfx("playerDamaged")

                -- Add karma if applicable
                if entity.karma then
                    self.playerHeart:addKarma(entity.karma)
                end
            end
        end
        ::continue::
    end
end

-- Check collision between point and beam line
function Battle:checkBeamCollision(px, py, beam)
    local dx = beam.x2 - beam.x1
    local dy = beam.y2 - beam.y1
    local len = math.sqrt(dx * dx + dy * dy)

    if len == 0 then return false end

    -- Normalize
    dx, dy = dx / len, dy / len

    -- Vector from beam start to point
    local fx = px - beam.x1
    local fy = py - beam.y1

    -- Project point onto beam line
    local proj = fx * dx + fy * dy

    -- Clamp to beam length
    proj = math.max(0, math.min(len, proj))

    -- Closest point on beam
    local closestX = beam.x1 + dx * proj
    local closestY = beam.y1 + dy * proj

    -- Distance from point to closest point
    local distX = px - closestX
    local distY = py - closestY
    local dist = math.sqrt(distX * distX + distY * distY)

    return dist <= beam.width / 2
end

function Battle:addEntity(entity)
    table.insert(self.entities, entity)
end

function Battle:clearEntities()
    self.entities = {}
end

function Battle:updateTestSpawner(dt)
    -- Spawn test bones periodically
    self.testSpawnTimer = self.testSpawnTimer + dt

    if self.testSpawnTimer >= 0.8 then
        self.testSpawnTimer = 0

        local x1, y1, x2, y2 = self.combatZone:getBounds()
        local cx, cy = self.combatZone:getCenter()

        -- Randomly spawn from different sides
        local side = math.random(1, 4)
        local bone

        -- Random color: 0=white (80%), 1=blue (20%)
        local color = math.random() < 0.2 and 1 or 0

        if side == 1 then
            -- From left
            bone = Bone.new(x1 - 20, cy, math.random(30, 80), "vertical", color)
            bone:setVelocity(200, 0)
        elseif side == 2 then
            -- From right
            bone = Bone.new(x2 + 20, cy, math.random(30, 80), "vertical", color)
            bone:setVelocity(-200, 0)
        elseif side == 3 then
            -- From top
            bone = Bone.new(cx, y1 - 20, math.random(30, 80), "horizontal", color)
            bone:setVelocity(0, 200)
        else
            -- From bottom
            bone = Bone.new(cx, y2 + 20, math.random(30, 80), "horizontal", color)
            bone:setVelocity(0, -200)
        end

        bone:setLifetime(5)
        self:addEntity(bone)
    end
end

-- Collect active platform entities (for blue-mode landing)
function Battle:getPlatforms()
    local platforms = {}
    for _, entity in ipairs(self.entities) do
        if entity.isPlatform then
            table.insert(platforms, entity)
        end
    end
    return platforms
end

function Battle:exit()
    -- Stop music
    Audio:stopMusic()

    -- Cleanup
    self.combatZone = nil
    self.playerHeart = nil
    self.sans = nil
    self.battleUI = nil
    self.sequencer = nil
    self.turnManager = nil
    self.entities = {}
    self.blackScreen = false
    self.sansText = nil
    self.hideHeart = false
    self.phase = nil
    self.phaseName = nil
    self.phases = {}
end

return Battle
