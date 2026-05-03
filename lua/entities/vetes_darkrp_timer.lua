if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("darkrp_alarm_timer_openui")
    util.AddNetworkString("darkrp_alarm_timer_config")
    ENT.MinimumAlarmTime = CreateConVar("darkrp_alarm_clock_minimum_time", "5", FCVAR_ARCHIVE, "The minimum timer allowed to be set (in minutes).")
    ENT.AlarmNameMaxCharacters = CreateConVar("darkrp_alarm_name_max_chars", "20", FCVAR_ARCHIVE, "The maximum amount of characters allowed for the timer's name.")
end
ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.PrintName = "Alarm Clock"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "Vetes' SEnts"
ENT.Author = "Vetes"
ENT.Purpose = "Allows you to make a timer that goes off after your selected duration."
ENT.Instructions = "Press E on the clock to edit the timer."
ENT.PhysgunDisabled = false
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true
ENT.Model = Model("models/vetes/darkrp_alarm_clock.mdl")
ENT.AlarmPlayingMaterial = Material("voice/icntlk_pl")
ENT.IconOverride = "entities/vetes/darkrp_alarm_clock.vtf"
ENT.AlarmMaxTimeHours = 99
ENT.AlarmSoundLevel = 60
ENT.AlarmSoundVolume = 1
ENT.DefaultColor = Color(25, 25, 25)
ENT.DefaultFontColor = Color(81, 155, 52)
ENT.DefaultBackgroundColor = Color(0, 0, 0, 200)
ENT.AvailableAlarmSounds = {
    "ambient/alarms/alarm1.wav",
    "ambient/alarms/city_firebell_loop1.wav",
    "ambient/alarms/alarm_citizen_loop1.wav",
    "ambient/alarms/apc_alarm_loop1.wav",
    "ambient/alarms/combine_bank_alarm_loop1.wav",
    "ambient/alarms/combine_bank_alarm_loop4.wav",
    "ambient/alarms/siren.wav"
}
ENT.AvailableAlarmSoundsLookup = {}
for _, sound in ipairs(ENT.AvailableAlarmSounds) do
    ENT.AvailableAlarmSoundsLookup[sound] = true
end

function ENT:Initialize()
    if CLIENT then
        self.SoundObject = nil
        self.PlayingAlarmSound = ""
        self.CachedFontColor = self.DefaultFontColor
        return
    end
    self:SetRPTimerName("")
    self:SetRPTimerPlaying(false)
    self:SetRPTimerEndTime(-1)
    self:SetRPTimerAlarmSound(self.AvailableAlarmSounds[1])
    self:SetRPTimerColorR(self.DefaultFontColor.r)
    self:SetRPTimerColorG(self.DefaultFontColor.g)
    self:SetRPTimerColorB(self.DefaultFontColor.b)
    self.NextUse = 0
    self:SetColor(self.DefaultColor)
    self:SetModel(self.Model)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_BBOX)
    self:PhysicsInit(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end
end

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "owning_ent")
    self:NetworkVar("Bool", 0, "RPTimerPlaying")
    self:NetworkVar("Float", 0, "RPTimerEndTime")
    self:NetworkVar("String", 0, "RPTimerName")
    self:NetworkVar("String", 1, "RPTimerAlarmSound")
    self:NetworkVar("Int", 0, "RPTimerColorR")
    self:NetworkVar("Int", 1, "RPTimerColorG")
    self:NetworkVar("Int", 2, "RPTimerColorB")
end

