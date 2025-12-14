-- Sans Character Test
-- Complete sprite viewer with all poses and category navigation

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")

local TestSans = {
    images = {},
    currentTab = 1,
    -- FullBody navigation
    currentCategory = 1,
    currentBody = 1,
    currentHead = 1,
    showSweat = false,
    sweatFrame = 1,
    -- Debug mode
    debugMode = false,
}

local TABS = {"FullBody", "Head", "Body", "Torso", "Legs", "Sweat"}

-- HEAD frames: 32x30 each (9 expressions)
local HEAD_FRAMES = {
    {1, 1, 32, 30, "Default"},
    {35, 1, 32, 30, "LookLeft"},
    {69, 1, 32, 30, "Wink"},
    {1, 33, 32, 30, "ClosedEyes"},
    {35, 33, 32, 30, "NoEyes"},
    {69, 33, 32, 30, "BlueEye1"},
    {1, 65, 32, 30, "BlueEye2"},
    {35, 65, 32, 30, "Tired1"},
    {69, 65, 32, 30, "Tired2"},
}

-- BODY frames: {x, y, w, h, name, headOffsetX, headOffsetY}
-- headOffset is relative (0-1) where to attach head on body
local BODY_FRAMES = {
    -- HandDown (idle) 64x70
    {99, 101, 64, 70, "idle0", 0.47, 0.4},
    {165, 101, 64, 70, "idle1", 0.47, 0.386},
    {1, 151, 64, 70, "idle2", 0.47, 0.429},
    {67, 173, 64, 70, "idle3", 0.47, 0.443},
    -- HandUp 64x70
    {133, 173, 64, 70, "handup", 0.47, 0.429},
    -- HandRight 96x48
    {1, 1, 96, 48, "right0", 0.34, 0.125},
    {99, 1, 96, 48, "right1", 0.32, 0.125},
    {1, 51, 96, 48, "right2", 0.31, 0.125},
    {99, 51, 96, 48, "right3", 0.375, 0.125},
    {1, 101, 96, 48, "right4", 0.35, 0.125},
}

-- TORSO frames: {x, y, w, h, name, headOffsetX, headOffsetY}
local TORSO_FRAMES = {
    {1, 27, 54, 25, "Default", 0.5, 0.24},
    {1, 1, 72, 24, "Shrug", 0.5, 0.208},
}

-- LEGS frames: {x, y, w, h, name, torsoOffsetX, torsoOffsetY}
local LEGS_FRAMES = {
    {1, 1, 44, 23, "Standing", 0.477, 0},
    {1, 26, 52, 17, "Sitting", 0.481, 0.059},
}

-- SWEAT frames: 32x9
local SWEAT_FRAMES = {
    {1, 1, 32, 9, "Sweat1"},
    {1, 12, 32, 9, "Sweat2"},
    {1, 23, 32, 9, "Sweat3"},
}

-- Categories for navigation
local CATEGORIES = {
    {
        name = "Idle",
        mode = "body",
        bodies = {1, 2, 3, 4},
    },
    {
        name = "HandUp",
        mode = "body",
        bodies = {5},
    },
    {
        name = "HandRight",
        mode = "body",
        bodies = {6, 7, 8, 9, 10},
    },
    {
        name = "Standing",
        mode = "parts",
        legs = 1,
        torso = 1,
    },
    {
        name = "Shrug",
        mode = "parts",
        legs = 1,
        torso = 2,
    },
    {
        name = "Sitting",
        mode = "parts",
        legs = 2,
        torso = 1,
    },
}

function TestSans:enter(game)
    self.game = game
    Fonts:load()
    self.currentTab = 1
    self.currentCategory = 1
    self.currentBody = 1
    self.currentHead = 1
    self.showSweat = false
    self.sweatFrame = 1

    -- Load all images
    self.images.head = love.graphics.newImage("assets/sprites/sanshead-sheet0.png")
    self.images.body = love.graphics.newImage("assets/sprites/sansbody-sheet0.png")
    self.images.torso = love.graphics.newImage("assets/sprites/sanstorso-sheet0.png")
    self.images.legs = love.graphics.newImage("assets/sprites/sanslegs-sheet0.png")
    self.images.sweat = love.graphics.newImage("assets/sprites/sanssweat-sheet0.png")

    for _, img in pairs(self.images) do
        img:setFilter("nearest", "nearest")
    end
