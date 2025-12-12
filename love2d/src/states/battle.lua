-- Battle State
-- Main gameplay state with combat zone, player heart, and attacks

local Constants = require("src.core.constants")
local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local CombatZone = require("src.entities.combat_zone")
local PlayerHeart = require("src.entities.player_heart")
local HpBar = require("src.ui.hp_bar")
local Bone = require("src.entities.bone")

local Battle = {
    game = nil,

    -- Entities
    combatZone = nil,
    playerHeart = nil,
    hpBar = nil,

    -- Attack state
    currentAttack = nil,
    attackTimer = 0,
    entities = {},

    -- Battle state
    paused = false,

    -- Test spawn timer
    testSpawnTimer = 0
}

function Battle:enter(game)
    self.game = game

    -- Reset HP
    game.hp = game.maxHp

    -- Create combat zone
    self.combatZone = CombatZone.new()

    -- Create player heart
    self.playerHeart = PlayerHeart.new(self.combatZone)

    -- Create HP bar
    self.hpBar = HpBar.new()

    -- Clear entities
    self.entities = {}

    -- Reset attack state
    self.attackTimer = 0
    self.paused = false
    self.testSpawnTimer = 0

    -- Start attack based on mode
    self:startBattle()
end

function Battle:startBattle()
    local mode = self.game.simulatorMode

    if mode == Constants.MODE_NORMAL then
        -- Start normal fight sequence
        self:loadAttackSequence("normal")
    elseif mode == Constants.MODE_PRACTICE then
        -- Practice mode - same as normal but infinite HP
        self:loadAttackSequence("normal")
    elseif mode == Constants.MODE_ENDLESS then
        -- Endless mode - random attacks
        self:startEndlessMode()
    elseif mode == Constants.MODE_SINGLE then
        -- Single attack mode
        self:loadSingleAttack(self.game.singleAttack)
    end
end

function Battle:loadAttackSequence(name)
    -- Load attack sequence (to be implemented)
    -- For now, just set up a basic test environment
end

function Battle:loadSingleAttack(attackName)
    -- Load single attack (to be implemented)
end

function Battle:startEndlessMode()
    -- Start endless mode (to be implemented)
end

function Battle:update(dt, game)
    if self.paused then
        if Input:justPressed("confirm") or Input:justPressed("cancel") then
            self.paused = false
        end
        return
    end

    -- Return to menu on cancel (temporary - will be pause menu later)
    if Input:justPressed("menu") then
        game:setState("menu")
        return
    end

    -- Toggle heart mode for testing (temporary)
    if Input:justPressed("cancel") then
        if self.playerHeart.mode == Constants.HEARTMODE_RED then
            self.playerHeart:setMode(Constants.HEARTMODE_BLUE)
        else
            self.playerHeart:setMode(Constants.HEARTMODE_RED)
        end
    end

    -- Update combat zone
    self.combatZone:update(dt)

    -- Update player heart
    self.playerHeart:update(dt)

    -- Update HP bar
    self.hpBar:update(dt, game.hp, game.maxHp, self.playerHeart.karma)

    -- Update attack entities
    self:updateEntities(dt)

    -- Check collisions
    self:checkCollisions(game)

    -- Update attack timer
    self.attackTimer = self.attackTimer + dt

    -- Test bone spawning (temporary)
    self:updateTestSpawner(dt)

    -- Check for game over
    if game.hp <= 0 then
        -- Game over (to be implemented)
        game:setState("menu")
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

function Battle:checkCollisions(game)
    if self.playerHeart.invincible then
        return
    end

    local hx1, hy1, hx2, hy2 = self.playerHeart:getHitbox()

    for _, entity in ipairs(self.entities) do
        if entity.getHitbox and entity.damage then
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

                -- Apply damage
                local damaged = self.playerHeart:damage(entity.damage)
                if damaged then
                    game.hp = game.hp - entity.damage

                    -- Add karma if applicable
                    if entity.karma then
                        self.playerHeart:addKarma(entity.karma)
                    end
                end
            end
        end
        ::continue::
    end
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

        if side == 1 then
            -- From left
            bone = Bone.new(x1 - 20, cy, math.random(30, 80), "vertical", math.random() < 0.2)
            bone:setVelocity(200, 0)
        elseif side == 2 then
            -- From right
            bone = Bone.new(x2 + 20, cy, math.random(30, 80), "vertical", math.random() < 0.2)
            bone:setVelocity(-200, 0)
        elseif side == 3 then
            -- From top
            bone = Bone.new(cx, y1 - 20, math.random(30, 80), "horizontal", math.random() < 0.2)
            bone:setVelocity(0, 200)
        else
            -- From bottom
            bone = Bone.new(cx, y2 + 20, math.random(30, 80), "horizontal", math.random() < 0.2)
            bone:setVelocity(0, -200)
        end

        bone:setLifetime(5)
        self:addEntity(bone)
    end
end

function Battle:draw(game)
    -- Draw combat zone
    self.combatZone:draw()

    -- Draw attack entities (behind heart)
    for _, entity in ipairs(self.entities) do
        if entity.draw then
            entity:draw()
        end
    end

    -- Draw player heart
    self.playerHeart:draw()

    -- Draw HP bar
    self.hpBar:draw(game.hp, game.maxHp, self.playerHeart.karma)

    -- Draw mode indicator (temporary for testing)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)

    local modeText = ""
    if game.simulatorMode == Constants.MODE_NORMAL then
        modeText = "Normal"
    elseif game.simulatorMode == Constants.MODE_PRACTICE then
        modeText = "Practice"
    elseif game.simulatorMode == Constants.MODE_ENDLESS then
        modeText = "Endless " .. (game.endlessStage + 1)
    elseif game.simulatorMode == Constants.MODE_SINGLE then
        modeText = game.singleAttack
    end

    Fonts.default:draw(modeText, 320, 430, "center")

    -- Draw heart mode indicator
    local heartModeText = self.playerHeart.mode == Constants.HEARTMODE_RED and "Red" or "Blue (Z=jump)"
    Fonts.default:draw(heartModeText, 320, 448, "center")
    Fonts.default:draw("X: toggle | Esc: menu", 320, 466, "center")
end

function Battle:exit()
    -- Cleanup
    self.combatZone = nil
    self.playerHeart = nil
    self.hpBar = nil
    self.entities = {}
end

return Battle
