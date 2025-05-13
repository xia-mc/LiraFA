return {
    LuaVersion = "Lua51",
    VarNamePrefix = "",
    NameGenerator = "MangledShuffled",
    PrettyPrint = false,
    Seed = 0,
    Steps = {
        -- {
        --     Name = "ProxifyLocals",
        --     Settings = {
        --         LiteralType = "number"
        --     }
        -- },
        {
            Name = "SplitStrings",
            Settings = {
                Treshold = 0.2,
                ConcatenationType = "custom",
                CustomFunctionType = "local",
                CustomLocalFunctionsCount = 1
            }
        },
        {
            Name = "EncryptStrings",
            Settings = {
            }
        },
        {
            Name = "SplitStrings",
            Settings = {
                Treshold = 1,
                ConcatenationType = "custom",
                CustomFunctionType = "local",
                CustomLocalFunctionsCount = 3
            }
        },
        {
            Name = "ConstantArray",
            Settings = {
                Treshold = 1,
                StringsOnly = false,
                Shuffle = true,
                Rotate = false,
                LocalWrapperTreshold = 1,
                LocalWrapperArgCount = 128,
                MaxWrapperOffset = 128
            }
        },
        {
            Name = "WrapInFunction",
            Settings = {
                Iterations = 1
            }
        }
    }
}
