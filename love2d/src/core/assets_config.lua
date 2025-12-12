-- Assets configuration
-- Defines paths, dimensions, and settings for all game assets

local AssetsConfig = {
    -- Fonts configuration
    fonts = {
        default = {
            path = "assets/fonts/defaultfont.png",
            charWidth = 10,
            charHeight = 16,
            cols = 16,
            rows = 6,
            startChar = 32,
            hasLowercase = true
        },
        battle = {
            path = "assets/fonts/battlefont.png",
            charWidth = 6,
            charHeight = 6,
            cols = 16,
            rows = 4,
            startChar = 32,
            hasLowercase = false
        },
        sans = {
            path = "assets/fonts/sansfont.png",
            charWidth = 16,
            charHeight = 16,
            cols = 16,
            rows = 6,
            startChar = 32,
            hasLowercase = true
        },
        damage = {
            path = "assets/fonts/damagefont.png",
            charWidth = 33,
            charHeight = 32,
            cols = 16,
            rows = 6,
            startChar = 32,
            hasLowercase = true
        }
    },

    -- Sprites configuration
    sprites = {
        playerHeart = {
            path = "assets/sprites/playerheart.png",
            width = 16,
            height = 16,
            originX = 8,
            originY = 8
        },
        boneH = {
            path = "assets/sprites/boneh.png",
            width = 24,
            height = 10
        },
        boneV = {
            path = "assets/sprites/bonev.png",
            width = 10,
            height = 24
        },
        boneStabH = {
            path = "assets/sprites/bonestabh.png",
            width = 24,
            height = 12
        },
        boneStabV = {
            path = "assets/sprites/bonestabv.png",
            width = 12,
            height = 24
        },
        boneStabWarn = {
            path = "assets/sprites/bonestabwarn.png",
            width = 16,
            height = 16
        },
        combatZone = {
            path = "assets/sprites/combatzone.png"
        },
        combatZoneBorder = {
            path = "assets/sprites/combatzoneborder.png"
        }
    },

    -- Audio configuration
    audio = {
        music = {
            megalovania = {
                path = "assets/audio/mus_zz_megalovania.ogg",
                type = "stream"
            }
        },
        sfx = {
            menuSelect = {
                path = "assets/audio/menuselect.ogg",
                type = "static"
            },
            menuCursor = {
                path = "assets/audio/menucursor.ogg",
                type = "static"
            },
            ding = {
                path = "assets/audio/ding.ogg",
                type = "static"
            },
            playerDamaged = {
                path = "assets/audio/playerdamaged.ogg",
                type = "static"
            }
        }
    },

    -- UI configuration
    ui = {
        menu = {
            titleY = 32,
            itemStartY = 96,
            itemSpacing = 32,
            itemX = 224,
            heartOffsetX = -32,
            heartOffsetY = 12
        },
        combatZone = {
            defaultX1 = 239,
            defaultY1 = 226,
            defaultX2 = 404,
            defaultY2 = 391
        }
    }
}

return AssetsConfig
