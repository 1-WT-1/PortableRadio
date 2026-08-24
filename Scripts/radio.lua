local _print = print
local print = function(msg)
    _print(tostring(msg) .. "\n")
end

local UEHelpers = require("UEHelpers")
local Radio = {}

Radio.SpawnedRadio = nil
Radio.IsPlaying = false

local ActorClass = StaticFindObject("/Game/Assets/StaticMeshes/Mesh_Props/Prop_Radio01.Prop_Radio01_C")
local GameplayStatics = StaticFindObject("/Script/Engine.Default__GameplayStatics")
local SoundClassRadio = StaticFindObject("/Game/Assets/Sounds/SoundClasses/SC_Radio.SC_Radio")
local SoundClassMusic = StaticFindObject("/Game/Assets/Sounds/SoundClasses/SC_Music.SC_Music")
local SoundClassMaster = StaticFindObject("/Game/Assets/Sounds/SoundClasses/SC_Master.SC_Master")

function Radio.PlayCue(cuePath, config)
    if not config or not config.EnableToggleSound then return end
    local PC = UEHelpers.GetPlayerController()
    if not PC or not PC:IsValid() then return end
    if not GameplayStatics or not GameplayStatics:IsValid() then
        GameplayStatics = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    end
    local Cue = StaticFindObject(cuePath)
    if GameplayStatics and Cue then
        pcall(function()
            GameplayStatics:PlaySound2D(PC, Cue, config.ToggleSoundVolume, 1.0, 0.0, nil, nil, true)
        end)
    end
end

function Radio.IsPortableRadio(actor)
    if not actor or not actor:IsValid() then return false end

    local okLoc, loc = pcall(function() return actor:K2_GetActorLocation() end)
    if okLoc and loc and loc.Z and loc.Z < -3000 then
        return true
    end

    local okHidden, hidden = pcall(function() return actor.bHidden end)
    if okHidden and hidden == true then
        return true
    end

    return false
end

function Radio.CleanLeftoverRadios()
    pcall(function()
        local allRadios = FindAllOf("Prop_Radio01_C")
        if allRadios then
            for _, r in ipairs(allRadios) do
                if r and r:IsValid() and Radio.IsPortableRadio(r) then
                    print("[PortableRadio] Destroying leftover underground radio: " .. r:GetFullName() .. "\n")
                    pcall(function()
                        if r.Toggle_Power then r:Toggle_Power(false) end
                        local mp = r.MediaPlayer
                        if mp and mp:IsValid() and mp.Close then mp:Close() end
                    end)
                    pcall(function() r:K2_DestroyActor() end)
                end
            end
        end
    end)
end

function Radio.ApplyVolume(volume)
    if not Radio.SpawnedRadio or not Radio.SpawnedRadio:IsValid() then return end
    pcall(function()
        Radio.SpawnedRadio.Volume = volume
        local ms = Radio.SpawnedRadio.MediaSound
        if ms and ms:IsValid() and ms.SetVolumeMultiplier then
            ms:SetVolumeMultiplier(volume)
        end
    end)
end

function Radio.SelectNextTrack(currentVolume)
    if not Radio.SpawnedRadio or not Radio.SpawnedRadio:IsValid() then return end
    pcall(function()
        if Radio.SpawnedRadio.SelectNextSong then
            Radio.SpawnedRadio:SelectNextSong()
        end
    end)
    if currentVolume then
        Radio.ApplyVolume(currentVolume)
        ExecuteWithDelay(100, function() Radio.ApplyVolume(currentVolume) end)
    end
end

function Radio.GetCurrentSongName()
    if not Radio.SpawnedRadio or not Radio.SpawnedRadio:IsValid() then
        return "RADIO ON"
    end
    local title = "RADIO ON"
    pcall(function()
        if Radio.SpawnedRadio.CurrentSong then
            local s = Radio.SpawnedRadio.CurrentSong:ToString()
            if s and s ~= "" and s ~= "None" then
                title = s
            end
        end
    end)
    return title
end