end

function TestSans:update(dt, game)
    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("test_menu")
        return
    end

    if self.currentTab == 1 then
        -- FullBody tab: category navigation
        local cat = CATEGORIES[self.currentCategory]

        -- Left/Right: change category
        if Input:justPressed("left") then
            self.currentCategory = self.currentCategory - 1
            if self.currentCategory < 1 then self.currentCategory = #CATEGORIES end
            self.currentBody = 1
        elseif Input:justPressed("right") then
            self.currentCategory = self.currentCategory + 1
            if self.currentCategory > #CATEGORIES then self.currentCategory = 1 end
            self.currentBody = 1
        end

        -- Up/Down: change body frame in category
        if cat.mode == "body" then
            if Input:justPressed("up") then
                self.currentBody = self.currentBody - 1
                if self.currentBody < 1 then self.currentBody = #cat.bodies end
            elseif Input:justPressed("down") then
                self.currentBody = self.currentBody + 1
                if self.currentBody > #cat.bodies then self.currentBody = 1 end
            end
        end

        -- Z/X: change head expression
        if Input:justPressed("confirm") then
            self.currentHead = self.currentHead + 1
            if self.currentHead > #HEAD_FRAMES then self.currentHead = 1 end
        end

        -- S: toggle sweat (keyboard only)
        if love.keyboard.isDown("s") and not self._sPressed then
            self.showSweat = not self.showSweat
            self._sPressed = true
        elseif not love.keyboard.isDown("s") then
            self._sPressed = false
        end

        -- V: change sweat frame (use menu button)
        if self.showSweat and Input:justPressed("menu") then
            self.sweatFrame = self.sweatFrame + 1
            if self.sweatFrame > #SWEAT_FRAMES then self.sweatFrame = 1 end
        end

        -- D: toggle debug mode (keyboard only)
        if love.keyboard.isDown("d") and not self._dPressed then
            self.debugMode = not self.debugMode
            self._dPressed = true
        elseif not love.keyboard.isDown("d") then
            self._dPressed = false
        end
    else
        -- Other tabs: simple left/right navigation
        if Input:justPressed("left") then
            self.currentTab = self.currentTab - 1
            if self.currentTab < 1 then self.currentTab = #TABS end
        elseif Input:justPressed("right") then
            self.currentTab = self.currentTab + 1
            if self.currentTab > #TABS then self.currentTab = 1 end
        end
    end
end

function TestSans:draw(game)
    -- Tab indicators at top
    local tabX = 55
    for i, tab in ipairs(TABS) do
        if i == self.currentTab then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
        end
        Fonts.default:setScale(1)
        Fonts.default:draw(tab, tabX, 10, "center")
        tabX = tabX + 100
    end

    -- Draw current tab content
    if self.currentTab == 1 then
        self:drawFullBody()
    elseif self.currentTab == 2 then
        self:drawFrames(self.images.head, HEAD_FRAMES, 2)
    elseif self.currentTab == 3 then
        self:drawFrames(self.images.body, BODY_FRAMES, 1.2)
    elseif self.currentTab == 4 then
        self:drawFrames(self.images.torso, TORSO_FRAMES, 2)
    elseif self.currentTab == 5 then
        self:drawFrames(self.images.legs, LEGS_FRAMES, 2)
    elseif self.currentTab == 6 then
        self:drawFrames(self.images.sweat, SWEAT_FRAMES, 3)
    end

    -- Controls
    love.graphics.setColor(0.5, 0.5, 0.5)
    if self.currentTab == 1 then
        Fonts.default:draw("L/R:Cat | U/D:Frame | Z:Head | S:Sweat | D:Debug | Esc:Back", 320, 460, "center")
    else
        Fonts.default:draw("Left/Right: Switch tab | Esc: Back", 320, 460, "center")
    end
end

