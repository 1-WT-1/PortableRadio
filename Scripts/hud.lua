local _print = print
local print = function(msg)
    _print(tostring(msg) .. "\n")
end

local HUD = {}

local TextBlockClass = StaticFindObject("/Script/UMG.TextBlock")
local HBoxClass = StaticFindObject("/Script/UMG.HorizontalBox")
local VBoxClass = StaticFindObject("/Script/UMG.VerticalBox")
local SizeBoxClass = StaticFindObject("/Script/UMG.SizeBox")
local ImageClass = StaticFindObject("/Script/UMG.Image")
local ProgressBarClass = StaticFindObject("/Script/UMG.ProgressBar")
local RenderingLib = StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")

HUD.IsInjected = false
HUD.CachedHUDWidget = nil
HUD.MainContainer = nil
HUD.TitleRow = nil
HUD.TextBlock = nil
HUD.IconWidget = nil
HUD.VolumeRow = nil
HUD.VolProgressBar = nil
HUD.VolPctText = nil
HUD.IsHUDVisible = false

HUD.UIState = "OFF_HIDDEN" -- "OFF_HIDDEN", "TURNING_ON", "PLAYING", "TURNING_OFF", "FADING_OUT"
HUD.StateTimer = 0.0
HUD.CurrentRenderOpacity = 0.0
HUD.TargetRenderOpacity = 0.0

HUD.VolSliderTimer = 0.0
HUD.VolSliderOpacity = 0.0
HUD.VolSliderTargetOpacity = 0.0

HUD.LastRawSongName = ""
HUD.MarqueeOffset = 1
HUD.MarqueeAccumulator = 0.0

function HUD.CleanTrackTitle(title)
    if not title or title == "" or title == "None" then
        return "RADIO ON"
    end
    -- Strip .wav extension
    return title:gsub("%.[wW][aA][vV]$", "")
end

function HUD.GetMarqueeDisplayString(rawTitle, maxChars, enableMarquee)
    local title = HUD.CleanTrackTitle(rawTitle)
    if not title or title == "" or title == "None" then
        return "RADIO ON"
    end

    if not enableMarquee or #title <= maxChars then
        return title
    end

    local loopString = title .. "    *    "
    local len = #loopString
    local visible = ""

    for i = 0, maxChars - 1 do
        local idx = ((HUD.MarqueeOffset - 1 + i) % len) + 1
        visible = visible .. loopString:sub(idx, idx)
    end

    return visible
end

function HUD.GetAnchorSettings(anchorName, offX, offY)
    local a = anchorName:lower()
    if a == "bottomleft" then
        return { Min = {X = 0.0, Y = 1.0}, Max = {X = 0.0, Y = 1.0}, Align = {X = 0.0, Y = 1.0}, Pos = {X = offX, Y = offY} }
    elseif a == "bottomright" then
        return { Min = {X = 1.0, Y = 1.0}, Max = {X = 1.0, Y = 1.0}, Align = {X = 1.0, Y = 1.0}, Pos = {X = offX, Y = offY} }
    elseif a == "topleft" then
        return { Min = {X = 0.0, Y = 0.0}, Max = {X = 0.0, Y = 0.0}, Align = {X = 0.0, Y = 0.0}, Pos = {X = offX, Y = offY} }
    elseif a == "topright" then
        return { Min = {X = 1.0, Y = 0.0}, Max = {X = 1.0, Y = 0.0}, Align = {X = 1.0, Y = 0.0}, Pos = {X = offX, Y = offY} }
    elseif a == "topcenter" then
        return { Min = {X = 0.5, Y = 0.0}, Max = {X = 0.5, Y = 0.0}, Align = {X = 0.5, Y = 0.0}, Pos = {X = offX, Y = offY} }
    elseif a == "bottomcenter" then
        return { Min = {X = 0.5, Y = 1.0}, Max = {X = 0.5, Y = 1.0}, Align = {X = 0.5, Y = 1.0}, Pos = {X = offX, Y = offY} }
    end
    return { Min = {X = 0.5, Y = 0.5}, Max = {X = 0.5, Y = 0.5}, Align = {X = 0.5, Y = 0.5}, Pos = {X = offX, Y = offY} }
end

