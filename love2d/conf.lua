function love.conf(t)
    t.identity = "sans-fight"
    t.version = "11.4"
    t.console = false

    t.window.title = "Bad Time Simulator (Sans Fight)"
    t.window.width = 640
    t.window.height = 480
    t.window.resizable = false
    t.window.vsync = 1

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = false
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
    t.modules.thread = false
end
