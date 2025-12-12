-- Game constants

local Constants = {
    -- Screen dimensions
    SCREEN_W = 640,
    SCREEN_H = 480,

    -- Game modes
    MODE_NORMAL = 0,
    MODE_ENDLESS = 1,
    MODE_SINGLE = 2,
    MODE_PRACTICE = 3,

    -- Heart modes
    HEARTMODE_RED = 0,
    HEARTMODE_BLUE = 1,

    -- Player defaults
    DEFAULT_HP = 92,
    DEFAULT_MAX_HP = 92,

    -- Input deadzone for analog sticks
    STICK_DEADZONE = 0.25,

    -- Combat zone default bounds
    COMBAT_ZONE = {
        x1 = 239,
        y1 = 226,
        x2 = 404,
        y2 = 391
    },

    -- Colors
    COLORS = {
        WHITE = {1, 1, 1},
        BLACK = {0, 0, 0},
        RED = {1, 0, 0},
        YELLOW = {1, 1, 0},
        BLUE = {0, 0, 1},
        PURPLE = {0.5, 0, 0.5}
    }
}

return Constants
