--[[
	Teleport Script - V3.1.5
	Pengembang: Lucifers ( Sann )

	Fitur Baru:
	- Efek Transisi Teleportasi (Fade-in/Fade-out).
	- Penamaan Slot Kustom (misal: "Base", "Finish Obby").
	- Menu Pengaturan: Ubah Keybinds & Warna Indikator.
	- Umpan Balik Visual pada Tombol (Hover, Press).
	- UI yang lebih rapi dan terorganisir.
]]

--================================================================
-- Layanan & Variabel Utama
--================================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local HRP = character:WaitForChild("HumanoidRootPart")

--================================================================
-- TABEL KONFIGURASI & DATA
--================================================================
local Config = {
	CooldownTime = 1.5,
	MaxSlots = 3,
	TeleportHeightOffset = Vector3.new(0, 4, 0),
	
	SaveSoundID = "rbxassetid://77457926931973",
	TeleportSoundID = "rbxassetid://3140269034",
	ErrorSoundID = "rbxassetid://1096728519",
	ClickSoundID = "rbxassetid://6023428994", -- Suara klik UI
}

-- Data dinamis yang bisa diubah oleh pemain
local UserData = {
	Keybinds = {
		Save = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three},
		Teleport = {Enum.KeyCode.G, Enum.KeyCode.H, Enum.KeyCode.J},
		TeleportBack = Enum.KeyCode.T,
	},
	IndicatorColor = Color3.fromRGB(0, 255, 127),
}

local saveSlots = {}
local lastTeleportOrigin = nil
local canTeleport = true

--================================================================
-- Inisialisasi
--================================================================
local Sounds = {}
for name, id in pairs(Config) do
	if string.find(name, "SoundID") then
		local soundName = string.gsub(name, "ID", "")
		Sounds[soundName] = Instance.new("Sound", SoundService)
		Sounds[soundName].SoundId = id
		Sounds[soundName].Volume = name == "ClickSound" and 4 or 8
	end
end

local mainGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
mainGui.Name = "SaveStateGUI_Pro"
mainGui.ResetOnSpawn = false

--================================================================
-- FUNGSI INTI (Tidak Berubah Banyak)
--================================================================
local function showNotification(message)
	-- Fungsi ini sama seperti sebelumnya
	local notifFrame = Instance.new("TextLabel")
	notifFrame.Size = UDim2.new(0.3, 0, 0.05, 0); notifFrame.Position = UDim2.new(0.35, 0, -0.1, 0); notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); notifFrame.BackgroundTransparency = 0.2; notifFrame.TextColor3 = Color3.fromRGB(255, 255, 255); notifFrame.Text = message; notifFrame.TextScaled = true; notifFrame.Font = Enum.Font.GothamSemibold; notifFrame.Parent = mainGui; local corner = Instance.new("UICorner", notifFrame); TweenService:Create(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.35, 0, 0.02, 0)}):Play(); task.delay(2, function() if notifFrame then TweenService:Create(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0.35, 0, -0.1, 0)}):Play(); task.wait(0.5); notifFrame:Destroy() end end)
end

local function createVisualIndicator(slot)
	if saveSlots[slot] and saveSlots[slot].Indicator then
		saveSlots[slot].Indicator:Destroy()
	end
	
	local position = saveSlots[slot].Position
	local attachment = Instance.new("Attachment", workspace.Terrain)
	attachment.Position = position
	local particle = Instance.new("ParticleEmitter", attachment)
	particle.Color = ColorSequence.new(UserData.IndicatorColor) -- Menggunakan warna dari data pengguna
	particle.Lifetime = NumberRange.new(1, 1.5)
	particle.Rate = 50
	particle.Size = NumberSequence.new(0.5)
	
	saveSlots[slot].Indicator = attachment
end

local function startCooldown()
	canTeleport = false
	task.delay(Config.CooldownTime, function()
		canTeleport = true
	end)
end

