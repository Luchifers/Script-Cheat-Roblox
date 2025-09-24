--[[
	Save State Script - Versi Fitur Lengkap
	Pengembang: Commonlag (Original), Dikembangkan oleh Gemini
	
	Fitur:
	- Multi-Slot Save State (Simpan hingga 3 lokasi)
	- Menyimpan Posisi & Rotasi (CFrame)
	- Fitur "Teleport Kembali" ke lokasi sebelum teleportasi.
	- Indikator visual menggunakan efek partikel.
	- Notifikasi UI untuk setiap aksi (Simpan, Teleport, Cooldown).
	- Tabel Konfigurasi terpusat untuk kustomisasi yang mudah.
	- UI terpisah dan fungsional untuk PC & Seluler.
	- Kode yang terorganisir dengan fungsi terpusat.

	Kontrol PC:
	- Angka 1, 2, 3: Simpan Posisi ke Slot 1, 2, 3
	- G, H, J: Teleport ke Slot 1, 2, 3
	- T: Teleport Kembali ke lokasi sebelum teleportasi terakhir
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
-- TABEL KONFIGURASI (Ubah pengaturan di sini!)
--================================================================
local Config = {
	-- Tombol Keyboard (PC)
	SaveKeys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three},
	TeleportKeys = {Enum.KeyCode.G, Enum.KeyCode.H, Enum.KeyCode.J},
	TeleportBackKey = Enum.KeyCode.T,
	
	-- Pengaturan Gameplay
	CooldownTime = 1.5, -- Waktu jeda dalam detik
	MaxSlots = 3,
	
	-- ID Suara
	SaveSoundID = "rbxassetid://77457926931973",
	TeleportSoundID = "rbxassetid://3140269034",
	ErrorSoundID = "rbxassetid://1096728519",
	PCDetectSoundID = "rbxassetid://18996974946",
	MobileDetectSoundID = "rbxassetid://138721734757982",
	
	-- Warna & Visual
	IndicatorColor = Color3.fromRGB(0, 255, 127), -- Warna partikel (Hijau Mint)
	ButtonSavedColor = Color3.fromRGB(76, 175, 80), -- Warna tombol setelah menyimpan (Hijau)
	ButtonDefaultColor = Color3.fromRGB(192, 192, 192), -- Warna tombol default (Silver)
	
	-- Teks Notifikasi
	SaveMessage = "Posisi disimpan ke Slot %d!", -- %d akan diganti dengan nomor slot
	TeleportMessage = "Teleport ke Slot %d!",
	TeleportBackMessage = "Teleport kembali!",
	CooldownMessage = "Harap tunggu...",
	EmptySlotMessage = "Slot %d kosong!"
}

--================================================================
-- Variabel Status & Inisialisasi
--================================================================
local saveSlots = {} -- Tabel untuk menyimpan CFrame dan indikator visual
local lastTeleportOrigin = nil
local canTeleport = true

-- Inisialisasi Suara
local Sounds = {}
for name, id in pairs(Config) do
	if string.find(name, "SoundID") then
		local soundName = string.gsub(name, "ID", "")
		Sounds[soundName] = Instance.new("Sound")
		Sounds[soundName].SoundId = id
		Sounds[soundName].Parent = SoundService
		Sounds[soundName].Volume = 8
	end
end

-- GUI Utama
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "SaveStateGUI"
mainGui.ResetOnSpawn = false
mainGui.Parent = player:WaitForChild("PlayerGui")

--================================================================
-- FUNGSI TERPUSAT
--================================================================

-- Fungsi untuk menampilkan notifikasi di layar
local function showNotification(message)
	local notifFrame = Instance.new("TextLabel")
	notifFrame.Size = UDim2.new(0.3, 0, 0.05, 0)
	notifFrame.Position = UDim2.new(0.35, 0, -0.1, 0)
	notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	notifFrame.BackgroundTransparency = 0.2
	notifFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
	notifFrame.Text = message
	notifFrame.TextScaled = true
	notifFrame.Font = Enum.Font.GothamSemibold
	notifFrame.Parent = mainGui
	
	local corner = Instance.new("UICorner", notifFrame)
	corner.CornerRadius = UDim.new(0, 8)
	
	TweenService:Create(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.35, 0, 0.02, 0)}):Play()
	task.delay(2, function()
		if notifFrame then
			TweenService:Create(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0.35, 0, -0.1, 0)}):Play()
			task.wait(0.5)
			notifFrame:Destroy()
		end
	end)
