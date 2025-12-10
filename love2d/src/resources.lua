local Resources = {}
Resources.__index = Resources

function Resources.new()
  local self = setmetatable({}, Resources)
  local base = love.filesystem.getSourceBaseDirectory()
  local root = base .. "/../Textures/"
  local function image(name)
    return love.graphics.newImage(root .. name)
  end
  self.images = {
    boneV = image("BoneV.png"),
    boneH = image("BoneH.png"),
    blaster = image("GasterBlast3.png"),
    beam = image("GasterBlastHit.png"),
    platform = image("Platform1.png"),
    sansHead = image("SansFont.png"),
  }
  self.font = love.graphics.newFont(14)
  return self
end

return Resources