--================================================================
-- FUNGSI BARU & YANG DIMODIFIKASI
--================================================================
local function playTeleportEffect(onComplete)
	local fadeFrame = Instance.new("Frame", mainGui)
	fadeFrame.Size = UDim2.new(1, 0, 1, 0)
	fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	fadeFrame.BackgroundTransparency = 1
	
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
	
	-- Fade to black
	TweenService:Create(fadeFrame, tweenInfo, {BackgroundTransparency = 0}):Play()
	task.wait(0.35)
	
	onComplete() -- Pindahkan karakter saat layar hitam
	
	task.wait(0.1)
	
	-- Fade back to clear
	TweenService:Create(fadeFrame, tweenInfo, {BackgroundTransparency = 1}):Play()
	task.wait(0.35)
	fadeFrame:Destroy()
end

local function performSave(slot, buttonObject, nameBox)
	if not canTeleport then showNotification("Harap tunggu..."); Sounds.ErrorSound:Play(); return end
	if not saveSlots[slot] then saveSlots[slot] = {} end
	
	saveSlots[slot].Position = HRP.Position
	saveSlots[slot].Name = nameBox and nameBox.Text or "Slot " .. slot
	
	showNotification(string.format("Posisi '%s' disimpan!", saveSlots[slot].Name))
	Sounds.SaveSound:Play()
	createVisualIndicator(slot)
	
	if buttonObject then
		buttonObject.Parent.Teleport.Text = "TP: " .. saveSlots[slot].Name -- Update tombol teleport
	end
end

local function performTeleport(slot)
	if not canTeleport then showNotification("Harap tunggu..."); Sounds.ErrorSound:Play(); return end
	if not saveSlots[slot] or not saveSlots[slot].Position then
		showNotification("Slot kosong!"); Sounds.ErrorSound:Play(); return
	end
	
	playTeleportEffect(function()
		lastTeleportOrigin = HRP.Position
		character:PivotTo(CFrame.new(saveSlots[slot].Position) + Config.TeleportHeightOffset)
	end)
	
	showNotification(string.format("Teleport ke '%s'!", saveSlots[slot].Name))
	Sounds.TeleportSound:Play()
	startCooldown()
end

local function performTeleportBack()
	if not canTeleport then showNotification("Harap tunggu..."); Sounds.ErrorSound:Play(); return end
	if not lastTeleportOrigin then showNotification("Tidak ada lokasi sebelumnya!"); Sounds.ErrorSound:Play(); return end
	
	playTeleportEffect(function()
		local tempOrigin = HRP.Position
		character:PivotTo(CFrame.new(lastTeleportOrigin) + Config.TeleportHeightOffset)
		lastTeleportOrigin = tempOrigin
	end)
	
	showNotification("Teleport kembali!")
	Sounds.TeleportSound:Play()
	startCooldown()
end

--================================================================
-- PEMBUATAN UI & EVENT HANDLING
--================================================================
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	HRP = newChar:WaitForChild("HumanoidRootPart")
end)

-- Fungsi untuk umpan balik tombol
local function setupButtonFeedback(button)
	local originalColor = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = originalColor:Lerp(Color3.new(1,1,1), 0.2)}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = originalColor}):Play()
	end)
	button.MouseButton1Down:Connect(function()
		button.Size = button.Size - UDim2.fromOffset(4, 4)
		button.Position = button.Position + UDim2.fromOffset(2, 2)
	end)
	button.MouseButton1Up:Connect(function()
		button.Size = button.Size + UDim2.fromOffset(4, 4)
		button.Position = button.Position - UDim2.fromOffset(2, 2)
		Sounds.ClickSound:Play()
	end)
end

