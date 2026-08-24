local _print = print
local print = function(msg)
    _print(tostring(msg) .. "\n")
end

local UEHelpers = require("UEHelpers")
local Input = {}

Input.CachedPC = nil

Input.BindingToggle = nil
Input.BindingVolUp = nil
Input.BindingVolDown = nil
Input.BindingNextTrack = nil

Input.FKeyLeftShift = nil
Input.FKeyRightShift = nil
Input.FKeyLeftControl = nil
Input.FKeyRightControl = nil
Input.FKeyLeftAlt = nil
Input.FKeyRightAlt = nil

Input.LastKeyStateToggle = false
Input.LastKeyStateNextTrack = false
Input.LastKeyStateVolUp = false
Input.LastKeyStateVolDown = false

Input.HoldTimerVolUp = 0.0
Input.HoldTimerVolDown = 0.0
Input.HOLD_INITIAL_DELAY = 0.30
Input.HOLD_REPEAT_RATE = 0.05

function Input.Init(config)
    Input.FKeyLeftShift = config.ResolveFKey("LeftShift")
    Input.FKeyRightShift = config.ResolveFKey("RightShift")
    Input.FKeyLeftControl = config.ResolveFKey("LeftControl")
    Input.FKeyRightControl = config.ResolveFKey("RightControl")
    Input.FKeyLeftAlt = config.ResolveFKey("LeftAlt")
    Input.FKeyRightAlt = config.ResolveFKey("RightAlt")

    Input.BindingToggle = config.ParseKeybind(config.ToggleKey)
    Input.BindingVolUp = config.ParseKeybind(config.VolumeUpKey)
    Input.BindingVolDown = config.ParseKeybind(config.VolumeDownKey)
    Input.BindingNextTrack = config.ParseKeybind(config.NextTrackKey)

    local function formatBindingLog(name, binding, rawConfigKey)
        if not binding then return end
        if binding.Modifier then
            local modDisplay = type(binding.Modifier) == "string" and binding.Modifier or binding.Modifier.KeyName:ToString()
            print(string.format("[PortableRadio] Bound %s: %s (Key: %s, Modifier: %s)", name, rawConfigKey, binding.Key.KeyName:ToString(), modDisplay))
        else
            print(string.format("[PortableRadio] Bound %s: %s (Key: %s)", name, rawConfigKey, binding.Key.KeyName:ToString()))
        end
    end

    formatBindingLog("ToggleKey", Input.BindingToggle, config.ToggleKey)
    formatBindingLog("VolumeUpKey", Input.BindingVolUp, config.VolumeUpKey)
    formatBindingLog("VolumeDownKey", Input.BindingVolDown, config.VolumeDownKey)
    formatBindingLog("NextTrackKey", Input.BindingNextTrack, config.NextTrackKey)
end

function Input.GetPlayerController()
    if not Input.CachedPC or not Input.CachedPC:IsValid() then
        Input.CachedPC = UEHelpers.GetPlayerController()
    end
    return Input.CachedPC
end

local function IsModifierActive(mod, PC)
    if not mod then return true end
    if mod == "SHIFT" then
        local lDown = false
        local rDown = false
        if Input.FKeyLeftShift then pcall(function() lDown = PC:IsInputKeyDown(Input.FKeyLeftShift) end) end
        if Input.FKeyRightShift then pcall(function() rDown = PC:IsInputKeyDown(Input.FKeyRightShift) end) end
        return lDown or rDown
    elseif mod == "CTRL" then
        local lDown = false
        local rDown = false
        if Input.FKeyLeftControl then pcall(function() lDown = PC:IsInputKeyDown(Input.FKeyLeftControl) end) end
        if Input.FKeyRightControl then pcall(function() rDown = PC:IsInputKeyDown(Input.FKeyRightControl) end) end
        return lDown or rDown
    elseif mod == "ALT" then
        local lDown = false
        local rDown = false
        if Input.FKeyLeftAlt then pcall(function() lDown = PC:IsInputKeyDown(Input.FKeyLeftAlt) end) end
        if Input.FKeyRightAlt then pcall(function() rDown = PC:IsInputKeyDown(Input.FKeyRightAlt) end) end
        return lDown or rDown
    else
        local down = false
        pcall(function() down = PC:IsInputKeyDown(mod) end)
        return down
    end
