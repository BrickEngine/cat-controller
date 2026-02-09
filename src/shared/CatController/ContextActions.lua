local Actions = {
    -- movement
    MOVE_L = "moveLeftAction",
    MOVE_R = "moveRightAction",
    MOVE_F = "moveForwardAction",
    MOVE_B = "moveBackwardAction",
    MOVE_THUMBSTICK = "moveThumbstickAction",
    JUMP = "jumpAction",
    JUMP_BUTTON = "jumpButtonAction",
    RUN = "runAction",
    RUN_BUTTON = "runButtonAction",
    SPEED_U = "speedUpAction",
    SPEED_D = "speedDownAction",
    SHIFT_BUTTON = "shiftButtonAction",
    -- camera
    CAM_L = "camRotateLeftAction",
    CAM_R = "camRotateRightAction",
    CAM_U = "camRotateUpACtion",
    CAM_D = "camRotateDownAction",
    -- special
    SIT = "sitAction",
    -- other
    MENU = "MenuOpenAction"
}

return Actions