function TestSans:drawFullBody()
    local cat = CATEGORIES[self.currentCategory]
    local headFrame = HEAD_FRAMES[self.currentHead]

    local scale = 3
    local centerX = 180
    local centerY = 280

    -- Get image dimensions for quads
    local headImgW, headImgH = self.images.head:getDimensions()
    local bodyImgW, bodyImgH = self.images.body:getDimensions()
    local torsoImgW, torsoImgH = self.images.torso:getDimensions()
    local legsImgW, legsImgH = self.images.legs:getDimensions()
    local sweatImgW, sweatImgH = self.images.sweat:getDimensions()

    -- Create head quad
    local headQuad = love.graphics.newQuad(headFrame[1], headFrame[2], headFrame[3], headFrame[4], headImgW, headImgH)

    local headX, headY

    local bodyX, bodyY, bodyW, bodyH
    local debugInfo = {}

    if cat.mode == "body" then
        -- Mode Body + Head
        local bodyIdx = cat.bodies[self.currentBody]
        local bodyFrame = BODY_FRAMES[bodyIdx]
        local bodyQuad = love.graphics.newQuad(bodyFrame[1], bodyFrame[2], bodyFrame[3], bodyFrame[4], bodyImgW, bodyImgH)

        -- Body position (centered)
        bodyW = bodyFrame[3] * scale
        bodyH = bodyFrame[4] * scale
        bodyX = centerX - bodyW / 2
        bodyY = centerY - bodyH / 2

        -- Head position using offsets from body frame
        local headOffsetX = bodyFrame[6] or 0.5
        local headOffsetY = bodyFrame[7] or 0.4
        local headW = headFrame[3] * scale
        local headH = headFrame[4] * scale

        -- Attachment point on body
        local attachX = bodyX + bodyW * headOffsetX
        local attachY = bodyY + bodyH * headOffsetY

        headX = attachX - headW / 2
        headY = attachY - headH

        -- Draw body then head
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.images.body, bodyQuad, bodyX, bodyY, 0, scale, scale)
        love.graphics.draw(self.images.head, headQuad, headX, headY, 0, scale, scale)

        -- Store debug info
        debugInfo = {
            {name = "Body", x = bodyX, y = bodyY, w = bodyW, h = bodyH, color = {1, 0, 0}},
            {name = "Head", x = headX, y = headY, w = headW, h = headH, color = {0, 1, 0}},
            attachPoint = {x = attachX, y = attachY},
            offsets = {x = headOffsetX, y = headOffsetY},
        }

        -- Draw info
        love.graphics.setColor(1, 1, 0)
        local info = cat.name .. " " .. self.currentBody .. "/" .. #cat.bodies .. " | " .. bodyFrame[5]
        Fonts.default:draw(info, centerX, 40, "center")

    else
        -- Mode Parts: Legs + Torso + Head
        local legsFrame = LEGS_FRAMES[cat.legs]
        local torsoFrame = TORSO_FRAMES[cat.torso]

        local legsQuad = love.graphics.newQuad(legsFrame[1], legsFrame[2], legsFrame[3], legsFrame[4], legsImgW, legsImgH)
        local torsoQuad = love.graphics.newQuad(torsoFrame[1], torsoFrame[2], torsoFrame[3], torsoFrame[4], torsoImgW, torsoImgH)

        -- Legs at bottom
        local legsW = legsFrame[3] * scale
        local legsH = legsFrame[4] * scale
        local legsX = centerX - legsW / 2
        local legsY = centerY + 20

        -- Torso above legs
        local torsoW = torsoFrame[3] * scale
        local torsoH = torsoFrame[4] * scale
        local torsoOffsetX = legsFrame[6] or 0.5
        local torsoAttachX = legsX + legsW * torsoOffsetX
        local torsoX = torsoAttachX - torsoW / 2
        local torsoY = legsY - torsoH + 5 * scale

        -- Head above torso
        local headOffsetX = torsoFrame[6] or 0.5
        local headOffsetY = torsoFrame[7] or 0.24
        local headW = headFrame[3] * scale
        local headH = headFrame[4] * scale
        local headAttachX = torsoX + torsoW * headOffsetX
        local headAttachY = torsoY + torsoH * headOffsetY
        headX = headAttachX - headW / 2
        headY = headAttachY - headH

        -- Draw legs, torso, head
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.images.legs, legsQuad, legsX, legsY, 0, scale, scale)
        love.graphics.draw(self.images.torso, torsoQuad, torsoX, torsoY, 0, scale, scale)
        love.graphics.draw(self.images.head, headQuad, headX, headY, 0, scale, scale)

        -- Store debug info
        debugInfo = {
            {name = "Legs", x = legsX, y = legsY, w = legsW, h = legsH, color = {1, 0.5, 0}},
            {name = "Torso", x = torsoX, y = torsoY, w = torsoW, h = torsoH, color = {1, 0, 0}},
            {name = "Head", x = headX, y = headY, w = headW, h = headH, color = {0, 1, 0}},
            attachPoint = {x = headAttachX, y = headAttachY},
            torsoAttach = {x = torsoAttachX, y = legsY},
        }

        -- Draw info
        love.graphics.setColor(1, 1, 0)
        local info = cat.name .. " | " .. legsFrame[5] .. " + " .. torsoFrame[5]
        Fonts.default:draw(info, centerX, 40, "center")
    end

    -- Draw debug overlay
    if self.debugMode then
        love.graphics.setLineWidth(2)

        -- Draw bounding boxes
        for i, box in ipairs(debugInfo) do
            if box.name then
                love.graphics.setColor(box.color[1], box.color[2], box.color[3], 0.5)
                love.graphics.rectangle("line", box.x, box.y, box.w, box.h)
                love.graphics.setColor(box.color[1], box.color[2], box.color[3], 1)
                Fonts.default:draw(box.name, box.x + 2, box.y + 2, "left")
            end
        end

        -- Draw attachment points
        if debugInfo.attachPoint then
            love.graphics.setColor(1, 1, 0)
            love.graphics.circle("fill", debugInfo.attachPoint.x, debugInfo.attachPoint.y, 5)
            love.graphics.setColor(0, 0, 0)
            love.graphics.circle("line", debugInfo.attachPoint.x, debugInfo.attachPoint.y, 5)
        end
        if debugInfo.torsoAttach then
            love.graphics.setColor(1, 0.5, 0)
            love.graphics.circle("fill", debugInfo.torsoAttach.x, debugInfo.torsoAttach.y, 4)
        end

        -- Draw offset values
        love.graphics.setColor(1, 1, 1)
        local dbgY = 380
        Fonts.default:draw("DEBUG MODE (D to toggle)", 10, dbgY, "left")
        if debugInfo.offsets then
            Fonts.default:draw("HeadOffset: X=" .. debugInfo.offsets.x .. " Y=" .. debugInfo.offsets.y, 10, dbgY + 15, "left")
        end
        if debugInfo.attachPoint then
            Fonts.default:draw("AttachPt: " .. math.floor(debugInfo.attachPoint.x) .. "," .. math.floor(debugInfo.attachPoint.y), 10, dbgY + 30, "left")
        end

        love.graphics.setLineWidth(1)
    end

    -- Draw sweat if enabled
    if self.showSweat then
        local sweatFrame = SWEAT_FRAMES[self.sweatFrame]
        local sweatQuad = love.graphics.newQuad(sweatFrame[1], sweatFrame[2], sweatFrame[3], sweatFrame[4], sweatImgW, sweatImgH)
        local sweatW = sweatFrame[3] * scale
        local sweatX = headX + (headFrame[3] * scale) / 2 - sweatW / 2
        local sweatY = headY - 5 * scale

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.images.sweat, sweatQuad, sweatX, sweatY, 0, scale, scale)
    end

    -- Draw reference panel on the right
    self:drawReferencePanel(headFrame)
