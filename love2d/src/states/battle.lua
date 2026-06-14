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

-- Duration of the heart-shatter animation before returning to menu.
local SHATTER_DURATION = 0.9

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
    useTestSpawner = false,

    -- Ending overlay (game over shatter / dunked / victory).
    -- "gameover" | "dunked" | "victory" | nil
    ending = nil,
    endingTimer = 0,
    -- Shard sprites loaded lazily (3 sheets, one shard per frame).
    shardImages = nil,
    -- Last known heart position, captured when the shatter is triggered.
    shatterX = 320,
    shatterY = 308,
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

    -- Item inventory: one set per fight, shared across all turns.
    self.items = {
        { name = "Butterscotch Pie", heal = 99, used = false },
        { name = "Instant Noodles",  heal = 90, used = false },
        { name = "Face Steak",       heal = 60, used = false },
        { name = "Legendary Hero",   heal = 40, used = false },
    }

    -- Pending action set by player_turn before transitioning to action_resolve.
    self.pendingAction = nil

    -- Pending ending flag (set by action_resolve on dunked spare).
    self.pendingEnding = nil

    -- Reset ending state.
    self.ending = nil
    self.endingTimer = 0
    self.shardImages = nil

    -- Register phases
    self.phases = {
        attack          = require("src.states.battle_phases.attack"),
        player_turn     = require("src.states.battle_phases.player_turn"),
        action_resolve  = require("src.states.battle_phases.action_resolve"),
        sans_dialogue   = require("src.states.battle_phases.sans_dialogue"),
        ending_dunked   = require("src.states.battle_phases.ending_dunked"),
        ending_victory  = require("src.states.battle_phases.ending_victory"),
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

        -- Reset the flag that guards the finishing player turn (post-sans_final).
        self.sansAsleep = false

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
            -- sans_final has just finished; mark Sans as asleep so the
            -- finishing player turn lets FIGHT connect.
            self.sansAsleep = true
            self:setPhase("player_turn")
        else
            self.turnManager:advance()
            self:setPhase("player_turn")
        end
    end
    -- Endless mode: no turn manager; let the phase handle looping.
end

-- Called by player_turn / action_resolve after the player has chosen an action.
-- Checks for a pending dunked ending; otherwise transitions to sans_dialogue.
function Battle:onPlayerActionDone()
    if self.pendingEnding == "dunked" then
        self:triggerDunked()
        return
    end
    self:setPhase("sans_dialogue")
end

-- Called by sans_dialogue once the speech bubble is dismissed (or skipped when
-- the turn has no dialogue). Loads the attack and begins the attack phase.
function Battle:onDialogueDone()
    -- Dunked ending: after action_resolve showed "..." and called onPlayerActionDone,
    -- sans_dialogue is bypassed above; this branch handles any unexpected re-entry.
    if self.pendingEnding == "dunked" then
        self:triggerDunked()
        return
    end

    -- After sans_final has already played, sansAsleep is true: the player is on
    -- the finishing menu where non-FIGHT actions loop back without loading any attack.
    if self.sansAsleep then
        self:setPhase("player_turn")
        return
    end

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

-- Trigger the "get dunked on" game-over path.
function Battle:triggerDunked()
    self.pendingEnding = nil
    -- Use the dedicated dunked-ending phase (or fall back to a direct game over).
    self:setPhase("ending_dunked")
end

-- Trigger the victory ending.
function Battle:triggerVictory()
    self:setPhase("ending_victory")
end

function Battle:checkGameOver()
    if self.game.hp <= 0 then
        local mode = self.game.simulatorMode
        if mode == Constants.MODE_PRACTICE then
            -- Practice floor: clamp HP to 1 and never die.
            self.game.hp = math.max(1, self.game.hp)
            return
        end
        -- Normal / Single / Endless: trigger the shatter ending.
        self:triggerGameOver()
    end
end

-- Start the heart-shatter animation then return to menu.
function Battle:triggerGameOver()
    if self.ending then return end  -- already ending
    Audio:stopMusic()
    Audio:playSfx("heartShatter")
    self.ending     = "gameover"
    self.endingTimer = SHATTER_DURATION
    -- Capture the heart's last position for the shard animation.
    if self.playerHeart then
        self.shatterX = self.playerHeart.x
        self.shatterY = self.playerHeart.y
    end
    -- Load shard sprites lazily.
    self:loadShardImages()
end

-- Lazy-load the three heartshard sprite sheets.
function Battle:loadShardImages()
    if self.shardImages then return end
    self.shardImages = {}
    for i = 0, 2 do
        local ok, img = pcall(love.graphics.newImage,
            "assets/sprites/heartshard-sheet" .. i .. ".png")
        if ok then
            img:setFilter("nearest", "nearest")
            self.shardImages[i + 1] = img
        end
    end
end

function Battle:update(dt, game)
    self.game = game

    -- Handle game-over shatter overlay timer (independent of phase machine).
    if self.ending == "gameover" then
        self.endingTimer = self.endingTimer - dt
        if self.endingTimer <= 0 then
            self.ending = nil
            game:setState("menu")
        end
        return
    end

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

    -- Toggle heart mode for testing (only when test spawner is active and not
    -- in player_turn, where cancel is used for sub-menu navigation).
    if self.useTestSpawner and self.phaseName ~= "player_turn" and Input:justPressed("cancel") then
        if self.playerHeart.mode == Constants.HEARTMODE_RED then
            self.playerHeart:setMode(Constants.HEARTMODE_BLUE)
        else
            self.playerHeart:setMode(Constants.HEARTMODE_RED)
        end
    end

    -- Keep the HP bar smooth-animation state current.
    if self.battleUI and self.playerHeart then
        self.battleUI:update(dt, self.game.hp, self.game.maxHp, self.playerHeart.karma)
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

    -- Game-over shatter overlay: hide normal phase draw and show shard explosion.
    if self.ending == "gameover" then
        self:drawShatter()
        return
    end

    if self.phase and self.phase.draw then
        self.phase:draw(self)
    end
end

-- Draw the three heart shards flying outward from the shatter point.
function Battle:drawShatter()
    -- Black background for contrast.
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 640, 480)

    if not self.shardImages then return end

    -- Progress from 1 (just started) down to 0 (ending).
    local progress = self.endingTimer / SHATTER_DURATION
    -- Fade out in the last third of the animation.
    local alpha = math.min(1, progress * 3)

    -- Each shard flies in a different direction from the last heart position.
    local directions = {
        { dx = -1,  dy = -0.8 },
        { dx =  0,  dy =  1.2 },
        { dx =  1,  dy = -0.6 },
    }
    local speed  = 80   -- pixels of travel over the full duration
    local spread = (1 - progress) * speed

    for i, dir in ipairs(directions) do
        local img = self.shardImages[i]
        if img then
            local iw, ih = img:getDimensions()
            local sx = self.shatterX + dir.dx * spread
            local sy = self.shatterY + dir.dy * spread
            love.graphics.setColor(1, 0.15, 0.15, alpha)
            love.graphics.draw(img, sx, sy, 0, 2, 2, iw / 2, ih / 2)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
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
    self.ending = nil
    self.endingTimer = 0
    self.shardImages = nil
    self.pendingEnding = nil
end

return Battle
