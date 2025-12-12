-- Sprite Font System
-- Simple bitmap font renderer for Undertale-style fonts

local AssetsConfig = require("src.core.assets_config")

local SpriteFont = {}
SpriteFont.__index = SpriteFont

function SpriteFont.new(imagePath, charWidth, charHeight)
    local self = setmetatable({}, SpriteFont)

    self.image = love.graphics.newImage(imagePath)
    self.image:setFilter("nearest", "nearest")

    self.charWidth = charWidth
    self.charHeight = charHeight
    self.scale = 1
    self.spacing = 0

    local imgW, imgH = self.image:getDimensions()
    self.cols = math.floor(imgW / charWidth)
    self.rows = math.floor(imgH / charHeight)
    self.imgW = imgW
    self.imgH = imgH

    -- Character width overrides for variable-width rendering
    self.charWidths = {}

    return self
end

function SpriteFont:getQuad(char)
    -- Get ASCII code and calculate position
    -- Font starts at ASCII 32 (space)
    local code = string.byte(char) or 32
    local idx = code - 32

    if idx < 0 or idx >= self.cols * self.rows then
        idx = 0  -- Default to space
    end

    local col = idx % self.cols
    local row = math.floor(idx / self.cols)

    return love.graphics.newQuad(
        col * self.charWidth,
        row * self.charHeight,
        self.charWidth,
        self.charHeight,
        self.imgW,
        self.imgH
    )
end

function SpriteFont:setCharWidth(chars, width)
    for i = 1, #chars do
        local char = chars:sub(i, i)
        self.charWidths[string.byte(char)] = width
    end
end

function SpriteFont:setScale(scale)
    self.scale = scale
end

function SpriteFont:setSpacing(spacing)
    self.spacing = spacing
end

function SpriteFont:getCharWidth(char)
    local code = string.byte(char)
    return self.charWidths[code] or self.charWidth
end

function SpriteFont:getWidth(text)
    local width = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        width = width + self:getCharWidth(char) + self.spacing
    end
    return (width - self.spacing) * self.scale
end

function SpriteFont:getHeight()
    return self.charHeight * self.scale
end

function SpriteFont:draw(text, x, y, align, maxWidth)
    align = align or "left"
    text = tostring(text)

    local textWidth = self:getWidth(text)
    local startX = x

    if align == "center" then
        startX = x - textWidth / 2
        if maxWidth then
            startX = x + (maxWidth - textWidth) / 2
        end
    elseif align == "right" then
        startX = x - textWidth
        if maxWidth then
            startX = x + maxWidth - textWidth
        end
    end

    local curX = startX
    for i = 1, #text do
        local char = text:sub(i, i)
        local quad = self:getQuad(char)
        love.graphics.draw(self.image, quad, curX, y, 0, self.scale, self.scale)
        curX = curX + (self:getCharWidth(char) + self.spacing) * self.scale
    end
end

-- Font Manager
local Fonts = {
    loaded = false,
    default = nil,
    battle = nil,
    sans = nil,
    damage = nil
}

function Fonts:load()
    if self.loaded then return end

    local cfg = AssetsConfig.fonts

    -- DefaultFont
    self.default = SpriteFont.new(cfg.default.path, cfg.default.charWidth, cfg.default.charHeight)
    self.default:setCharWidth("#%&MWmw~", 9)
    self.default:setCharWidth(" $*+-./0123456789=?@ABCDEFGHIJKLNOPQRSTUVXYZ\\^abcdefghijklnopqrstuvxyz", 8)
    self.default:setCharWidth("\"<>{}", 7)
    self.default:setCharWidth("!()[]_", 6)
    self.default:setCharWidth("`", 5)
    self.default:setCharWidth("',:;|", 4)

    -- BattleFont
    self.battle = SpriteFont.new(cfg.battle.path, cfg.battle.charWidth, cfg.battle.charHeight)
    self.battle:setCharWidth("!\"#%-/0123456789<=>?ABCDEFGHIJKLNOPQRSTUVXYZ[\\]_", 5)
    self.battle:setCharWidth("\"()<>[]", 4)
    self.battle:setCharWidth(" -", 3)
    self.battle:setCharWidth("',.:;", 2)

    -- SansFont
    self.sans = SpriteFont.new(cfg.sans.path, cfg.sans.charWidth, cfg.sans.charHeight)
    self.sans:setCharWidth("W", 15)
    self.sans:setCharWidth("@", 14)
    self.sans:setCharWidth("%Q", 13)
    self.sans:setCharWidth("MO", 12)
    self.sans:setCharWidth("#&GNVX_", 11)
    self.sans:setCharWidth(" $ACHJSTUYZmw", 10)
    self.sans:setCharWidth("247?BDEKdxy~", 9)
    self.sans:setCharWidth("*+/0135689FILR\\^abcefghknopqrtuvz", 8)
    self.sans:setCharWidth("-=Pjs{}", 7)
    self.sans:setCharWidth("()<>[]", 6)
    self.sans:setCharWidth("\";`", 5)
    self.sans:setCharWidth("!',.:|l", 4)

    -- DamageFont
    self.damage = SpriteFont.new(cfg.damage.path, cfg.damage.charWidth, cfg.damage.charHeight)
    self.damage:setCharWidth("~", 29)
    self.damage:setCharWidth("\"/^<>Ij{}", 25)
    self.damage:setCharWidth("(),1[]`", 21)
    self.damage:setCharWidth("!'.:;il|", 17)

    self.loaded = true
end

return Fonts