end

-- Fungsi untuk membuat atau memindahkan indikator visual
local function createVisualIndicator(slot)
	-- Hapus indikator lama jika ada
	if saveSlots[slot] and saveSlots[slot].Indicator then
		saveSlots[slot].Indicator:Destroy()
	end
	
	local position = saveSlots[slot].CFrame.Position
	
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	
	local particle = Instance.new("ParticleEmitter")
	particle.Color = ColorSequence.new(Config.IndicatorColor)
	particle.Lifetime = NumberRange.new(1, 1.5)
	particle.Rate = 50
	particle.Size = NumberSequence.new(0.5)
	particle.Speed = NumberRange.new(0.5)
	particle.SpreadAngle = Vector2.new(360, 360)
	particle.Parent = attachment
	
	saveSlots[slot].Indicator = attachment
end

-- Fungsi untuk memulai cooldown
local function startCooldown()
	canTeleport = false
	task.delay(Config.CooldownTime, function()
		canTeleport = true
	end)
end

-- Fungsi logika untuk menyimpan state
local function performSave(slot, buttonObject)
	if not canTeleport then
		showNotification(Config.CooldownMessage)
		Sounds.ErrorSound:Play()
		return
	end
	
	-- Inisialisasi tabel slot jika belum ada
	if not saveSlots[slot] then saveSlots[slot] = {} end
	
	saveSlots[slot].CFrame = HRP.CFrame
	
	showNotification(string.format(Config.SaveMessage, slot))
	Sounds.SaveSound:Play()
	createVisualIndicator(slot)
	
	if buttonObject then -- Untuk feedback tombol seluler
		buttonObject.BackgroundColor3 = Config.ButtonSavedColor
		buttonObject.Text = "Saved " .. slot
	end
end

-- Fungsi logika untuk teleportasi
local function performTeleport(slot)
	if not canTeleport then
		showNotification(Config.CooldownMessage)
		Sounds.ErrorSound:Play()
		return
	end
	
	if not saveSlots[slot] or not saveSlots[slot].CFrame then
		showNotification(string.format(Config.EmptySlotMessage, slot))
		Sounds.ErrorSound:Play()
		return
	end
	
	lastTeleportOrigin = HRP.CFrame
	character:PivotTo(saveSlots[slot].CFrame)
	
	showNotification(string.format(Config.TeleportMessage, slot))
	Sounds.TeleportSound:Play()
	startCooldown()
end

-- Fungsi logika untuk teleport kembali
local function performTeleportBack()
	if not canTeleport then
		showNotification(Config.CooldownMessage)
		Sounds.ErrorSound:Play()
		return
	end
	
	if not lastTeleportOrigin then
		showNotification("Tidak ada lokasi sebelumnya!")
		Sounds.ErrorSound:Play()
		return
	end
	
	local tempOrigin = HRP.CFrame
	character:PivotTo(lastTeleportOrigin)
	lastTeleportOrigin = tempOrigin
	
	showNotification(Config.TeleportBackMessage)
	Sounds.TeleportSound:Play()
	startCooldown()
end


--================================================================
-- Penanganan Karakter & Platform
--================================================================

local function onCharacterAdded(newChar)
	character = newChar
	HRP = newChar:WaitForChild("HumanoidRootPart")
end

player.CharacterAdded:Connect(onCharacterAdded)