function HUD.GetActiveHUDWidget()
    if not HUD.CachedHUDWidget or not HUD.CachedHUDWidget:IsValid() then
        HUD.CachedHUDWidget = FindFirstOf("HUD_Widget_C")
    end
    return HUD.CachedHUDWidget
end

function HUD.CleanLeftoverWidgets(targetCanvas, config)
    if not targetCanvas or not targetCanvas:IsValid() or not targetCanvas.GetChildrenCount then return end
    pcall(function()
        local count = targetCanvas:GetChildrenCount()
        if count and type(count) == "number" and count > 0 then
            for i = count - 1, 0, -1 do
                local child = targetCanvas:GetChildAt(i)
                if child and child:IsValid() then
                    local name = child:GetFullName()
                    if name:find("PortableRadio") or name:find("RadioMainContainer") or name:find("RadioHorizontalBox") or name:find("RadioStatusText") or name:find("RadioVolumeRow") then
                        pcall(function() child:RemoveFromParent() end)
                        if config and config.dprint then config.dprint("[PortableRadio] Destroyed leftover HUD widget: " .. name) end
                    end
                end
            end
        end
    end)
end

function HUD.TryInject(config, currentVolume, isRadioOn)
    if not config.ShowHUD then return end

    if HUD.IsInjected and HUD.MainContainer and HUD.MainContainer:IsValid() then
        return
    end

    local inGameHUD = HUD.GetActiveHUDWidget()
    if not inGameHUD or not inGameHUD:IsValid() then
        HUD.IsInjected = false
        HUD.MainContainer = nil
        return
    end

    HUD.IsInjected = false

    local WidgetTree = inGameHUD.WidgetTree
    if not WidgetTree or not WidgetTree:IsValid() then return end

    local SourceTB = inGameHUD.TextBlock_AmmoCounter
    if not SourceTB or not SourceTB:IsValid() then return end

    if not TextBlockClass or not HBoxClass or not VBoxClass then
        TextBlockClass = StaticFindObject("/Script/UMG.TextBlock")
        HBoxClass = StaticFindObject("/Script/UMG.HorizontalBox")
        VBoxClass = StaticFindObject("/Script/UMG.VerticalBox")
        SizeBoxClass = StaticFindObject("/Script/UMG.SizeBox")
        ImageClass = StaticFindObject("/Script/UMG.Image")
        ProgressBarClass = StaticFindObject("/Script/UMG.ProgressBar")
    end
    if not TextBlockClass or not HBoxClass or not VBoxClass then return end

    local TargetCanvas = WidgetTree.RootWidget
    local R81 = inGameHUD.RetainerBox_81
    if R81 and R81:IsValid() and R81.GetContent then
        local SB = R81:GetContent()
        if SB and SB:IsValid() and SB.GetContent then
            local CanvasEffects = SB:GetContent()
            if CanvasEffects and CanvasEffects:IsValid() then
                TargetCanvas = CanvasEffects
            end
        end
    end

    HUD.CleanLeftoverWidgets(TargetCanvas, config)

    local okConstruct, errConstruct = pcall(function()
        local MainVBox = StaticConstructObject(VBoxClass, WidgetTree, FName("PortableRadioMainContainer"))
        if not MainVBox or not MainVBox:IsValid() then return end

        local VSlot = TargetCanvas:AddChildToCanvas(MainVBox)
        if VSlot and VSlot:IsValid() then
            local anchor = HUD.GetAnchorSettings(config.Anchor, config.OffsetX, config.OffsetY)

            local titleEstimatedWidth = (config.MaxVisibleCharacters * (config.FontSize * 0.85)) + (config.ShowIcon and (config.IconSize + config.IconSpacing) or 0.0) + 20.0
            local volumeEstimatedWidth = config.SliderWidth + (config.FontSize * 4.0) + 20.0
            local cWidth = math.max(titleEstimatedWidth, volumeEstimatedWidth)
            local cHeight = (config.FontSize * 2.5) + config.SliderHeight + 15.0

            VSlot:SetAnchors({Minimum = anchor.Min, Maximum = anchor.Max})
            VSlot:SetAlignment(anchor.Align)
            VSlot:SetPosition(anchor.Pos)
            VSlot:SetSize({X = cWidth, Y = cHeight})
            VSlot:SetZOrder(100)
            if config.dprint then
                config.dprint(string.format("[PortableRadio] Applied Final VSlot (%s): Pos=(%.1f, %.1f) Size=(%.1f, %.1f) Align=(%.2f, %.2f)",
                    config.Anchor, anchor.Pos.X, anchor.Pos.Y, cWidth, cHeight, anchor.Align.X, anchor.Align.Y))
            end
        end

        local TitleHBox = StaticConstructObject(HBoxClass, WidgetTree)
        if not TitleHBox or not TitleHBox:IsValid() then return end
        MainVBox:AddChildToVerticalBox(TitleHBox)

        if config.ShowIcon and ImageClass and ImageClass:IsValid() then
            local IconWidget = StaticConstructObject(ImageClass, WidgetTree)
            if IconWidget and IconWidget:IsValid() then
                local NoteTexture = nil
                local NotePath = config.BaseDir .. "/note.png"
                if not RenderingLib or not RenderingLib:IsValid() then
                    RenderingLib = StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
                end
                if RenderingLib and RenderingLib:IsValid() then
                    pcall(function() NoteTexture = RenderingLib:ImportFileAsTexture2D(inGameHUD, NotePath) end)
                end

                if NoteTexture and NoteTexture:IsValid() then
                    IconWidget:SetBrushFromTexture(NoteTexture, true)
                elseif inGameHUD.Image_AmmoIcon and inGameHUD.Image_AmmoIcon:IsValid() then
                    IconWidget:SetBrush(inGameHUD.Image_AmmoIcon.Brush)
                end

                if SourceTB and SourceTB.ColorAndOpacity then
                    pcall(function() IconWidget:SetBrushTintColor(SourceTB.ColorAndOpacity) end)
                end
                pcall(function() IconWidget:SetDesiredSizeOverride({X = config.IconSize, Y = config.IconSize}) end)

                local ISlot = TitleHBox:AddChildToHorizontalBox(IconWidget)
                if ISlot and ISlot:IsValid() and ISlot.SetPadding then
                    pcall(function()
                        ISlot:SetPadding({Left = 0.0, Top = 0.0, Right = config.IconSpacing, Bottom = 0.0})
                        ISlot:SetVerticalAlignment(2)
                    end)
                end
                HUD.IconWidget = IconWidget
            end
        end

        local TB = StaticConstructObject(TextBlockClass, WidgetTree)
        if not TB or not TB:IsValid() then return end

        local fontInfo = SourceTB.Font
        if fontInfo then
            fontInfo.Size = config.FontSize
            TB:SetFont(fontInfo)
        end
        TB:SetColorAndOpacity(SourceTB.ColorAndOpacity)
        if SourceTB.ShadowColorAndOpacity then TB:SetShadowColorAndOpacity(SourceTB.ShadowColorAndOpacity) end
        if SourceTB.ShadowOffset then TB:SetShadowOffset(SourceTB.ShadowOffset) end
        TB:SetText(FText(isRadioOn and "RADIO ON" or "RADIO OFF"))

        local TSlot = TitleHBox:AddChildToHorizontalBox(TB)
        if TSlot and TSlot:IsValid() and TSlot.SetVerticalAlignment then
            pcall(function() TSlot:SetVerticalAlignment(2) end)
        end

        local VolHBox = StaticConstructObject(HBoxClass, WidgetTree)
        if VolHBox and VolHBox:IsValid() then
            local VRowSlot = MainVBox:AddChildToVerticalBox(VolHBox)
            if VRowSlot and VRowSlot:IsValid() and VRowSlot.SetPadding then
                pcall(function() VRowSlot:SetPadding({Left = (config.ShowIcon and (config.IconSize + config.IconSpacing) or 0.0), Top = 2.0, Right = 0.0, Bottom = 0.0}) end)
            end

            local SubFontSize = math.max(10, config.FontSize - 2)

            local VolTag = StaticConstructObject(TextBlockClass, WidgetTree)
            if VolTag and VolTag:IsValid() then
                if fontInfo then
                    local tagFont = SourceTB.Font
                    tagFont.Size = SubFontSize
                    VolTag:SetFont(tagFont)
                end
                VolTag:SetColorAndOpacity(SourceTB.ColorAndOpacity)
                VolTag:SetText(FText("VOL"))
                local TagSlot = VolHBox:AddChildToHorizontalBox(VolTag)
                if TagSlot and TagSlot:IsValid() and TagSlot.SetPadding then
                    pcall(function()
                        TagSlot:SetPadding({Left = 0.0, Top = 0.0, Right = 8.0, Bottom = 0.0})
                        TagSlot:SetVerticalAlignment(2)
                    end)
                end
            end

            if ProgressBarClass and ProgressBarClass:IsValid() then
                local PB = StaticConstructObject(ProgressBarClass, WidgetTree)
                if PB and PB:IsValid() then
                    if inGameHUD.ProgressBar_Health and inGameHUD.ProgressBar_Health:IsValid() then
                        pcall(function() PB.WidgetStyle = inGameHUD.ProgressBar_Health.WidgetStyle end)
                    end
                    if SourceTB and SourceTB.ColorAndOpacity then
                        pcall(function() PB:SetFillColorAndOpacity(SourceTB.ColorAndOpacity) end)
                    end
                    pcall(function() PB:SetPercent(currentVolume / 2.0) end)

                    if SizeBoxClass and SizeBoxClass:IsValid() then
                        local PBBox = StaticConstructObject(SizeBoxClass, WidgetTree)
                        if PBBox and PBBox:IsValid() then
                            pcall(function()
                                if PBBox.SetWidthOverride then
                                    PBBox:SetWidthOverride(config.SliderWidth)
                                else
                                    PBBox.bOverride_WidthOverride = true
                                    PBBox.WidthOverride = config.SliderWidth
                                end
                                if PBBox.SetHeightOverride then
                                    PBBox:SetHeightOverride(config.SliderHeight)
                                else
                                    PBBox.bOverride_HeightOverride = true
                                    PBBox.HeightOverride = config.SliderHeight
                                end
                            end)

                            local innerSlot = PBBox:AddChild(PB)
                            if innerSlot and innerSlot:IsValid() then
                                pcall(function()
                                    if innerSlot.SetHorizontalAlignment then innerSlot:SetHorizontalAlignment(0) end
                                    if innerSlot.SetVerticalAlignment then innerSlot:SetVerticalAlignment(0) end
                                end)
                            end

                            local PBSlot = VolHBox:AddChildToHorizontalBox(PBBox)
                            if PBSlot and PBSlot:IsValid() and PBSlot.SetPadding then
                                pcall(function()
                                    PBSlot:SetPadding({Left = 0.0, Top = 0.0, Right = 8.0, Bottom = 0.0})
                                    PBSlot:SetVerticalAlignment(2)
                                end)
                            end
                            if config.dprint then config.dprint(string.format("[PortableRadio] SizeBox created with Width=%.1f, Height=%.1f", config.SliderWidth, config.SliderHeight)) end
                        else
                            local PBSlot = VolHBox:AddChildToHorizontalBox(PB)
                            if PBSlot and PBSlot:IsValid() and PBSlot.SetPadding then
                                pcall(function()
                                    PBSlot:SetPadding({Left = 0.0, Top = 0.0, Right = 8.0, Bottom = 0.0})
                                    PBSlot:SetVerticalAlignment(2)
                                end)
                            end
                        end
                    else
                        local PBSlot = VolHBox:AddChildToHorizontalBox(PB)
                        if PBSlot and PBSlot:IsValid() and PBSlot.SetPadding then
                            pcall(function()
                                PBSlot:SetPadding({Left = 0.0, Top = 0.0, Right = 8.0, Bottom = 0.0})
                                PBSlot:SetVerticalAlignment(2)
                            end)
                        end
                    end
                    HUD.VolProgressBar = PB
                end
            end

            local PctTB = StaticConstructObject(TextBlockClass, WidgetTree)
            if PctTB and PctTB:IsValid() then
                if fontInfo then
                    local pctFont = SourceTB.Font
                    pctFont.Size = SubFontSize
                    PctTB:SetFont(pctFont)
                end
                PctTB:SetColorAndOpacity(SourceTB.ColorAndOpacity)
                PctTB:SetText(FText(string.format("%d%%", math.floor((currentVolume / 2.0) * 100 + 0.5))))

                local PctSlot = VolHBox:AddChildToHorizontalBox(PctTB)
                if PctSlot and PctSlot:IsValid() and PctSlot.SetVerticalAlignment then
                    pcall(function() PctSlot:SetVerticalAlignment(2) end)
                end
                HUD.VolPctText = PctTB
            end

            pcall(function()
                VolHBox:SetRenderOpacity(0.0)
                VolHBox:SetVisibility(1)
            end)
            HUD.VolSliderOpacity = 0.0
            HUD.VolSliderTargetOpacity = 0.0
            HUD.VolumeRow = VolHBox
        end

        HUD.MainContainer = MainVBox
        HUD.TitleRow = TitleHBox
        HUD.TextBlock = TB

        if config.AutoHideWhenOff and not isRadioOn then
            pcall(function()
                MainVBox:SetRenderOpacity(0.0)
                MainVBox:SetVisibility(1)
            end)
            HUD.CurrentRenderOpacity = 0.0
            HUD.TargetRenderOpacity = 0.0
            HUD.UIState = "OFF_HIDDEN"
        else
            pcall(function()
                MainVBox:SetRenderOpacity(1.0)
                MainVBox:SetVisibility(0)
            end)
            HUD.CurrentRenderOpacity = 1.0
            HUD.TargetRenderOpacity = 1.0
            HUD.UIState = "PLAYING"
        end

        HUD.IsInjected = true
        if config.dprint then config.dprint("[PortableRadio] HUD Injected successfully at " .. config.Anchor) end
    end)

    if not okConstruct then
        print("[PortableRadio] Error constructing HUD: " .. tostring(errConstruct) .. "\n")
    end
