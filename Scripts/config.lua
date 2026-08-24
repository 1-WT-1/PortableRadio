local _print = print
local print = function(msg)
    _print(tostring(msg) .. "\n")
end

local Config = {}

local ScriptDir = debug.getinfo(1).source:match("@?(.*[\\/])") or ""
ScriptDir = ScriptDir:gsub("[\\/]$", "")
local BaseDir = ScriptDir:gsub("[\\/]Scripts$", "")

Config.ScriptDir = ScriptDir
Config.BaseDir = BaseDir
Config.ConfigFilePath = nil

Config.Debug = false
Config.ToggleKey = "F5"
Config.VolumeUpKey = "Add"
Config.VolumeDownKey = "Subtract"
Config.NextTrackKey = "F4"

Config.EnableToggleSound = true
Config.ToggleSoundVolume = 1.0
Config.DefaultVolume = 0.8
Config.VolumeStep = 0.05

Config.ShowHUD = true
Config.ShowWithoutEquippedHUD = false
Config.AutoHideWhenOff = true
Config.TransitionDuration = 1.0
Config.FadeDuration = 0.3

Config.ShowVolumeSlider = true
Config.SliderHideDelay = 1.5
Config.SliderWidth = 260.0
Config.SliderHeight = 10.0

Config.FontSize = 18
Config.EnableMarquee = true
Config.MaxVisibleCharacters = 24
Config.MarqueeSpeed = 3.0

Config.ShowIcon = true
Config.IconSize = 14.0
Config.IconSpacing = 6.0

Config.Anchor = "BottomLeft"
Config.OffsetX = 108.0
Config.OffsetY = -148.0

function Config.dprint(msg)
    if Config.Debug then
        print(msg)
    end
end

function Config.Load()
    local path = BaseDir .. "/config.ini"
    local file = io.open(path, "r")
    if not file then
        path = ScriptDir .. "/config.ini"
        file = io.open(path, "r")
    end
    if not file then
        print("[PortableRadio] config.ini not found, using default settings.\n")
        return
    end

    Config.ConfigFilePath = path
    local section = nil

    for line in file:lines() do
        if not line:match("^%s*[#;]") and line:match("%S") then
            local s = line:match("^%s*%[([^%]]+)%]")
            if s then
                section = s
            else
                local key, val = line:match("^%s*([^=]+)%s*=%s*(.*)")
                if key and val then
                    key = key:match("^%s*(.-)%s*$")
                    val = val:gsub("%s+[#;].*$", ""):match("^%s*(.-)%s*$")
                    local num = tonumber(val)
                    local low = val:lower()
                    local bool = (low == "true" or low == "1" or low == "yes")

                    if section == "General" then
                        if key == "Debug" then Config.Debug = bool end
                    elseif section == "Keybinds" then
                        if key == "ToggleKey" then Config.ToggleKey = val end
                        if key == "VolumeUpKey" then Config.VolumeUpKey = val end
                        if key == "VolumeDownKey" then Config.VolumeDownKey = val end
                        if key == "NextTrackKey" then Config.NextTrackKey = val end
                    elseif section == "Audio" then
                        if key == "EnableToggleSound" then Config.EnableToggleSound = bool end
                        if key == "ToggleSoundVolume" and num then Config.ToggleSoundVolume = num end
                        if key == "DefaultVolume" and num then Config.DefaultVolume = num end
                        if key == "VolumeStep" and num then Config.VolumeStep = num end
                    elseif section == "HUD" then
                        if key == "ShowHUD" then Config.ShowHUD = bool end
                        if key == "ShowWithoutEquippedHUD" then Config.ShowWithoutEquippedHUD = bool end
                        if key == "AutoHideWhenOff" then Config.AutoHideWhenOff = bool end
                        if key == "TransitionDuration" and num then Config.TransitionDuration = num end
                        if key == "FadeDuration" and num then Config.FadeDuration = num end
                    elseif section == "VolumeSlider" then
                        if key == "ShowVolumeSlider" then Config.ShowVolumeSlider = bool end
                        if key == "SliderHideDelay" and num then Config.SliderHideDelay = num end
                        if key == "SliderWidth" and num then Config.SliderWidth = num end
                        if key == "SliderHeight" and num then Config.SliderHeight = num end
                    elseif section == "Text" then
                        if key == "FontSize" and num then Config.FontSize = math.floor(num) end
                        if key == "EnableMarquee" then Config.EnableMarquee = bool end
                        if key == "MaxVisibleCharacters" and num then Config.MaxVisibleCharacters = math.floor(num) end
                        if key == "MarqueeSpeed" and num then Config.MarqueeSpeed = num end
                    elseif section == "Icon" then
                        if key == "ShowIcon" then Config.ShowIcon = bool end
                        if key == "IconSize" and num then Config.IconSize = num end
                        if key == "IconSpacing" and num then Config.IconSpacing = num end
                    elseif section == "Position" then
                        if key == "Anchor" then Config.Anchor = val end
                        if key == "OffsetX" and num then Config.OffsetX = num end
                        if key == "OffsetY" and num then Config.OffsetY = num end
                    end
                end
            end
        end
    end

    file:close()
    Config.dprint("[PortableRadio] Configuration loaded successfully.")
end

function Config.SaveVolume(volume)
    if not Config.ConfigFilePath or not volume then return end
    pcall(function()
        local file = io.open(Config.ConfigFilePath, "r")
        if not file then return end
        local content = file:read("*all")
        file:close()
        if not content then return end

        local newContent = content:gsub("(DefaultVolume%s*=%s*)[%d%.]+", string.format("%%1%.2f", volume))
        local outFile = io.open(Config.ConfigFilePath, "w")
        if outFile then
            outFile:write(newContent)
            outFile:close()
            Config.DefaultVolume = volume
            Config.dprint(string.format("[PortableRadio] Saved persistent volume %.2f to config.ini", volume))
        end
    end)
end

function Config.ResolveFKey(keyStr)
    if not keyStr or keyStr == "" or keyStr:lower() == "none" or keyStr:lower() == "nil" then return nil end
    local clean = keyStr:match("^%s*(.-)%s*$")
    return { KeyName = FName(clean) }
end

function Config.ParseKeybind(keyStr)
    if not keyStr or keyStr == "" or keyStr:lower() == "none" or keyStr:lower() == "nil" then
        return nil
    end

    local modStr = nil
    local mainStr = keyStr

    local trimmed = keyStr:match("^%s*(.-)%s*$")
    if trimmed:find("+", 1, true) then
        local parts = {}
        for part in trimmed:gmatch("[^+]+") do
            table.insert(parts, part:match("^%s*(.-)%s*$"))
        end
        if #parts >= 2 then
            modStr = parts[1]
            mainStr = parts[2]
        end
    end

    local modType = nil
    if modStr and modStr ~= "" and modStr:lower() ~= "none" and modStr:lower() ~= "nil" then
        local cleanMod = modStr:gsub("[%s_]+", ""):upper()
        if cleanMod == "SHIFT" then
            modType = "SHIFT"
        elseif cleanMod == "CTRL" or cleanMod == "CONTROL" then
            modType = "CTRL"
        elseif cleanMod == "ALT" then
            modType = "ALT"
        else
            modType = Config.ResolveFKey(modStr)
        end
    end

    local fkey = Config.ResolveFKey(mainStr)
    if not fkey then return nil end

    return {
        Key = fkey,
        Modifier = modType,
        RawKey = mainStr,
        RawModifier = modStr,
    }
end

return Config