if SERVER then
    function ENT:Think()
        local alarmPlaying = self:GetRPTimerPlaying()
        local timeLeft = self:GetRPTimerEndTime()
        if not alarmPlaying and timeLeft != -1 and timeLeft - CurTime() <= 0 then -- play the alarm!
            self:SetRPTimerPlaying(true)
            --self:EmitSound(self:GetRPTimerAlarmSound()), self.AlarmSoundLevel, 100, self.AlarmSoundVolume)
        end
        return false
    end

    function ENT:Use(activator, caller)
        if IsValid(activator) and activator:IsPlayer() and CurTime() > self.NextUse then
            self.NextUse = CurTime() + 1
            local alarmPlaying = self:GetRPTimerPlaying()
            if alarmPlaying then -- stop the alarm (anyone can stop it)
                self:SetRPTimerPlaying(false)
                self:SetRPTimerEndTime(-1)
                --self:StopSound(self:GetRPTimerAlarmSound())
                return
            end
            if self:Getowning_ent() != activator then
                activator:ChatPrint("This isn't your alarm clock.")
                return
            end
            net.Start("darkrp_alarm_timer_openui")
            net.WriteEntity(self)
            net.Send(activator)
        end
    end

    function ENT:OnTakeDamage(dmg) -- allow players to destroy them
        self:TakePhysicsDamage(dmg)
        self.damage = (self.damage or 100) - dmg:GetDamage()
        if self.damage <= 0 then
            self:Remove()
        end
    end

    net.Receive("darkrp_alarm_timer_config", function(len, ply)
        local alarmEnt = net.ReadEntity()
        local alarmName = net.ReadString()
        local alarmTime = net.ReadFloat()
        local alarmSound = net.ReadString()
        local alarmModelColor = net.ReadTable()
        local alarmFontColor = net.ReadTable()
        if not IsValid(alarmEnt) or not IsValid(ply) or not alarmEnt.AvailableAlarmSoundsLookup[alarmSound] then return end
        if alarmEnt:Getowning_ent() != ply then
            ply:ChatPrint("This isn't your alarm clock.")
            return
        end
        if #alarmName > alarmEnt.AlarmNameMaxCharacters:GetInt() then
            ply:ChatPrint("Alarm name can only be " .. alarmEnt.AlarmNameMaxCharacters:GetInt() .. " characters maximum.")
            return
        end
        if alarmTime > alarmEnt.AlarmMaxTimeHours * 60 * 60 then
            ply:ChatPrint("Alarm time too long. " .. alarmEnt.AlarmMaxTimeHours .. " hours maximum.")
            return
        elseif alarmTime <= 0 then
            alarmEnt:SetRPTimerEndTime(-1)
        elseif alarmTime / 60 < alarmEnt.MinimumAlarmTime:GetInt() then
            ply:ChatPrint("The minimum timer is " .. alarmEnt.MinimumAlarmTime:GetInt() .. " minutes.")
            return
        else
            alarmEnt:SetRPTimerEndTime(CurTime() + alarmTime)
        end
        alarmEnt:SetRPTimerName(alarmName)
        alarmEnt:SetRPTimerAlarmSound(alarmSound)
        if alarmModelColor and alarmModelColor.a == 255 then
            alarmEnt:SetColor(alarmModelColor)
        end
        if alarmFontColor and alarmFontColor.a == 255 then
            alarmEnt:SetRPTimerColorR(alarmFontColor.r)
            alarmEnt:SetRPTimerColorG(alarmFontColor.g)
            alarmEnt:SetRPTimerColorB(alarmFontColor.b)
        end
    end)
end