end

function HUD.UpdateVolume(currentVolume)
    if HUD.VolProgressBar and HUD.VolProgressBar:IsValid() then
        pcall(function() HUD.VolProgressBar:SetPercent(currentVolume / 2.0) end)
    end
    if HUD.VolPctText and HUD.VolPctText:IsValid() then
        pcall(function() HUD.VolPctText:SetText(FText(string.format("%d%%", math.floor((currentVolume / 2.0) * 100 + 0.5)))) end)
    end
end

function HUD.ShowVolumeSlider(config)
    if config.ShowVolumeSlider and HUD.VolumeRow and HUD.VolumeRow:IsValid() then
        pcall(function()
            HUD.VolumeRow:SetVisibility(0)
            HUD.VolumeRow:SetRenderOpacity(HUD.VolSliderOpacity)
        end)
        HUD.VolSliderTargetOpacity = 1.0
        HUD.VolSliderTimer = config.SliderHideDelay
    end
end

function HUD.DismissVolumeSlider()
    HUD.VolSliderTargetOpacity = 0.0
    HUD.VolSliderOpacity = 0.0
    HUD.VolSliderTimer = 0.0
    if HUD.VolumeRow and HUD.VolumeRow:IsValid() then
        pcall(function()
            HUD.VolumeRow:SetRenderOpacity(0.0)
            HUD.VolumeRow:SetVisibility(1)
        end)
    end