end

function TestSans:drawReferencePanel(headFrame)
    local cat = CATEGORIES[self.currentCategory]
    local headImgW, headImgH = self.images.head:getDimensions()
    local bodyImgW, bodyImgH = self.images.body:getDimensions()
    local torsoImgW, torsoImgH = self.images.torso:getDimensions()
    local legsImgW, legsImgH = self.images.legs:getDimensions()
    local sweatImgW, sweatImgH = self.images.sweat:getDimensions()

    local headQuad = love.graphics.newQuad(headFrame[1], headFrame[2], headFrame[3], headFrame[4], headImgW, headImgH)

    love.graphics.setColor(1, 1, 1)
    local refX = 370
    local refY = 35
    local spacing = 70

    -- Category info
    love.graphics.setColor(0, 1, 1)
    Fonts.default:draw("Cat: " .. self.currentCategory .. "/" .. #CATEGORIES, refX, refY, "left")

    -- Head reference
    refY = refY + 25
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("Head " .. self.currentHead .. ": " .. headFrame[5], refX, refY, "left")
    love.graphics.draw(self.images.head, headQuad, refX + 150, refY - 5, 0, 1.5, 1.5)

    if cat.mode == "body" then
        -- Body reference
        local bodyIdx = cat.bodies[self.currentBody]
        local bodyFrame = BODY_FRAMES[bodyIdx]
        local bodyQuad = love.graphics.newQuad(bodyFrame[1], bodyFrame[2], bodyFrame[3], bodyFrame[4], bodyImgW, bodyImgH)

        refY = refY + spacing
        Fonts.default:draw("Body: " .. bodyFrame[5], refX, refY, "left")
        love.graphics.draw(self.images.body, bodyQuad, refX + 150, refY - 5, 0, 0.8, 0.8)
    else
        -- Torso reference
        local torsoFrame = TORSO_FRAMES[cat.torso]
        local torsoQuad = love.graphics.newQuad(torsoFrame[1], torsoFrame[2], torsoFrame[3], torsoFrame[4], torsoImgW, torsoImgH)

        refY = refY + spacing
        Fonts.default:draw("Torso: " .. torsoFrame[5], refX, refY, "left")
        love.graphics.draw(self.images.torso, torsoQuad, refX + 150, refY - 5, 0, 1.5, 1.5)

        -- Legs reference
        local legsFrame = LEGS_FRAMES[cat.legs]
        local legsQuad = love.graphics.newQuad(legsFrame[1], legsFrame[2], legsFrame[3], legsFrame[4], legsImgW, legsImgH)

        refY = refY + spacing
        Fonts.default:draw("Legs: " .. legsFrame[5], refX, refY, "left")
        love.graphics.draw(self.images.legs, legsQuad, refX + 150, refY - 5, 0, 1.5, 1.5)
    end

    -- Sweat reference
    if self.showSweat then
        local sweatFrame = SWEAT_FRAMES[self.sweatFrame]
        local sweatQuad = love.graphics.newQuad(sweatFrame[1], sweatFrame[2], sweatFrame[3], sweatFrame[4], sweatImgW, sweatImgH)

        refY = refY + spacing
        love.graphics.setColor(1, 1, 0)
        Fonts.default:draw("Sweat " .. self.sweatFrame .. ": ON", refX, refY, "left")
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.images.sweat, sweatQuad, refX + 150, refY - 5, 0, 2, 2)
    else
        refY = refY + spacing
        love.graphics.setColor(0.5, 0.5, 0.5)
        Fonts.default:draw("Sweat: OFF (C)", refX, refY, "left")
    end
