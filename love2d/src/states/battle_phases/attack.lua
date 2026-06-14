-- Attack phase: runs the current attack CSV via the sequencer, updates
-- entities and collisions. On EndAttack it asks the battle what comes next.

local Audio = require("src.systems.audio")

local AttackPhase = {}

function AttackPhase:enter(battle)
end

function AttackPhase:update(dt, battle)
    if battle.sequencer then
        battle.sequencer:update(dt)
        if battle.sequencer:isFinished() then
            battle:onAttackFinished()
            return
        end
    end

    battle.combatZone:update(dt)

    battle.playerHeart.platforms = battle:getPlatforms()
    battle.playerHeart:update(dt)

    -- Slam impact damage (when SansSlamDamage was enabled)
    if battle.playerHeart.pendingSlamDamage then
        battle.playerHeart.pendingSlamDamage = false
        if battle.playerHeart:damage(3) then
            battle.game.hp = battle.game.hp - 3
            Audio:playSfx("playerDamaged")
        end
    end

    battle.sans:update(dt)
    battle:updateEntities(dt)
    battle:checkCollisions(battle.game)

    -- Update attack timer
    battle.attackTimer = battle.attackTimer + dt

    -- Update sans text timer
    if battle.sansText and battle.sansTextTimer then
        battle.sansTextTimer = battle.sansTextTimer - dt
        if battle.sansTextTimer <= 0 then
            battle.sansText = nil
        end
    end

    -- Test bone spawning (only when no attack loaded)
    if battle.useTestSpawner then
        battle:updateTestSpawner(dt)
    end

    battle:checkGameOver()
end

function AttackPhase:draw(battle)
    battle:drawArena()
end

return AttackPhase
