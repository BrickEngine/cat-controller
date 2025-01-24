-- Abstract base class for character controller input.

local ConnectionUtil = require(script.Parent.Common.ConnectionUtil)

export type BaseMoveInputType  = {
    new: () -> BaseMoveInputType,
    getMoveVec: (BaseMoveInputType) -> Vector3,
    enable: (BaseMoveInputType) -> boolean,

    enabled: boolean,
    isJumping: boolean,
    moveVec: Vector3,
    _connectionUtil: any
}

local VEC3_ZERO = Vector3.zero

local BaseMoveInput = {} :: BaseMoveInputType
(BaseMoveInput :: any).__index = BaseMoveInput

function BaseMoveInput.new()
    local self = setmetatable({}, BaseMoveInput)

    self.enabled = false
    self.jumpInp = false
    self.moveVec = VEC3_ZERO
    self.__connectionUtil = ConnectionUtil.new()

    return self :: any
end

function BaseMoveInput:getMoveVec(): Vector3
    return self.moveVec
end

function BaseMoveInput:init(): boolean
    return false
end

return BaseMoveInput