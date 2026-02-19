--[[
    Mapping of character specific joints and parts.
]]

-- table of joints to simulate and replicate
local JOINT_NAMES = {
    ROOT = "ROOT",
    TORSO_0 = "CHEST",
    TORSO_1 = "HIP",
    --neck
    NECK_0 = "NECK_0",
    NECK_1 = "NECK_1",
    -- tail
    TAIL_0 = "TAIL_0",
    TAIL_1 = "TAIL_1",
    TAIL_2 = "TAIL_2",
    TAIL_3 = "TAIL_3",
    TAIL_4 = "TAIL_4",
    TAIL_5 = "TAIL_5",
    TAIL_6 = "TAIL_6",
    -- front left
    FL_LEG_0 = "FL_LEG_0",
    FL_LEG_1 = "FL_LEG_1",
    FL_LEG_2 = "FL_LEG_2",
    FL_PAW = "FL_PAW",
    -- front right
    FR_LEG_0 = "FR_LEG_0",
    FR_LEG_1 = "FR_LEG_1",
    FR_LEG_2 = "FR_LEG_2",
    FR_PAW = "FR_PAW",
    -- rear left
    RL_LEG_0 = "RL_LEG_0",
    RL_LEG_1 = "RL_LEG_1",
    RL_LEG_2 = "RL_LEG_2",
    RL_PAW = "RL_PAW",
    -- rear right
    RR_LEG_0 = "RR_LEG_0",
    RR_LEG_1 = "RR_LEG_1",
    RR_LEG_2 = "RR_LEG_2",
    RR_PAW = "RR_PAW"
}

-- index table for iterating joints
-- defines where Vector3 C0 rotation offsets are indexed for reading from or writing for events
local JOINT_INDEX_ARR = {
    "ROOT",
    "TORSO_0",
    "TORSO_1",
    "NECK_0",
    "NECK_1",
    "TAIL_0",
    "TAIL_1",
    "TAIL_2",
    "TAIL_3",
    "TAIL_4",
    "TAIL_5",
    "TAIL_6",
    "FL_LEG_0",
    "FL_LEG_1",
    "FL_LEG_2",
    "FL_PAW",
    "FR_LEG_0",
    "FR_LEG_1",
    "FR_PAW",
    "RL_LEG_0",
    "RL_LEG_1",
    "RL_LEG_2",
    "RL_PAW",
    "RR_LEG_0",
    "RR_LEG_1",
    "RR_LEG_2",
    "FR_LEG_2",
    "RR_PAW",
}

-- parts that are connected to joints to be used by IKControl
local PART_NAMES = {
    -- torso
    UPPER_TORSO = "TorsoUpperTop",
    LOWER_TORSO = "TorsoLowerTop",
    -- front left
    FL_BICEP = "BicepTopLeft",
    FL_ARM = "ArmTopLeft",
    FL_WRIST = "WristTopLeft",
    FL_PAW = "PawLeftFront",
    -- front right
    FR_BICEP = "BicepTopRight",
    FR_ARM = "ArmTopRight",
    FR_WRIST = "WristTopRight",
    FR_PAW = "PawRightFront",
    -- rear left
    RL_THIGH = "ThighLeft",
    RL_LEG = "LegTopLeft",
    RL_ANKLE = "AnkleTopLeft",
    RL_PAW = "PawLeftBack",
    -- rear right
    RR_THIGH = "ThighRight",
    RR_LEG = "LegTopRight",
    RR_ANKLE = "AnkleTopRight",
    RR_PAW = "PawRightBack",
}

local JointMap = table.freeze{
    JOINT_NAMES = JOINT_NAMES,
    JOINT_INDEX_ARR = JOINT_INDEX_ARR,
    PART_NAMES = PART_NAMES
}

return JointMap