if CLIENT then
    function ENT:Think()
        local alarmPlaying = self:GetRPTimerPlaying()
        if alarmPlaying then
            if not self.SoundObject then
                self.SoundObject = CreateSound(self, self:GetRPTimerAlarmSound())
                self.SoundObject:SetSoundLevel(self.AlarmSoundLevel)
                self.SoundObject:PlayEx(self.AlarmSoundVolume, 100)
            elseif not self.SoundObject:IsPlaying() then
                self.SoundObject:PlayEx(self.AlarmSoundVolume, 100)
            end
        else
            if self.SoundObject and self.SoundObject:IsPlaying() then
                self.SoundObject:Stop()
                self.SoundObject = nil
            end
        end
    end

    function ENT:OnRemove()
        if self.SoundObject then
            self.SoundObject:Stop()
            self.SoundObject = nil
        end
    end

    function ENT:Draw()
        self:DrawModel()
        local distance = LocalPlayer():GetPos():DistToSqr(self:GetPos())
        local maxDistance = 500 * 500
        if distance > maxDistance then return end

        local pos = self:GetPos() + self:GetUp() * 9
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 180)
        ang:RotateAroundAxis(ang:Forward(), 45)

        local timerEnd = self:GetRPTimerEndTime()
        local alarmPlaying = self:GetRPTimerPlaying()
        local fontColorRed = self:GetRPTimerColorR()
        local fontColorGreen = self:GetRPTimerColorG()
        local fontColorBlue = self:GetRPTimerColorB()
        if self.CachedFontColor.r != fontColorRed or self.CachedFontColor.g != fontColorGreen or self.CachedFontColor.b != fontColorBlue then
            self.CachedFontColor = Color(fontColorRed, fontColorGreen, fontColorBlue)
        end
        if timerEnd == -1 then -- When there's no timer just show the local time.
            cam.Start3D2D(pos, ang, 0.3)
                local flash = CurTime() % 2 < 1
                local dateFormat = "%I:%M %p"
                if flash then
                    dateFormat = "%I %M %p"
                end
                draw.SimpleText(os.date(dateFormat), "DefaultFixed", 0, 18, self.CachedFontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        else
            local alarmName = self:GetRPTimerName()
            if alarmPlaying or alarmName != "" then
                local pos2 = self:GetPos() + self:GetUp() * 20 + self:GetRight() * 5
                local ang2 = self:GetAngles()
                ang2:RotateAroundAxis(ang2:Up(), 180)
                ang2:RotateAroundAxis(ang2:Forward(), 90)
                surface.SetFont("DefaultFixedDropShadow")
                local textWidth, textHeight = surface.GetTextSize(alarmName)
                local boxWidth = textWidth + 10 * 2
                local boxHeight = textHeight + 10 * 2
                cam.Start3D2D(pos2, ang2, 0.3)
                    if alarmPlaying then
                        surface.SetMaterial(self.AlarmPlayingMaterial)
                        surface.SetDrawColor(color_white)
                        surface.DrawTexturedRect(-16, -32, 32, 32)
                    end
                    if alarmName != "" then
                        draw.RoundedBox(8, -boxWidth / 2, 0, boxWidth, boxHeight, self.DefaultBackgroundColor)
                        draw.SimpleText(alarmName, "DefaultFixedDropShadow", 0, 18, self.CachedFontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                cam.End3D2D()
            end
            local timeLeft = timerEnd - CurTime()
            local hours = 0
            local minutes = 0
            local seconds = 0
            if timeLeft > 0 then
                hours = math.floor(timeLeft / 3600)
                minutes = math.floor((timeLeft % 3600) / 60)
                seconds = timeLeft % 60
            end

            cam.Start3D2D(pos, ang, 0.3)
                if alarmPlaying == false or (alarmPlaying and CurTime() % 2 < 1) then
                    draw.SimpleText(string.format("%02d:%02d:%02d", hours, minutes, seconds), "DefaultFixed", 0, 18, self.CachedFontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            cam.End3D2D()
        end
    end

    net.Receive("darkrp_alarm_timer_openui", function(len, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end
        local timerEnd = ent:GetRPTimerEndTime()
        local timeLeft = timerEnd - CurTime()
        local hours = 0
        local minutes = 0
        local seconds = 0
        if timeLeft > 0 then
            hours = math.floor(timeLeft / 3600)
            minutes = math.floor((timeLeft % 3600) / 60)
            seconds = math.floor(timeLeft % 60)
        end

        local frame = vgui.Create("DFrame")
        frame:SetTitle("Alarm Clock Settings")
        frame:SetSize(420, 500)
        frame:Center()
        frame:MakePopup()

        local colorPanels = vgui.Create("DPanel", frame)
        colorPanels:SetSize(220, 400)
        colorPanels:Dock(LEFT)
        colorPanels:DockMargin(10, 0, 10, 10)
        colorPanels:SetBackgroundColor(Color(0, 0, 0, 50))

        local modelColorLabel = vgui.Create("DLabel", colorPanels)
        modelColorLabel:SetText("Clock Color:")
        modelColorLabel:Dock(TOP)
        modelColorLabel:DockMargin(5, 0, 0, 0)

        local modelColorPanel = vgui.Create("DPanel", colorPanels)
        modelColorPanel:SetSize(200, 200)
        modelColorPanel:Dock(TOP)
        modelColorPanel:DockMargin(10, 5, 10, 0)
        modelColorPanel:SetBackgroundColor(Color(0, 0, 0, 50))

        local colorRedLabel = vgui.Create("DLabel", modelColorPanel)
        colorRedLabel:SetText("R:")
        colorRedLabel:SetColor(Color(165, 0, 0))
        colorRedLabel:SetPos(40, 170)

        local colorRed = vgui.Create("DNumberWang", modelColorPanel)
        colorRed:SetPos(53, 170)
        colorRed:SetMin(0)
        colorRed:SetMax(255)
        colorRed:SetSize(33, 20)
        colorRed:SetValue(ent:GetColor().r)

        local colorGreenLabel = vgui.Create("DLabel", modelColorPanel)
        colorGreenLabel:SetText("G:")
        colorGreenLabel:SetColor(Color(0, 165, 0))
        colorGreenLabel:SetPos(53 + 33 + 3, 170)

        local colorGreen = vgui.Create("DNumberWang", modelColorPanel)
        colorGreen:SetPos(53 + 23 + 23 + 3, 170)
        colorGreen:SetMin(0)
        colorGreen:SetMax(255)
        colorGreen:SetSize(33, 20)
        colorGreen:SetValue(ent:GetColor().g)

        local colorBlueLabel = vgui.Create("DLabel", modelColorPanel)
        colorBlueLabel:SetText("B:")
        colorBlueLabel:SetColor(Color(0, 0, 165))
        colorBlueLabel:SetPos(53 + 23 + 23 + 33 + 6, 170)

        local colorBlue = vgui.Create("DNumberWang", modelColorPanel)
        colorBlue:SetPos(53 + 23 + 23 + 33 + 13 + 6, 170)
        colorBlue:SetMin(0)
        colorBlue:SetMax(255)
        colorBlue:SetSize(33, 20)
        colorBlue:SetValue(ent:GetColor().b)

        local colorPicker = vgui.Create("DRGBPicker", modelColorPanel)
        colorPicker:SetPos(5, 5)
        colorPicker:SetSize(30, 190)

        local colorCube = vgui.Create("DColorCube", modelColorPanel)
        colorCube:SetPos(40, 5)
        colorCube:SetSize(155, 155)

        local updateModelColorsPreview = function(col)
            modelColorPanel:SetBackgroundColor(col)
        end
        local supressRGBFieldsUpdate = false
        local updateColorPickers = function(col)
            --colorPicker:SetRGB(col) -- this doesn't appear to work?
            colorCube:SetColor(col)
             -- hack to update the color picker when rgb is manually set:
            local hue, s, v = ColorToHSV(colorCube:GetBaseRGB())
            colorPicker.LastY = ( 1 - hue / 360 ) * colorPicker:GetTall()
            colorPicker:InvalidateLayout(true)
        end

        function colorPicker:OnChange(col)
            supressRGBFieldsUpdate = true
            local h = ColorToHSV(col)
            local _, s, v = ColorToHSV(colorCube:GetRGB())
            col = HSVToColor(h, s, v)
            colorRed:SetValue(col.r)
            colorGreen:SetValue(col.g)
            colorBlue:SetValue(col.b)
            colorCube:SetColor(col)
            updateModelColorsPreview(col)
            supressRGBFieldsUpdate = false
        end

        function colorCube:OnUserChanged(col)
            supressRGBFieldsUpdate = true
            colorRed:SetValue(col.r)
            colorGreen:SetValue(col.g)
            colorBlue:SetValue(col.b)
            updateModelColorsPreview(col)
            supressRGBFieldsUpdate = false
        end

        function colorRed:OnValueChanged(val)
            if supressRGBFieldsUpdate then return end
            local col = colorCube:GetRGB()
            col = Color(val, col.g, col.b)
            updateModelColorsPreview(col)
            updateColorPickers(col)
        end

        function colorGreen:OnValueChanged(val)
            if supressRGBFieldsUpdate then return end
            local col = colorCube:GetRGB()
            col = Color(col.r, val, col.b)
            updateModelColorsPreview(col)
            updateColorPickers(col)
        end

        function colorBlue:OnValueChanged(val)
            if supressRGBFieldsUpdate then return end
            local col = colorCube:GetRGB()
            col = Color(col.r, col.g, val)
            updateModelColorsPreview(col)
            updateColorPickers(col)
        end

        updateModelColorsPreview(ent:GetColor())
        updateColorPickers(ent:GetColor())

        local fontColorLabel = vgui.Create("DLabel", colorPanels)
        fontColorLabel:SetText("Font Color:")
        fontColorLabel:Dock(TOP)
        fontColorLabel:DockMargin(5, 0, 0, 0)

        local fontColorPanel = vgui.Create("DPanel", colorPanels)
        fontColorPanel:SetSize(200, 200)
        fontColorPanel:Dock(TOP)
        fontColorPanel:DockMargin(10, 5, 10, 0)
        fontColorPanel:SetBackgroundColor(Color(0, 0, 0, 50))

        local fontColorRedLabel = vgui.Create("DLabel", fontColorPanel)
        fontColorRedLabel:SetText("R:")
        fontColorRedLabel:SetColor(Color(165, 0, 0))
        fontColorRedLabel:SetPos(40, 170)

        local fontColorRed = vgui.Create("DNumberWang", fontColorPanel)
        fontColorRed:SetPos(53, 170)
        fontColorRed:SetMin(0)
        fontColorRed:SetMax(255)
        fontColorRed:SetSize(33, 20)
        fontColorRed:SetValue(ent.CachedFontColor.r)

        local fontColorGreenLabel = vgui.Create("DLabel", fontColorPanel)
        fontColorGreenLabel:SetText("G:")
        fontColorGreenLabel:SetColor(Color(0, 165, 0))
        fontColorGreenLabel:SetPos(53 + 33 + 3, 170)

        local fontColorGreen = vgui.Create("DNumberWang", fontColorPanel)
        fontColorGreen:SetPos(53 + 23 + 23 + 3, 170)
        fontColorGreen:SetMin(0)
        fontColorGreen:SetMax(255)
        fontColorGreen:SetSize(33, 20)
        fontColorGreen:SetValue(ent.CachedFontColor.g)

        local fontColorBlueLabel = vgui.Create("DLabel", fontColorPanel)
        fontColorBlueLabel:SetText("B:")
        fontColorBlueLabel:SetColor(Color(0, 0, 165))
        fontColorBlueLabel:SetPos(53 + 23 + 23 + 33 + 6, 170)

        local fontColorBlue = vgui.Create("DNumberWang", fontColorPanel)
        fontColorBlue:SetPos(53 + 23 + 23 + 33 + 13 + 6, 170)
        fontColorBlue:SetMin(0)
        fontColorBlue:SetMax(255)
        fontColorBlue:SetSize(33, 20)
        fontColorBlue:SetValue(ent.CachedFontColor.b)

        local fontColorPicker = vgui.Create("DRGBPicker", fontColorPanel)
        fontColorPicker:SetPos(5, 5)
        fontColorPicker:SetSize(30, 190)

        local fontColorCube = vgui.Create("DColorCube", fontColorPanel)
        fontColorCube:SetPos(40, 5)
        fontColorCube:SetSize(155, 155)

        local updateFontColorPickers = function(col)
            --fontColorPicker:SetRGB(col) -- this doesn't appear to work?
            fontColorCube:SetColor(col)
             -- hack to update the fontColor picker when rgb is manually set:
            local hue, s, v = ColorToHSV(fontColorCube:GetBaseRGB())
            fontColorPicker.LastY = ( 1 - hue / 360 ) * fontColorPicker:GetTall()
            fontColorPicker:InvalidateLayout(true)
        end

        function fontColorPicker:OnChange(col)
            supressRGBFieldsUpdate = true
            local h = ColorToHSV(col)
            local _, s, v = ColorToHSV(fontColorCube:GetRGB())
            col = HSVToColor(h, s, v)
            fontColorRed:SetValue(col.r)
            fontColorGreen:SetValue(col.g)
            fontColorBlue:SetValue(col.b)
            fontColorCube:SetColor(col)
            fontColorPanel:SetBackgroundColor(col)
            supressRGBFieldsUpdate = false
        end

        function fontColorCube:OnUserChanged(col)
            supressRGBFieldsUpdate = true
            fontColorRed:SetValue(col.r)
            fontColorGreen:SetValue(col.g)
            fontColorBlue:SetValue(col.b)
            fontColorPanel:SetBackgroundColor(col)
            supressRGBFieldsUpdate = false
        end

        function fontColorRed:OnValueChanged(val)
            if supressRGBFieldsUpdate then return end
            local col = fontColorCube:GetRGB()
            col = Color(val, col.g, col.b)
            fontColorPanel:SetBackgroundColor(col)
            updateFontColorPickers(col)
        end

        function fontColorGreen:OnValueChanged(val)
            if supressRGBFieldsUpdate then return end
            local col = fontColorCube:GetRGB()
            col = Color(col.r, val, col.b)
            fontColorPanel:SetBackgroundColor(col)
            updateFontColorPickers(col)
        end

        function fontColorBlue:OnValueChanged(val)
            if supressRGBFieldsUpdate then return end
            local col = fontColorCube:GetRGB()
            col = Color(col.r, col.g, val)
            fontColorPanel:SetBackgroundColor(col)
            updateFontColorPickers(col)
        end

        fontColorPanel:SetBackgroundColor(ent.CachedFontColor)
        updateFontColorPickers(ent.CachedFontColor)

        local namePanel = vgui.Create("DPanel", frame)
        namePanel:Dock(TOP)
        namePanel:DockMargin(10, 0, 10, 2)
        namePanel:SetBackgroundColor(Color(0, 0, 0, 50))

        local nameLabel = vgui.Create("DLabel", namePanel)
        nameLabel:SetText("Timer Name:")
        nameLabel:Dock(LEFT)
        nameLabel:DockMargin(5, 5, 1, 5)

        local nameEntry = vgui.Create("DTextEntry", namePanel)
        nameEntry:Dock(LEFT)
        nameEntry:SetValue(ent:GetRPTimerName())
        nameEntry:DockMargin(1, 1, 5, 1)
        nameEntry:SetSize(75, 20)

        local hoursPanel = vgui.Create("DPanel", frame)
        hoursPanel:Dock(TOP)
        hoursPanel:DockMargin(10, 2, 10, 2)
        hoursPanel:SetBackgroundColor(Color(0, 0, 0, 50))

        local hoursLabel = vgui.Create("DLabel", hoursPanel)
        hoursLabel:SetText("Hours:")
        hoursLabel:Dock(LEFT)
        hoursLabel:DockMargin(5, 5, 1, 5)

        local hoursEntry = vgui.Create("DNumberWang", hoursPanel)
        hoursEntry:SetMin(0)
        hoursEntry:SetMax(99)
        hoursEntry:SetValue(hours)
        hoursEntry:Dock(LEFT)
        hoursEntry:DockMargin(1, 1, 5, 1)
        hoursEntry:SetSize(75, 20)

        local minutesPanel = vgui.Create("DPanel", frame)
        minutesPanel:Dock(TOP)
        minutesPanel:DockMargin(10, 2, 10, 2)
        minutesPanel:SetBackgroundColor(Color(0, 0, 0, 50))

        local minutesLabel = vgui.Create("DLabel", minutesPanel)
        minutesLabel:SetText("Minutes:")
        minutesLabel:Dock(LEFT)
        minutesLabel:DockMargin(5, 5, 1, 5)

        local minutesEntry = vgui.Create("DNumberWang", minutesPanel)
        minutesEntry:SetMin(0)
        minutesEntry:SetMax(59)
        minutesEntry:SetValue(minutes)
        minutesEntry:Dock(LEFT)
        minutesEntry:DockMargin(1, 1, 5, 1)
        minutesEntry:SetSize(75, 20)

        local secondsPanel = vgui.Create("DPanel", frame)
        secondsPanel:Dock(TOP)
        secondsPanel:DockMargin(10, 2, 10, 10)
        secondsPanel:SetBackgroundColor(Color(0, 0, 0, 50))

        local secondsLabel = vgui.Create("DLabel", secondsPanel)
        secondsLabel:SetText("Seconds:")
        secondsLabel:Dock(LEFT)
        secondsLabel:DockMargin(5, 5, 1, 5)

        local secondsEntry = vgui.Create("DNumberWang", secondsPanel)
        secondsEntry:SetMin(0)
        secondsEntry:SetMax(59)
        secondsEntry:SetValue(seconds)
        secondsEntry:Dock(LEFT)
        secondsEntry:DockMargin(1, 1, 5, 1)
        secondsEntry:SetSize(75, 20)

        local soundList = vgui.Create("DComboBox", frame)
        soundList:Dock(TOP)
        soundList:DockMargin(10, 0, 10, 0)
        local selectedSoundIdx = 1
        for soundIdx, sound in ipairs(ent.AvailableAlarmSounds) do
            soundList:AddChoice(sound)
            if sound == ent:GetRPTimerAlarmSound() then
                selectedSoundIdx = soundIdx
            end
        end
        soundList:ChooseOptionID(selectedSoundIdx)

        local previewButton = vgui.Create("DButton", frame)
        if ent.PlayingAlarmSound != "" then
            previewButton:SetText("Stop Preview")
        else
            previewButton:SetText("Preview Sound")
        end
        previewButton:Dock(TOP)
        previewButton:DockMargin(10, 0, 10, 10)
        previewButton.DoClick = function()
            if ent.PlayingAlarmSound != "" then
                previewButton:SetText("Preview Sound")
                ent:StopSound(ent.PlayingAlarmSound)
                ent.PlayingAlarmSound = ""
            else
                local selectedSound = soundList:GetSelected()
                if selectedSound then
                    previewButton:SetText("Stop Preview")
                    ent:EmitSound(selectedSound, ent.AlarmSoundLevel, 100, ent.AlarmSoundVolume)
                    ent.PlayingAlarmSound = selectedSound
                else
                    chat.AddText(Color(255, 0, 0), "Please select a sound to preview!")
                end
            end
        end

        -- Repeat option could be nice but just seems like a way for minges to easily annoy players.
        /* local repeatPanel = vgui.Create("DPanel", frame)
        repeatPanel:Dock(TOP)
        repeatPanel:DockMargin(5, 0, 5, 0)
        repeatPanel:SetBackgroundColor(Color(0, 0, 0, 50))

        local repeatLabel = vgui.Create("DLabel", repeatPanel)
        repeatLabel:SetText("Repeats:")
        repeatLabel:Dock(LEFT)
        repeatLabel:DockMargin(5, 5, 1, 5)

        local repeatToggle = vgui.Create("DCheckBox", repeatPanel)
        repeatToggle:Dock(RIGHT)
        repeatToggle:DockMargin(5, 5, 1, 5)

        local repeatDescription = vgui.Create("DLabel", frame)
        repeatDescription:Dock(TOP)
        repeatDescription:DockMargin(5, 0, 5, 0)
        repeatDescription:SetText("Note: Repeating timers will\nautomatically reset and only play the\nthe alarm for 5 seconds.")
        repeatDescription:SetSize(180, 50) */
        
        local saveButton = vgui.Create("DButton", frame)
        saveButton:SetText("Update Timer")
        saveButton:Dock(BOTTOM)
        saveButton:DockMargin(10, 10, 10, 10)
        saveButton.DoClick = function()
            if not IsValid(ent) then return end
            local alarmName = nameEntry:GetValue()
            local hours = tonumber(hoursEntry:GetValue()) or 0
            local minutes = tonumber(minutesEntry:GetValue()) or 0
            local seconds = tonumber(secondsEntry:GetValue()) or 0
            local soundToPlay = soundList:GetValue()

            net.Start("darkrp_alarm_timer_config")
            net.WriteEntity(ent)
            net.WriteString(alarmName)
            net.WriteFloat(hours * 3600 + minutes * 60 + seconds)
            net.WriteString(soundToPlay)
            net.WriteTable(Color(colorRed:GetValue(), colorGreen:GetValue(), colorBlue:GetValue())) -- writing colorCube:GetRGB() would sometimes be off by a few for r/g/b? wtf
            net.WriteTable(Color(fontColorRed:GetValue(), fontColorGreen:GetValue(), fontColorBlue:GetValue()))
            net.SendToServer()

            frame:Close()
        end
    end)
end