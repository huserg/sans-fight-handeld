-- Ordered fight script: one entry per turn.
-- event: nil | "spare_offer" | "final"
--
-- Dialogue strings are the original Bad Time Simulator between-turn InfoText,
-- transcribed verbatim from ../Event sheets/Battle.xml. In the original the
-- lines are gated on the SansLegs.HitAttempts dodge counter; here they are
-- mapped to the matching turn:
--   HitAttempts 0 (KR 0) -> sans_bonegap1   "sins crawling"
--   first phase flavor    -> sans_bluebone   "bad time"
--   HitAttempts 13        -> sans_spare      "taking a break"
--   HitAttempts 15        -> sans_multi1     "REAL battle"
--   HitAttempts 19        -> sans_bonestab2  "best use of time"
--   HitAttempts 20        -> sans_randomblaster2 "really tired"
--   HitAttempts 21        -> sans_boneslidev "preparing something"
--   HitAttempts 22        -> sans_multi3     "special attack"
return {
    { attack = "sans_intro",            dialogue = "" },
    { attack = "sans_bonegap1",         dialogue = "* You felt your sins crawling\n  on your back." },
    { attack = "sans_bluebone",         dialogue = "* You feel like you're going to\n  have a bad time." },
    { attack = "sans_bonegap2",         dialogue = "" },
    { attack = "sans_platforms1",       dialogue = "" },
    { attack = "sans_platforms2",       dialogue = "" },
    { attack = "sans_platforms3",       dialogue = "" },
    { attack = "sans_platforms4",       dialogue = "" },
    { attack = "sans_platformblaster",  dialogue = "" },
    { attack = "sans_platforms4hard",   dialogue = "" },
    { attack = "sans_bonegap1fast",     dialogue = "" },
    { attack = "sans_boneslideh",       dialogue = "" },
    { attack = "sans_bonegap2",         dialogue = "" },
    { attack = "sans_platformblasterfast", dialogue = "" },
    { attack = "sans_spare",            dialogue = "* Sans is taking a break.", event = "spare_offer" },
    { attack = "sans_multi1",           dialogue = "* The REAL battle finally begins." },
    { attack = "sans_randomblaster1",   dialogue = "" },
    { attack = "sans_multi2",           dialogue = "" },
    { attack = "sans_bonestab1",        dialogue = "" },
    { attack = "sans_bonestab2",        dialogue = "* Reading this doesn't seem\n  like the best use of time." },
    { attack = "sans_randomblaster2",   dialogue = "* Sans is starting to look\n  really tired." },
    { attack = "sans_boneslidev",       dialogue = "* Sans is preparing something." },
    { attack = "sans_multi3",           dialogue = "* Sans is getting ready to\n  use his special attack." },
    { attack = "sans_bonestab3",        dialogue = "" },
    { attack = "sans_final",            dialogue = "", event = "final" },
}