end

local function IsBindingDown(binding, PC)
    if not binding or not binding.Key then return false end
    if not IsModifierActive(binding.Modifier, PC) then return false end
    local isDown = false
    pcall(function() isDown = PC:IsInputKeyDown(binding.Key) end)
    return isDown
end

function Input.Process(dt, isRadioPlaying, callbacks)
    local PC = Input.GetPlayerController()
    if not PC or not PC:IsValid() then
        Input.Reset()
        return
    end

    local Pawn = PC.Pawn
    if not Pawn or not Pawn:IsValid() then
        Input.Reset()
        return
    end

    if Input.BindingToggle then
        local isDown = IsBindingDown(Input.BindingToggle, PC)
        if isDown and not Input.LastKeyStateToggle then
            if callbacks and callbacks.onToggle then callbacks.onToggle() end
        end
        Input.LastKeyStateToggle = isDown
    end

    if isRadioPlaying then
        if Input.BindingNextTrack then
            local isDown = IsBindingDown(Input.BindingNextTrack, PC)
            if isDown and not Input.LastKeyStateNextTrack then
                if callbacks and callbacks.onNextTrack then callbacks.onNextTrack() end
            end
            Input.LastKeyStateNextTrack = isDown
        end

        if Input.BindingVolUp then
            local isDown = IsBindingDown(Input.BindingVolUp, PC)
            if isDown then
                if not Input.LastKeyStateVolUp then
                    if callbacks and callbacks.onVolumeAdjust then callbacks.onVolumeAdjust(true) end
                    Input.HoldTimerVolUp = 0.0
                else
                    Input.HoldTimerVolUp = Input.HoldTimerVolUp + dt
                    if Input.HoldTimerVolUp >= Input.HOLD_INITIAL_DELAY then
                        Input.HoldTimerVolUp = Input.HoldTimerVolUp - Input.HOLD_REPEAT_RATE
                        if callbacks and callbacks.onVolumeAdjust then callbacks.onVolumeAdjust(true) end
                    end
                end
            else
                Input.HoldTimerVolUp = 0.0
            end
            Input.LastKeyStateVolUp = isDown
        end

        if Input.BindingVolDown then
            local isDown = IsBindingDown(Input.BindingVolDown, PC)
            if isDown then
                if not Input.LastKeyStateVolDown then
                    if callbacks and callbacks.onVolumeAdjust then callbacks.onVolumeAdjust(false) end
                    Input.HoldTimerVolDown = 0.0
                else
                    Input.HoldTimerVolDown = Input.HoldTimerVolDown + dt
                    if Input.HoldTimerVolDown >= Input.HOLD_INITIAL_DELAY then
                        Input.HoldTimerVolDown = Input.HoldTimerVolDown - Input.HOLD_REPEAT_RATE
                        if callbacks and callbacks.onVolumeAdjust then callbacks.onVolumeAdjust(false) end
                    end
                end
            else
                Input.HoldTimerVolDown = 0.0
            end
            Input.LastKeyStateVolDown = isDown
        end
    else
        Input.LastKeyStateNextTrack = false
        Input.LastKeyStateVolUp = false
        Input.LastKeyStateVolDown = false
    end
end

function Input.Reset()
    Input.LastKeyStateToggle = false
    Input.LastKeyStateNextTrack = false
    Input.LastKeyStateVolUp = false
    Input.LastKeyStateVolDown = false
    Input.HoldTimerVolUp = 0.0
    Input.HoldTimerVolDown = 0.0
end

return Input
