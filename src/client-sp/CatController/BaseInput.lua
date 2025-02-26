--!strict
-- Abstract base class for character controller input.

local ConnectionUtil = require(script.Parent.Common.ConnectionUtil)

export type BaseMoveInputType  = {
    new: () -> BaseMoveInputType,
    getMoveVec: (BaseMoveInputType) -> Vector3,
    getIsJumping: (BaseMoveInputType) -> boolean,
    getIsRunning: (BaseMoveInputType) -> boolean,
    enable: (BaseMoveInputType, enable: boolean) -> boolean,

    _connectionUtil: any,

    enabled: boolean,
    isJumping: boolean,
    isRunning: boolean,
    moveVec: Vector3
}

local VEC3_ZERO = Vector3.zero

local BaseMoveInput = {} :: BaseMoveInputType
(BaseMoveInput :: any).__index = BaseMoveInput

function BaseMoveInput.new()
    local self = setmetatable({}, BaseMoveInput)

    self._connectionUtil = ConnectionUtil.new()

    self.enabled = false
    self.isJumping = false
    self.isRunning = false
    self.moveVec = VEC3_ZERO

    return self :: any
end

function BaseMoveInput:getMoveVec(): Vector3
    return self.moveVec
end

function BaseMoveInput:getIsJumping(): boolean
    return self.isJumping
end

function BaseMoveInput:getIsRunning(): boolean
    return self.isRunning
end

function BaseMoveInput:enable(enable: boolean): boolean
    error("cannot enable abstract class BaseMoveInput", 2)
    return false
end

return BaseMoveInput