local function createFullGUI()
	-- ## Main Menu Frame ##
	local menuFrame = Instance.new("Frame", mainGui)
	menuFrame.Size = UDim2.new(0.25, 0, 0.4, 0); menuFrame.Position = UDim2.new(1.1, 0, 0.5, 0); menuFrame.AnchorPoint = Vector2.new(1, 0.5); menuFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45); menuFrame.BackgroundTransparency = 0.2; Instance.new("UICorner", menuFrame)
	local layout = Instance.new("UIListLayout", menuFrame); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder

	-- ## Settings Menu Frame ##
	local settingsFrame = Instance.new("Frame", mainGui)
	settingsFrame.Size = UDim2.new(0.25, 0, 0.4, 0); settingsFrame.Position = UDim2.new(1.1, 0, 0.5, 0); settingsFrame.AnchorPoint = Vector2.new(1, 0.5); settingsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40); settingsFrame.BackgroundTransparency = 0.1; settingsFrame.Visible = false; Instance.new("UICorner", settingsFrame)
	local settingsLayout = Instance.new("UIListLayout", settingsFrame); settingsLayout.Padding = UDim.new(0, 8);
	
	-- ## Toggle Button ##
	local toggleButton = Instance.new("TextButton", mainGui)
	toggleButton.Size = UDim2.new(0.1, 0, 0.05, 0); toggleButton.Position = UDim2.new(0.98, 0, 0.94, 0); toggleButton.AnchorPoint = Vector2.new(1, 1); toggleButton.Text = "Menu"; toggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60); toggleButton.TextColor3 = Color3.new(1,1,1); Instance.new("UICorner", toggleButton)
	setupButtonFeedback(toggleButton)

	-- Logika Toggle Menu
	local isMenuVisible = false
	toggleButton.MouseButton1Click:Connect(function()
		isMenuVisible = not isMenuVisible
		local targetPos = isMenuVisible and UDim2.new(0.98, 0, 0.5, 0) or UDim2.new(1.1, 0, 0.5, 0)
		TweenService:Create(menuFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Position = targetPos}):Play()
		if settingsFrame.Visible then settingsFrame.Visible = false end -- Selalu sembunyikan settings
	end)

	-- ## Isi Menu Utama ##
	for i = 1, Config.MaxSlots do
		local slotFrame = Instance.new("Frame", menuFrame); slotFrame.Size = UDim2.new(1, -16, 0.2, 0); slotFrame.Position = UDim2.new(0.5, 0, 0, 0); slotFrame.AnchorPoint = Vector2.new(0.5, 0); slotFrame.BackgroundTransparency = 1; slotFrame.LayoutOrder = i
		local slotLayout = Instance.new("UIListLayout", slotFrame); slotLayout.FillDirection = Enum.FillDirection.Horizontal; slotLayout.Padding = UDim.new(0, 5)

		local nameBox = Instance.new("TextBox", slotFrame); nameBox.Size = UDim2.new(0.4, 0, 1, 0); nameBox.PlaceholderText = "Nama Slot " .. i; nameBox.BackgroundColor3 = Color3.fromRGB(80,80,80); nameBox.TextColor3 = Color3.new(1,1,1)
		local saveBtn = Instance.new("TextButton", slotFrame); saveBtn.Size = UDim2.new(0.3, -5, 1, 0); saveBtn.Text = "Save"; saveBtn.BackgroundColor3 = Color3.fromRGB(80, 160, 240); saveBtn.TextColor3 = Color3.new(1,1,1)
		local tpBtn = Instance.new("TextButton", slotFrame); tpBtn.Size = UDim2.new(0.3, 0, 1, 0); tpBtn.Text = "Teleport"; tpBtn.BackgroundColor3 = Color3.fromRGB(240, 160, 80); tpBtn.TextColor3 = Color3.new(1,1,1)
		
		slotFrame.Name = "Slot" .. i
		slotFrame.Save = saveBtn
		slotFrame.Teleport = tpBtn
		
		setupButtonFeedback(saveBtn); setupButtonFeedback(tpBtn)
		saveBtn.MouseButton1Click:Connect(function() performSave(i, slotFrame, nameBox) end)
		tpBtn.MouseButton1Click:Connect(function() performTeleport(i) end)
	end

	local backBtn = Instance.new("TextButton", menuFrame); backBtn.Size = UDim2.new(1, -16, 0.1, 0); backBtn.Position = UDim2.new(0.5, 0, 0, 0); backBtn.AnchorPoint = Vector2.new(0.5, 0); backBtn.Text = "Teleport Kembali"; backBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50); backBtn.TextColor3 = Color3.new(1,1,1); backBtn.LayoutOrder = 4; setupButtonFeedback(backBtn)
	local settingsBtn = Instance.new("TextButton", menuFrame); settingsBtn.Size = UDim2.new(1, -16, 0.1, 0); settingsBtn.Position = UDim2.new(0.5, 0, 0, 0); settingsBtn.AnchorPoint = Vector2.new(0.5, 0); settingsBtn.Text = "Pengaturan"; settingsBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100); settingsBtn.TextColor3 = Color3.new(1,1,1); settingsBtn.LayoutOrder = 5; setupButtonFeedback(settingsBtn)
	
	backBtn.MouseButton1Click:Connect(performTeleportBack)
	settingsBtn.MouseButton1Click:Connect(function()
		menuFrame.Visible, settingsFrame.Visible = false, true
		TweenService:Create(settingsFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Position = UDim2.new(0.98, 0, 0.5, 0)}):Play()
	end)

	-- ## Isi Menu Pengaturan ##
	local title = Instance.new("TextLabel", settingsFrame); title.Size = UDim2.new(1,-16, 0.1, 0); title.Text = "Pengaturan"; title.TextColor3 = Color3.new(1,1,1); title.BackgroundTransparency = 1;
	local colorLabel = Instance.new("TextLabel", settingsFrame); colorLabel.Size = UDim2.new(1,-16, 0.1, 0); colorLabel.Text = "Warna Indikator (R,G,B)"; colorLabel.TextColor3 = Color3.new(1,1,1); colorLabel.BackgroundTransparency = 1;
	local colorFrame = Instance.new("Frame", settingsFrame); colorFrame.Size = UDim2.new(1,-16, 0.1, 0); colorFrame.BackgroundTransparency = 1;
	local colorLayout = Instance.new("UIListLayout", colorFrame); colorLayout.FillDirection = Enum.FillDirection.Horizontal; colorLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center;
	local rBox = Instance.new("TextBox", colorFrame); rBox.Size = UDim2.new(0.3, 0, 1, 0); rBox.Text = "0"; rBox.PlaceholderText = "R"
	local gBox = Instance.new("TextBox", colorFrame); gBox.Size = UDim2.new(0.3, 0, 1, 0); gBox.Text = "255"; gBox.PlaceholderText = "G"
	local bBox = Instance.new("TextBox", colorFrame); bBox.Size = UDim2.new(0.3, 0, 1, 0); bBox.Text = "127"; bBox.PlaceholderText = "B"
	
	local function updateColor()
		local r = tonumber(rBox.Text) or 0
		local g = tonumber(gBox.Text) or 0
		local b = tonumber(bBox.Text) or 0
		UserData.IndicatorColor = Color3.fromRGB(r,g,b)
		showNotification("Warna indikator diperbarui!")
	end
	rBox.FocusLost:Connect(updateColor); gBox.FocusLost:Connect(updateColor); bBox.FocusLost:Connect(updateColor)
	
	local backToMenuBtn = Instance.new("TextButton", settingsFrame); backToMenuBtn.Size = UDim2.new(1, -16, 0.1, 0); backToMenuBtn.Text = "Kembali ke Menu"; backToMenuBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100); backToMenuBtn.TextColor3 = Color3.new(1,1,1); setupButtonFeedback(backToMenuBtn)
	backToMenuBtn.MouseButton1Click:Connect(function()
		TweenService:Create(settingsFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Position = UDim2.new(1.1, 0, 0.5, 0)}):Play()
		task.wait(0.1)
		settingsFrame.Visible, menuFrame.Visible = false, true
	end)
end


--================================================================
-- MULAI SKRIP
--================================================================
createFullGUI()

if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
	showNotification("Mode PC: Gunakan Menu atau Hotkey.")
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		for i, keycode in ipairs(UserData.Keybinds.Save) do if input.KeyCode == keycode then performSave(i) end end
		for i, keycode in ipairs(UserData.Keybinds.Teleport) do if input.KeyCode == keycode then performTeleport(i) end end
		if input.KeyCode == UserData.Keybinds.TeleportBack then performTeleportBack() end
	end)
else
	showNotification("Mode Seluler: Gunakan Menu.")
end
