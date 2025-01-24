-- Init module for character controller

local Controller = {}
Controller.__index = Controller

function Controller.new()
    local self = setmetatable({}, Controller)
    self.simulation = require(script.simulation)
end

function Controller:getSimulation()
    return self.simulation
end

return Controller.new()