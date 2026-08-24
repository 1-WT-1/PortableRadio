-- PortableRadio
-- Portable radio with HUD, marquee track display, and audio routing.

local ModName = "PortableRadio"
local ModVersion = "1.0.0"
print(string.format("[%s] v%s Initializing...", ModName, ModVersion))

local _print = print
local print = function(msg)
    _print(tostring(msg) .. "\n")
end

local ScriptDir = debug.getinfo(1).source:match("@?(.*[\\/])") or ""
ScriptDir = ScriptDir:gsub("[\\/]$", "")

package.path = package.path .. ";" .. ScriptDir .. "/?.lua"

local Config = dofile(ScriptDir .. "/config.lua")
local Radio = dofile(ScriptDir .. "/radio.lua")
local HUD = dofile(ScriptDir .. "/hud.lua")
local Input = dofile(ScriptDir .. "/input.lua")

Config.Load()
Input.Init(Config)

local dprint = Config.dprint

Radio.CleanLeftoverRadios()
ExecuteWithDelay(500, Radio.CleanLeftoverRadios)

local CurrentVolume = Config.DefaultVolume
local SaveVolumePending = false

local function AdjustVolume(delta)
    if not Radio.IsPlaying then return end

    CurrentVolume = math.max(0.0, math.min(2.0, CurrentVolume + delta))
    Radio.ApplyVolume(CurrentVolume)
    HUD.UpdateVolume(CurrentVolume)
    HUD.ShowVolumeSlider(Config)
    SaveVolumePending = true

    dprint(string.format("[%s] Volume adjusted: %.2f", ModName, CurrentVolume))
end
 
local function ToggleRadio()
    local PC = Input.GetPlayerController()
    if not PC or not PC:IsValid() or not PC.Pawn or not PC.Pawn:IsValid() then
        return
    end

    if not Config.ShowWithoutEquippedHUD and not HUD.IsHUDVisible then
        dprint(string.format("[%s] Toggle ignored: HUD is unequipped.", ModName))
        return
    end

    if not Radio.IsPlaying then
        dprint(string.format("[%s] Toggling ON...", ModName))
        Radio.PlayCue("/Game/Assets/Sounds/CUEs/Mechanical_Cues/Tape_Insert_Cue.Tape_Insert_Cue", Config)

        HUD.TryInject(Config, CurrentVolume, true)
        HUD.UIState = "TURNING_ON"
        HUD.StateTimer = 0.0
        HUD.TargetRenderOpacity = 1.0
        HUD.MarqueeOffset = 1
        HUD.MarqueeAccumulator = 0.0

        if HUD.MainContainer and HUD.MainContainer:IsValid() then
            pcall(function() HUD.MainContainer:SetVisibility(0) end)
        end
        if HUD.TextBlock and HUD.TextBlock:IsValid() then
            pcall(function() HUD.TextBlock:SetText(FText("RADIO ON")) end)
        end

        Radio.Spawn(CurrentVolume, Config)
    else
        dprint(string.format("[%s] Toggling OFF...", ModName))
        Radio.PlayCue("/Game/Assets/Sounds/CUEs/Mechanical_Cues/Tape_Eject_Cue.Tape_Eject_Cue", Config)

        HUD.UIState = "TURNING_OFF"
        HUD.StateTimer = 0.0
        HUD.DismissVolumeSlider()

        if HUD.TextBlock and HUD.TextBlock:IsValid() then
            pcall(function() HUD.TextBlock:SetText(FText("RADIO OFF")) end)
        end

        Radio.Destroy(Config)
    end
end

local function SafeLevelTeardown(hookName)
    ExecuteInGameThread(function()
        dprint(string.format("[%s] Teardown hook fired: %s", ModName, hookName))
        if Radio.IsPlaying then
            Radio.Destroy(Config)
        end
        HUD.Teardown()
        Input.Reset()
        Input.CachedPC = nil
        collectgarbage("collect")
    end)
end

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
    Input.CachedPC = self:get()
    SafeLevelTeardown("ClientRestart")
end)
RegisterHook("/Script/Engine.PlayerController:ClientTravel", function(self, URL, TravelType, bSeamless, bAbsolute) SafeLevelTeardown("ClientTravel") end)
RegisterHook("/Script/Engine.GameplayStatics:OpenLevel", function(self, WorldContextObject, LevelName, bAbsolute, Options) SafeLevelTeardown("OpenLevel") end)
RegisterHook("/Script/Engine.GameplayStatics:OpenLevelBySoftObjectPtr", function(self, WorldContextObject, Level, bAbsolute, Options) SafeLevelTeardown("OpenLevelBySoftObjectPtr") end)
RegisterHook("/Script/Engine.KismetSystemLibrary:QuitGame", function(self, WorldContextObject, SpecificPlayer, QuitPreference, bIgnorePlatformRestrictions) SafeLevelTeardown("QuitGame") end)

RegisterHook("/Script/Engine.GameplayStatics:SetGamePaused", function(self, WorldContextObject, bPaused)
    local bIsPaused = bPaused:get()
    if bIsPaused and Radio.IsPlaying then
        ExecuteInGameThread(function()
            if Radio.IsPlaying then
                ToggleRadio()
            end
        end)
    end
end)

LoopInGameThreadWithDelay(25, function()
    local dt = 0.025

    pcall(function()
        Input.Process(dt, Radio.IsPlaying, {
            onToggle = function() ToggleRadio() end,
            onNextTrack = function()
                Radio.SelectNextTrack(CurrentVolume)
                HUD.MarqueeOffset = 1
                HUD.MarqueeAccumulator = 0.0
                dprint(string.format("[%s] Next track requested. Now playing: %s", ModName, Radio.GetCurrentSongName()))
            end,
            onVolumeAdjust = function(isUp)
                AdjustVolume(isUp and Config.VolumeStep or -Config.VolumeStep)
            end
        })

        HUD.TryInject(Config, CurrentVolume, Radio.IsPlaying)

        HUD.Update(dt, Radio.IsPlaying, Radio.GetCurrentSongName(), Config, function()
            if SaveVolumePending then
                SaveVolumePending = false
                Config.SaveVolume(CurrentVolume)
            end
        end)

        if not Config.ShowWithoutEquippedHUD and not HUD.IsHUDVisible and Radio.IsPlaying then
            ToggleRadio()
        end
    end)

    return true
end)

print(string.format("[%s] v%s loaded successfully.", ModName, ModVersion))