-- Fungsi untuk setup kontrol PC
local function setupPCControls()
	Sounds.PCDetectSound:Play()
	showNotification("Mode PC terdeteksi. Gunakan 1,2,3 / G,H,J / T.")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		-- Cek tombol save
		for i, keycode in ipairs(Config.SaveKeys) do
			if input.KeyCode == keycode then
				performSave(i)
			end
		end
		
		-- Cek tombol teleport
		for i, keycode in ipairs(Config.TeleportKeys) do
			if input.KeyCode == keycode then
				performTeleport(i)
			end
		end
		
		-- Cek tombol teleport kembali
		if input.KeyCode == Config.TeleportBackKey then
			performTeleportBack()
		end
	end)
end

-- Fungsi untuk setup GUI Seluler
local function setupMobileGUI()
	Sounds.MobileDetectSound:Play()
	showNotification("Mode Seluler terdeteksi.")
	
	local uiFrame = Instance.new("Frame")
	uiFrame.Size = UDim2.new(0.4, 0, 0.25, 0)
	uiFrame.Position = UDim2.new(0.98, 0, 0.5, 0)
	uiFrame.AnchorPoint = Vector2.new(1, 0.5)
	uiFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	uiFrame.BackgroundTransparency = 0.2
	uiFrame.Parent = mainGui
	local corner = Instance.new("UICorner", uiFrame)
	local layout = Instance.new("UIGridLayout", uiFrame)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.CellSize = UDim2.new(0.45, 0, 0.2, 0)
	layout.StartCorner = Enum.StartCorner.TopLeft
	
	-- Buat tombol untuk setiap slot
	local buttons = {}
	for i = 1, Config.MaxSlots do
		local saveBtn = Instance.new("TextButton")
		saveBtn.Name = "SaveButton" .. i
		saveBtn.Text = "Save " .. i
		saveBtn.BackgroundColor3 = Config.ButtonDefaultColor
		saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		saveBtn.Font = Enum.Font.Gotham
		saveBtn.TextScaled = true
		saveBtn.Parent = uiFrame
		local btnCorner1 = Instance.new("UICorner", saveBtn)
		
		local tpBtn = Instance.new("TextButton")
		tpBtn.Name = "TeleportButton" .. i
		tpBtn.Text = "TP " .. i
		tpBtn.BackgroundColor3 = Config.ButtonDefaultColor
		tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		tpBtn.Font = Enum.Font.Gotham
		tpBtn.TextScaled = true
		tpBtn.Parent = uiFrame
		local btnCorner2 = Instance.new("UICorner", tpBtn)
		
		-- Simpan referensi tombol
		buttons[i] = {Save = saveBtn, Teleport = tpBtn}
	end
	
	-- Buat tombol Teleport Kembali
	local backBtn = Instance.new("TextButton")
	backBtn.Name = "TeleportBackButton"
	backBtn.Text = "TP Back"
	backBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
	backBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	backBtn.Font = Enum.Font.Gotham
	backBtn.TextScaled = true
	backBtn.Parent = uiFrame
	local backCorner = Instance.new("UICorner", backBtn)
	layout.CellSize = UDim2.new(0.45, 0, 0.28, 0) -- Menyesuaikan ukuran agar muat

	-- Hubungkan event klik ke fungsi
	for i = 1, Config.MaxSlots do
		buttons[i].Save.MouseButton1Click:Connect(function()
			performSave(i, buttons[i].Save)
		end)
		buttons[i].Teleport.MouseButton1Click:Connect(function()
			performTeleport(i)
			-- Reset tombol save setelah teleport
			buttons[i].Save.BackgroundColor3 = Config.ButtonDefaultColor
			buttons[i].Save.Text = "Save " .. i
		end)
	end
	backBtn.MouseButton1Click:Connect(performTeleportBack)
end


--================================================================
-- DETEKSI PLATFORM & MULAI SKRIP
--================================================================
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	setupMobileGUI()
else
	setupPCControls()
end