function Radio.Spawn(currentVolume, config)
    local PC = UEHelpers.GetPlayerController()
    if not PC or not PC:IsValid() then return false end
    local Pawn = PC.Pawn
    if not Pawn or not Pawn:IsValid() then return false end
    local World = PC:GetWorld()
    if not World or not World:IsValid() then return false end

    if not ActorClass or not ActorClass:IsValid() then
        ActorClass = StaticFindObject("/Game/Assets/StaticMeshes/Mesh_Props/Prop_Radio01.Prop_Radio01_C")
    end
    if not ActorClass or not ActorClass:IsValid() then return false end

    Radio.CleanLeftoverRadios()

    local Loc = Pawn:K2_GetActorLocation()
    local SpawnLocation = { X = Loc.X, Y = Loc.Y, Z = Loc.Z - 9000 }
    local SpawnRotation = { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }

    Radio.SpawnedRadio = World:SpawnActor(ActorClass, SpawnLocation, SpawnRotation)

    if Radio.SpawnedRadio and Radio.SpawnedRadio:IsValid() then
        pcall(function()
            pcall(function() Radio.SpawnedRadio:SetActorEnableCollision(false) end)
            pcall(function() Radio.SpawnedRadio:SetActorHiddenInGame(true) end)

            local comps = { Radio.SpawnedRadio, Radio.SpawnedRadio.RootComponent, Radio.SpawnedRadio.PropMesh, Radio.SpawnedRadio.Box }
            for _, comp in ipairs(comps) do
                if comp and comp:IsValid() then
                    if comp.SetEnableGravity then pcall(function() comp:SetEnableGravity(false) end) end
                    if comp.SetCollisionEnabled then pcall(function() comp:SetCollisionEnabled(0) end) end
                end
            end

            Radio.SpawnedRadio.Powered = true
            Radio.SpawnedRadio.Working = true
            Radio.SpawnedRadio.Volume = currentVolume
            pcall(function() Radio.SpawnedRadio.bTickEvenWhenPaused = true end)
            pcall(function() Radio.SpawnedRadio.PrimaryActorTick.bTickEvenWhenPaused = true end)

            if Radio.SpawnedRadio.Toggle_Power then Radio.SpawnedRadio:Toggle_Power(true) end

            local stationCue = StaticFindObject("/Game/Assets/Sounds/Music/RadioStation_02_Rebel_Cue.RadioStation_02_Rebel_Cue")
                or StaticFindObject("/Game/Assets/Sounds/Music/RadioStation_01_Cue.RadioStation_01_Cue")
            if stationCue and stationCue:IsValid() and Radio.SpawnedRadio.SetStation then
                Radio.SpawnedRadio:SetStation(stationCue)
            end

            if Radio.SpawnedRadio.SelectNextSong then Radio.SpawnedRadio:SelectNextSong() end

            local ms = Radio.SpawnedRadio.MediaSound
            local mp = Radio.SpawnedRadio.MediaPlayer
            if ms and ms:IsValid() then
                if ms.Stop then ms:Stop() end
                if ms.Deactivate then ms:Deactivate() end

                ms.bAllowSpatialization = false
                ms.bUISound = true
                pcall(function() ms.bIsUISound = true end)
                ms.bOverrideAttenuation = true
                ms.AttenuationSettings = nil

                if not SoundClassRadio or not SoundClassRadio:IsValid() then
                    SoundClassRadio = StaticFindObject("/Game/Assets/Sounds/SoundClasses/SC_Radio.SC_Radio")
                    SoundClassMusic = StaticFindObject("/Game/Assets/Sounds/SoundClasses/SC_Music.SC_Music")
                    SoundClassMaster = StaticFindObject("/Game/Assets/Sounds/SoundClasses/SC_Master.SC_Master")
                end

                if SoundClassRadio and SoundClassRadio:IsValid() then
                    ms.SoundClass = SoundClassRadio
                elseif SoundClassMusic and SoundClassMusic:IsValid() then
                    ms.SoundClass = SoundClassMusic
                elseif SoundClassMaster and SoundClassMaster:IsValid() then
                    ms.SoundClass = SoundClassMaster
                end

                if mp and mp:IsValid() and ms.SetMediaPlayer then ms:SetMediaPlayer(mp) end
                if ms.Activate then ms:Activate(true) end
                if ms.Start then ms:Start() end

                Radio.ApplyVolume(currentVolume)
                ExecuteWithDelay(100, function() Radio.ApplyVolume(currentVolume) end)
            end
        end)
        Radio.IsPlaying = true
        if config and config.dprint then
            config.dprint(string.format("[PortableRadio] Spawned radio actor at underground Z=%.1f. Volume: %.2f", SpawnLocation.Z, currentVolume))
        end
        return true
    end

    return false
end

function Radio.Destroy(config)
    Radio.IsPlaying = false
    if Radio.SpawnedRadio and Radio.SpawnedRadio:IsValid() then
        pcall(function()
            if Radio.SpawnedRadio.Toggle_Power then Radio.SpawnedRadio:Toggle_Power(false) end
            local mp = Radio.SpawnedRadio.MediaPlayer
            if mp and mp:IsValid() and mp.Close then mp:Close() end
        end)
        pcall(function() Radio.SpawnedRadio:K2_DestroyActor() end)
        if config and config.dprint then config.dprint("[PortableRadio] Destroyed radio actor.") end
    end
    Radio.SpawnedRadio = nil
    collectgarbage("collect")
end

return Radio
