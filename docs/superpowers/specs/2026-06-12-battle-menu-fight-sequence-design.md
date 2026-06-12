# Battle Menu and Full Fight Sequence — Design

Date: 2026-06-12
Status: Approved

## Goal

Bring the Love2D port to a complete, faithful Normal mode: the player turn menu
(Fight/Act/Item/Mercy), damage numbers, KR display, the exact attack sequence of
the original fight with Sans dialogue between turns, all endings, and the three
attack commands the sequencer is still missing (Platform, BoneStab, SineBones).

Reference for all behavior: the original Construct 2 event sheets
(`Event sheets/Battle.xml`, `Items.xml`, `Menus.xml`) and `Documentation/Attacks.md`.
When this document and the event sheets disagree, the event sheets win.

## Scope

In scope:
- Turn-based phase machine inside the battle state
- Battle menu UI with sub-menus and all four actions
- Damage numbers (MISS and hit values)
- KR display unification (single HP bar component)
- Fight script data with the full attack order and per-turn Sans dialogue
- Endings: game over (heart shatter), "get dunked on" (spare accepted), victory
- Sequencer commands: Platform, PlatformRepeat, BoneStab, SineBones
- Test menu entries for each new component

Out of scope:
- Full Sans body animations during attacks (HandUp/HandDown/slam), sweat levels
- Touch controls
- Endless mode changes (keeps its current random spawner)

## Architecture

Scene-level states stay as they are (menu, loading, battle). Inside the battle
state, a phase machine delegates to small phase modules, each implementing
`enter(battle)`, `update(dt)`, `draw()`:

```
src/states/battle.lua              orchestrator: owns combat zone, Sans, heart,
                                   entities, music, collisions, setPhase()
src/states/battle_phases/
    player_turn.lua                menu active, heart hidden, zone widened
    action_resolve.lua             resolves the chosen action
    sans_dialogue.lua              Sans speech bubble before his attack
    attack.lua                     current CSV sequencer logic, extracted
src/systems/turn_manager.lua       advances through the fight script,
                                   decides which phase comes next
src/data/fight_script.lua          pure data: per turn -> attack, dialogue, event
src/ui/battle_menu.lua             4-button navigation + sub-menus
src/ui/damage_number.lua           DamageFont floating numbers
```

Phases never reference each other; only `turn_manager` decides transitions.
Single and Endless modes never enter `player_turn` (current behavior kept).

### Turn flow (Normal / Practice)

1. Attack CSV ends (`EndAttack`): combat zone widens into the dialogue box
   (existing resize animation), heart disappears, buttons become active.
2. Player turn: left/right moves selection across Fight/Act/Item/Mercy
   (selected quad + red heart on the button). Confirm opens the sub-menu in the
   box, cancel goes back one level.
3. Action resolves (see Battle menu below).
4. Sans dialogue: speech bubble above Sans with the turn line (existing
   `dialogue.lua` typewriter), confirm to dismiss.
5. Zone shrinks to the attack size, heart reappears centered, attack phase runs,
   back to step 1.

## Battle menu

Navigation sounds: menu move + confirm SFX (use existing audio assets; verify
exact names during implementation).

- FIGHT: target sub-menu ("* Sans", `targetchoice` sprite). Confirm starts the
  attack bar: `target` sprite fills the box, cursor sweeps left to right,
  confirm stops it, `strike` slash animation plays, Sans dodges sideways and a
  MISS damage number shows above him. Scripted exception: on the final turn
  (Sans asleep) the hit connects and triggers the victory sequence.
- ACT: single option "* Check" -> box text:
  `* SANS 1 ATK 1 DEF * The easiest enemy. * Can only deal 1 damage.`
- ITEM: the four original items, one of each, consumed on use:
  Butterscotch Pie (+99), Instant Noodles (+90), Face Steak (+60),
  Legendary Hero (+40). Heal SFX + "* You ate the [item]. * You recovered X HP!"
  HP capped at 92.
- MERCY: "* Spare" and "* Flee". Flee exits to the main menu. Spare does
  nothing outside the spare offer turn; on that turn it triggers the
  "get dunked on" ending.

Box text reuses the `dialogue.lua` typewriter rendering.

## Damage numbers and KR

- `ui/damage_number.lua`: reusable component. DamageFont text (MISS in gray,
  hit values in red) spawning above the target, rising with a small bounce,
  gone after about one second.
- HP bar duplication removed: `battle_ui.lua` delegates the bar to `hp_bar.lua`
  (which already has smooth HP, purple KR segment, and the KR label),
  repositioned inside the bottom bar. The purple KR label blinks while karma
  drains. Gameplay karma logic in `player_heart.lua` is unchanged.

## Fight script

`data/fight_script.lua` is an ordered table, one entry per turn:
`{ attack = "...", dialogue = "...", event = nil | "spare_offer" | "final" }`.

Attack order, extracted from `Battle.xml` (NextAttack chain):

