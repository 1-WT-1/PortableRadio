local _print = print
local print = function(msg)
    _print(tostring(msg) .. "\n")
end

local UEHelpers = require("UEHelpers")
local Input = {}

Input.CachedPC = nil

Input.FKeyToggle = nil
Input.FKeyVolUp = nil
Input.FKeyVolDown = nil
Input.FKeyNextTrack = nil

Input.LastKeyStateToggle = false
Input.LastKeyStateNextTrack = false
Input.LastKeyStateVolUp = false
Input.LastKeyStateVolDown = false

Input.HoldTimerVolUp = 0.0
Input.HoldTimerVolDown = 0.0
Input.HOLD_INITIAL_DELAY = 0.30
Input.HOLD_REPEAT_RATE = 0.05

function Input.Init(config)
    Input.FKeyToggle = config.ResolveFKey(config.ToggleKey)
    Input.FKeyVolUp = config.ResolveFKey(config.VolumeUpKey)
    Input.FKeyVolDown = config.ResolveFKey(config.VolumeDownKey)
    Input.FKeyNextTrack = config.ResolveFKey(config.NextTrackKey)

    if Input.FKeyToggle then print(string.format("[PortableRadio] Bound ToggleKey: %s (FName: %s)", config.ToggleKey, Input.FKeyToggle.KeyName:ToString())) end
    if Input.FKeyVolUp then print(string.format("[PortableRadio] Bound VolumeUpKey: %s (FName: %s)", config.VolumeUpKey, Input.FKeyVolUp.KeyName:ToString())) end
    if Input.FKeyVolDown then print(string.format("[PortableRadio] Bound VolumeDownKey: %s (FName: %s)", config.VolumeDownKey, Input.FKeyVolDown.KeyName:ToString())) end
    if Input.FKeyNextTrack then print(string.format("[PortableRadio] Bound NextTrackKey: %s (FName: %s)", config.NextTrackKey, Input.FKeyNextTrack.KeyName:ToString())) end
end

function Input.GetPlayerController()
    if not Input.CachedPC or not Input.CachedPC:IsValid() then
        Input.CachedPC = UEHelpers.GetPlayerController()
    end
    return Input.CachedPC
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

    if Input.FKeyToggle then
        local isDown = false
        pcall(function() isDown = PC:IsInputKeyDown(Input.FKeyToggle) end)
        if isDown and not Input.LastKeyStateToggle then
            if callbacks and callbacks.onToggle then callbacks.onToggle() end
        end
        Input.LastKeyStateToggle = isDown
    end

    if isRadioPlaying then
        if Input.FKeyNextTrack then
            local isDown = false
            pcall(function() isDown = PC:IsInputKeyDown(Input.FKeyNextTrack) end)
            if isDown and not Input.LastKeyStateNextTrack then
                if callbacks and callbacks.onNextTrack then callbacks.onNextTrack() end
            end
            Input.LastKeyStateNextTrack = isDown
        end

        if Input.FKeyVolUp then
            local isDown = false
            pcall(function() isDown = PC:IsInputKeyDown(Input.FKeyVolUp) end)
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

        if Input.FKeyVolDown then
            local isDown = false
            pcall(function() isDown = PC:IsInputKeyDown(Input.FKeyVolDown) end)
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