end

function TestSans:drawFrames(image, frames, scale)
    local imgW, imgH = image:getDimensions()

    -- Draw full spritesheet at top
    local sheetX = 20
    local sheetY = 60
    local sheetScale = math.min(200 / imgW, 150 / imgH)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, sheetX, sheetY, 0, sheetScale, sheetScale)

    -- Draw frame boxes on spritesheet
    love.graphics.setLineWidth(1)
    for i, f in ipairs(frames) do
        local x = sheetX + f[1] * sheetScale
        local y = sheetY + f[2] * sheetScale
        local w = f[3] * sheetScale
        local h = f[4] * sheetScale

        if i % 2 == 0 then
            love.graphics.setColor(0, 1, 0, 0.8)
        else
            love.graphics.setColor(1, 1, 0, 0.8)
        end
        love.graphics.rectangle("line", x, y, w, h)
    end

    -- Draw individual frames below
    local frameX = 20
    local frameY = 230
    local maxPerRow = 5
    local col = 0

    for i, f in ipairs(frames) do
        -- Create quad for this frame
        local quad = love.graphics.newQuad(f[1], f[2], f[3], f[4], imgW, imgH)

        -- Draw frame
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(image, quad, frameX, frameY, 0, scale, scale)

        -- Draw border
        love.graphics.setColor(0, 1, 0, 0.5)
        love.graphics.rectangle("line", frameX, frameY, f[3] * scale, f[4] * scale)

        -- Draw label
        love.graphics.setColor(1, 1, 1)
        Fonts.default:draw(f[5], frameX, frameY + f[4] * scale + 2, "left")

        -- Next position
        col = col + 1
        frameX = frameX + 120

        if col >= maxPerRow then
            col = 0
            frameX = 20
            frameY = frameY + 100
        end
    end

    -- Info
    love.graphics.setColor(0.7, 0.7, 0.7)
    Fonts.default:draw("Sheet: " .. imgW .. "x" .. imgH .. " | Frames: " .. #frames, 400, 60, "left")
end

function TestSans:exit()
    self.images = {}
end

return TestSans