end

function HUD.Update(dt, isRadioOn, currentSong, config, onVolumeHide)
    local inGameHUD = HUD.GetActiveHUDWidget()
    if inGameHUD and inGameHUD:IsValid() then
        local vis = 2
        local ok, val = pcall(function() return inGameHUD:Get_HUD_Visibility() end)
        if ok and type(val) == "number" then
            vis = val
        elseif inGameHUD.RetainerBox_81 and inGameHUD.RetainerBox_81:IsValid() then
            vis = inGameHUD.RetainerBox_81:GetVisibility()
        end

        HUD.IsHUDVisible = (vis == 0 or vis == 3 or vis == 4)

        if not config.ShowWithoutEquippedHUD and HUD.MainContainer and HUD.MainContainer:IsValid() then
            HUD.MainContainer:SetVisibility(vis)
        end
    end

    if HUD.UIState == "TURNING_ON" then
        HUD.StateTimer = HUD.StateTimer + dt
        HUD.TargetRenderOpacity = 1.0
        if HUD.StateTimer >= config.TransitionDuration then
            HUD.UIState = "PLAYING"
            HUD.StateTimer = 0.0
        end
    elseif HUD.UIState == "PLAYING" then
        HUD.TargetRenderOpacity = 1.0
        if isRadioOn and HUD.TextBlock and HUD.TextBlock:IsValid() then
            local rawTitle = currentSong or "RADIO ON"

            if rawTitle ~= HUD.LastRawSongName then
                HUD.LastRawSongName = rawTitle
                HUD.MarqueeOffset = 1
                HUD.MarqueeAccumulator = 0.0
            end

            HUD.MarqueeAccumulator = HUD.MarqueeAccumulator + dt
            local stepTime = 1.0 / math.max(0.5, config.MarqueeSpeed)
            if HUD.MarqueeAccumulator >= stepTime then
                HUD.MarqueeAccumulator = HUD.MarqueeAccumulator - stepTime
                HUD.MarqueeOffset = HUD.MarqueeOffset + 1
            end

            local displayText = HUD.GetMarqueeDisplayString(rawTitle, config.MaxVisibleCharacters, config.EnableMarquee)
            HUD.TextBlock:SetText(FText(displayText))
        end
    elseif HUD.UIState == "TURNING_OFF" then
        HUD.StateTimer = HUD.StateTimer + dt
        if HUD.StateTimer >= config.TransitionDuration then
            if config.AutoHideWhenOff then
                HUD.UIState = "FADING_OUT"
                HUD.TargetRenderOpacity = 0.0
            else
                HUD.UIState = "PLAYING"
            end
            HUD.StateTimer = 0.0
        end
    elseif HUD.UIState == "FADING_OUT" then
        HUD.TargetRenderOpacity = 0.0
        if HUD.CurrentRenderOpacity <= 0.01 then
            HUD.UIState = "OFF_HIDDEN"
            if HUD.MainContainer and HUD.MainContainer:IsValid() then
                pcall(function() HUD.MainContainer:SetVisibility(1) end)
            end
        end
    end

    if HUD.MainContainer and HUD.MainContainer:IsValid() then
        if math.abs(HUD.CurrentRenderOpacity - HUD.TargetRenderOpacity) > 0.01 then
            local step = (1.0 / config.FadeDuration) * dt
            if HUD.CurrentRenderOpacity < HUD.TargetRenderOpacity then
                HUD.CurrentRenderOpacity = math.min(HUD.TargetRenderOpacity, HUD.CurrentRenderOpacity + step)
            else
                HUD.CurrentRenderOpacity = math.max(HUD.TargetRenderOpacity, HUD.CurrentRenderOpacity - step)
            end
            pcall(function() HUD.MainContainer:SetRenderOpacity(HUD.CurrentRenderOpacity) end)
        end
    end

    if HUD.VolSliderTimer > 0.0 then
        HUD.VolSliderTimer = HUD.VolSliderTimer - dt
        if HUD.VolSliderTimer <= 0.0 then
            HUD.VolSliderTargetOpacity = 0.0
            if onVolumeHide then onVolumeHide() end
        end
    end

    if HUD.VolumeRow and HUD.VolumeRow:IsValid() then
        if math.abs(HUD.VolSliderOpacity - HUD.VolSliderTargetOpacity) > 0.01 then
            local step = (1.0 / config.FadeDuration) * dt
            if HUD.VolSliderOpacity < HUD.VolSliderTargetOpacity then
                HUD.VolSliderOpacity = math.min(HUD.VolSliderTargetOpacity, HUD.VolSliderOpacity + step)
            else
                HUD.VolSliderOpacity = math.max(HUD.VolSliderTargetOpacity, HUD.VolSliderOpacity - step)
            end
            pcall(function() HUD.VolumeRow:SetRenderOpacity(HUD.VolSliderOpacity) end)
        end

        if HUD.VolSliderOpacity <= 0.01 and HUD.VolSliderTargetOpacity == 0.0 then
            pcall(function() HUD.VolumeRow:SetVisibility(1) end)
        end
    end
end

function HUD.Teardown()
    HUD.IsInjected = false
    HUD.CachedHUDWidget = nil
    HUD.MainContainer = nil
    HUD.TitleRow = nil
    HUD.TextBlock = nil
    HUD.IconWidget = nil
    HUD.VolumeRow = nil
    HUD.VolProgressBar = nil
    HUD.VolPctText = nil
    HUD.UIState = "OFF_HIDDEN"
    HUD.CurrentRenderOpacity = 0.0
    HUD.TargetRenderOpacity = 0.0
    HUD.VolSliderOpacity = 0.0
    HUD.VolSliderTargetOpacity = 0.0
    HUD.VolSliderTimer = 0.0
end

return HUD
