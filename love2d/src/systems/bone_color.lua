-- Bone color motion gating (R6).
-- Pure helper deciding whether a colored bullet damages the soul this frame,
-- mirroring the original (Battle.xml 8028-8106). Color: 0=white, 1=blue, 2=orange.
--   white  (0): always damages.
--   blue   (1): damages only when the soul IS moving.
--   orange (2): damages only when the soul is NOT moving.
-- "moved" is real per-frame soul motion (any source), not a key-press check.

local function shouldDamage(color, moved)
    if color == 1 then
        return moved == true
    elseif color == 2 then
        return moved ~= true
    end
    -- White (0) and any unknown color always damage.
    return true
end

return shouldDamage