- Turns 1-14 (phase 1): sans_intro, sans_bonegap1, sans_bluebone, sans_bonegap2,
  sans_platforms1, sans_platforms2, sans_platforms3, sans_platforms4,
  sans_platformblaster, sans_platforms4hard, sans_bonegap1fast, sans_boneslideh,
  sans_bonegap2, sans_platformblasterfast
- Turn 15: spare offer (sans_spare — Sans lowers his guard)
- Turns 16-24 (phase 2): sans_multi1, sans_randomblaster1, sans_multi2,
  sans_bonestab1, sans_bonestab2, sans_randomblaster2, sans_boneslidev,
  sans_multi3, sans_bonestab3
- Turn 25: sans_final (the "special attack"), then Sans falls asleep and the
  next FIGHT connects -> victory

Exact per-turn Sans dialogue lines are extracted from `Battle.xml` during
implementation planning; they are data only and do not affect architecture.

## Endings

- Game over: HP <= 0 -> music stops, short pause, heart shatter animation
  (`heartshard` sprites + existing heartShatter SFX), back to main menu.
  Faithful to the original simulator: no Undertale "stay determined" screen.
- Get dunked on: Spare accepted on the offer turn -> dialogue, scripted
  unavoidable attack, forced game over.
- Victory: final hit connects -> damage number, Sans dialogue, he leaves the
  screen, back to main menu.
- Practice mode: HP never drops below 1, game over disabled.

## New sequencer commands

Parameters per `Documentation/Attacks.md`:

- `Platform(X, Y, Width, Direction, Speed, BooleanReverse)` and
  `PlatformRepeat(StartX, StartY, Width, Direction, Speed, Count, Spacing)`:
  new `entities/platform.lua` using `platform1/2` sprites. The blue-mode heart
  lands on it from above only and is carried with it.
- `BoneStab(Direction, Distance, WarnTime, StayTime)`: new
  `entities/bone_stab.lua`. Warning sprite (`bonestabwarn`) shown for WarnTime,
  then a bone wall (`bonestabh`/`bonestabv`) bursts from the zone edge over
  Distance, stays for StayTime, retracts.
- `SineBones(Count, Spacing, Speed, Height)`: generated with the existing
  `bone.lua` entity — a series of bone pairs leaving a sine-wave gap.

## Revision 1 (2026-06-12): attack CSV virtual machine

Planning analysis of the 24 attack CSVs revealed that they are small programs,
not linear timelines. 18 of the 24 sequence attacks (including sans_final) use:

- Variables: read with `$Name`; written by SET/ADD/SUB/MUL/DIV/MOD/FLOOR/DEG/
  RAD/SIN/COS/ANGLE/RND (see `Documentation/Math.md`)
- Labels (`:Name`) and ten jump opcodes (JMPABS/JMPREL/JMPZ/JMPNZ/JMPE/JMPNE/
  JMPL/JMPNL/JMPG/JMPNG, see `Documentation/Jumps.md`); absolute jump targets
  are 1-based CSV line numbers or label names, `$var` allowed anywhere
- `GetHeartPos(XVarName, YVarName)` for aimed attacks

The current sequencer supports none of this, and analysis also exposed three
latent bugs in it:

1. The time column is a DELAY relative to the previous line, not an absolute
   timestamp (times decrease mid-file in linear attacks). The current
   absolute-time model plays even the six "ready" attacks with wrong timing.
2. `TLPause` only freezes the clock but still executes due events; with correct
   pause semantics, the standard `CombatZoneResize(..., TLResume)` + `TLPause`
   opening pattern requires TLResume to fire when the resize animation
   completes (`combatZone:isResizing()`), not instantly as today.
3. `BoneVRepeat`/`BoneHRepeat` real parameters are
   (StartX, StartY, Length, Direction, Speed, Count, Spacing); the current
   implementation misreads Count/Spacing as a gap and spawns a single bone.

Scope consequence: the VM is a hard prerequisite for the full fight sequence.
The work is split into three plans, each shipping testable software:

1. Sequencer VM: program-counter execution with relative delays, variables,
   labels, jumps, math opcodes, GetHeartPos, deferred TLResume. Unlocks
   sans_bonegap2, sans_multi1, sans_randomblaster1/2 in Single mode.
2. Entities and commands: Platform/PlatformRepeat, BoneStab, SineBones,
   SansSlam + SansSlamDamage, HeartMaxFallSpeed, CombatZoneSpeed, and the
   BoneV/HRepeat fix. Unlocks the remaining sequence attacks.
3. Battle menu, turn system, fight script and endings (the original spec body).

## Testing

- New test menu entries: battle menu navigation, platform riding (blue heart),
  bone stab timing, damage numbers.
- Single attack mode acts as the integration test for each platforms/bonestab
  CSV once the commands exist.
- Full sequence smoke test: Normal mode reaches turn 25 with Practice HP.
