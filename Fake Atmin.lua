--[[
	Admin Panel Script V3 - Fitur Lengkap
	By: Luchifres ( Sann )

	PERINGATAN: Sesuai permintaan, sistem verifikasi admin telah DIHAPUS.
	Semua pemain yang masuk akan mendapatkan akses ke panel ini.

	Fitur Baru:
	- Perintah: kill, heal, speed, jumppower.
	- GUI: Daftar pemain (player list) yang bisa diklik.
	- GUI: Tombol toggle untuk fly/god dengan indikator visual.
	- GUI: Tab untuk mengorganisir perintah (Pemain & Mandiri).
	- GUI: Keybind (kunci ;) untuk membuka/menutup panel.
]]

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- KONFIGURASI
local COMMAND_PREFIX = ";"
local TOGGLE_KEY = Enum.KeyCode.Semicolon -- Tombol untuk membuka/menutup panel

-- REMOTE EVENTS
local AdminEvent = Instance.new("RemoteEvent")
AdminEvent.Name = "AdminEvent"
AdminEvent.Parent = ReplicatedStorage

local PlayerListEvent = Instance.new("RemoteEvent")
PlayerListEvent.Name = "PlayerListEvent"
PlayerListEvent.Parent = ReplicatedStorage

-- VARIABEL UNTUK MELACAK STATUS
local playerStatus = {}

-- =============================================================================
-- ||                            FUNGSI INTI PERINTAH                         ||
-- =============================================================================

local Commands = {}

-- Fungsi untuk mengirim feedback ke client
local function sendFeedback(player, message, isError)
	AdminEvent:FireClient(player, "Feedback", {Message = message, IsError = isError})
end

-- Fungsi untuk update status toggle di client
local function updateToggleState(player, command, state)
	AdminEvent:FireClient(player, "UpdateToggle", {Command = command, State = state})
end

-- Fungsi mencari target
local function findTarget(name)
	for _, player in ipairs(Players:GetPlayers()) do
		if string.sub(string.lower(player.Name), 1, #name) == string.lower(name) then
			return player
		end
	end
	return nil
end


--- PERINTAH MANDIRI (SELF)
Commands.fly = function(player)
	-- ... (logika fly sama seperti sebelumnya, tapi sekarang memanggil updateToggleState)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	
	local humanoid = char.Humanoid
	local rootPart = char.HumanoidRootPart
	
	playerStatus[player.UserId] = playerStatus[player.UserId] or {}
	local isFlying = not playerStatus[player.UserId].isFlying -- Toggle state
	playerStatus[player.UserId].isFlying = isFlying
	
	if isFlying then
		humanoid.PlatformStand = true
		local gyro = Instance.new("BodyGyro", rootPart)
		gyro.Name = "AdminBodyGyro"
		gyro.P = 9e4
		gyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
		gyro.CFrame = rootPart.CFrame
		
		local velocity = Instance.new("BodyVelocity", rootPart)
		velocity.Name = "AdminBodyVelocity"
		velocity.velocity = Vector3.new(0,0,0)
		velocity.maxForce = Vector3.new(9e9, 9e9, 9e9)
		
		sendFeedback(player, "Fly diaktifkan.", false)
	else
		if rootPart:FindFirstChild("AdminBodyGyro") then rootPart.AdminBodyGyro:Destroy() end
		if rootPart:FindFirstChild("AdminBodyVelocity") then rootPart.AdminBodyVelocity:Destroy() end
		humanoid.PlatformStand = false
		sendFeedback(player, "Fly dinonaktifkan.", false)
	end
	updateToggleState(player, "fly", isFlying)
end

Commands.god = function(player)
	-- ... (logika god sama seperti sebelumnya, tapi sekarang memanggil updateToggleState)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	playerStatus[player.UserId] = playerStatus[player.UserId] or {}
	local isGod = not playerStatus[player.UserId].isGod -- Toggle state
	playerStatus[player.UserId].isGod = isGod
	
	if isGod then
		humanoid.MaxHealth = math.huge
		humanoid.Health = humanoid.MaxHealth
		sendFeedback(player, "God mode diaktifkan.", false)
	else
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		sendFeedback(player, "God mode dinonaktifkan.", false)
	end
	updateToggleState(player, "god", isGod)
end

--- PERINTAH TARGET
Commands.kill = function(admin, targetName)
	local target = findTarget(targetName)
	if target and target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
		target.Character.Humanoid.Health = 0
		sendFeedback(admin, target.Name .. " telah di-kill.", false)
	else
		sendFeedback(admin, "Target tidak ditemukan.", true)
	end
end

Commands.heal = function(admin, targetName)
	local target = findTarget(targetName)
	if target and target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
		local humanoid = target.Character.Humanoid
		humanoid.Health = humanoid.MaxHealth
		sendFeedback(admin, target.Name .. " telah di-heal.", false)
	else
		sendFeedback(admin, "Target tidak ditemukan.", true)
	end
end

Commands.speed = function(admin, targetName, value)
	local speedValue = tonumber(value) or 16 -- Default speed
	local target = findTarget(targetName)
	if target and target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
		target.Character.Humanoid.WalkSpeed = speedValue
		sendFeedback(admin, "Speed "..target.Name.." diatur ke "..speedValue..".", false)
	else
		sendFeedback(admin, "Target tidak ditemukan.", true)
	end
end

Commands.jumppower = function(admin, targetName, value)
	local jumpValue = tonumber(value) or 50 -- Default jump power
	local target = findTarget(targetName)
	if target and target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
		target.Character.Humanoid.JumpPower = jumpValue
		sendFeedback(admin, "Jump Power "..target.Name.." diatur ke "..jumpValue..".", false)
	else
		sendFeedback(admin, "Target tidak ditemukan.", true)
	end
end


-- =============================================================================
-- ||                         LOGIKA EKSEKUSI PERINTAH                        ||
-- =============================================================================

local function executeCommand(player, commandName, args)
	local cmdFunc = Commands[string.lower(commandName)]
	if cmdFunc then
		cmdFunc(player, table.unpack(args))
	else
		sendFeedback(player, "Perintah tidak dikenal.", true)
	end
end

AdminEvent.OnServerEvent:Connect(function(player, action, data)
	if action == "ExecuteCommand" then
		executeCommand(player, data.Command, data.Args)
	end
end)


-- =============================================================================
-- ||                     MANAJEMEN PLAYER & PEMBUATAN GUI                    ||
-- =============================================================================

local function updatePlayerLists(action, playerInfo)
	PlayerListEvent:FireAllClients(action, playerInfo)
end

Players.PlayerAdded:Connect(function(player)
	-- Kirim informasi pemain baru ke semua client
	updatePlayerLists("Add", {Name = player.Name, UserId = player.UserId})

	-- Hapus status lama jika ada
	playerStatus[player.UserId] = nil

	-- Buat GUI untuk pemain yang baru masuk
	local adminGuiScript = [[
		-- Script ini akan berjalan di sisi client (pemain)
		local player = game.Players.LocalPlayer
		local UserInputService = game:GetService("UserInputService")
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		
		-- REMOTE EVENTS
		local AdminEvent = ReplicatedStorage:WaitForChild("AdminEvent")
		local PlayerListEvent = ReplicatedStorage:WaitForChild("PlayerListEvent")

		-- STATE VARIABLES
		local selectedPlayerName = player.Name -- Default target adalah diri sendiri
		local commandToggles = { fly = false, god = false }

		-- ================== GUI CREATION ==================
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "AdminPanelGUI"
		screenGui.ResetOnSpawn = false
		
		local mainFrame = Instance.new("Frame")
		mainFrame.Size = UDim2.new(0, 400, 0, 300)
		mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
		mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		mainFrame.Draggable = true
		mainFrame.Active = true
		mainFrame.Visible = true
		mainFrame.Parent = screenGui
		
		Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

		local title = Instance.new("TextLabel", mainFrame)
		title.Size = UDim2.new(1, 0, 0, 30)
		title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		title.Text = "Admin Panel"
		title.Font = Enum.Font.SourceSansBold
		title.TextSize = 18
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		
		local keybindLabel = Instance.new("TextLabel", title)
		keybindLabel.Size = UDim2.new(1, -10, 1, 0)
		keybindLabel.BackgroundTransparency = 1
		keybindLabel.Text = "Tekan ';' untuk toggle"
		keybindLabel.Font = Enum.Font.SourceSans
		keybindLabel.TextSize = 14
		keybindLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		keybindLabel.TextXAlignment = Enum.TextXAlignment.Right

		-- === TABS ===
		local tabsFrame = Instance.new("Frame", mainFrame)
		tabsFrame.Size = UDim2.new(1, 0, 0, 30)
		tabsFrame.Position = UDim2.new(0, 0, 0, 30)
		tabsFrame.BackgroundTransparency = 1
		tabsFrame.ClipsDescendants = true
		
		local tabLayout = Instance.new("UIListLayout", tabsFrame)
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.Padding = UDim.new(0, 5)

		local contentFrame = Instance.new("Frame", mainFrame)
		contentFrame.Size = UDim2.new(1, -10, 1, -65)
		contentFrame.Position = UDim2.new(0.5, -195, 0, 65)
		contentFrame.BackgroundTransparency = 1

		-- === PAGES ===
		local playerPage = Instance.new("Frame", contentFrame)
		playerPage.Size = UDim2.new(1, 0, 1, 0)
		playerPage.BackgroundTransparency = 1
		playerPage.Visible = true

		local selfPage = Instance.new("Frame", contentFrame)
		selfPage.Size = UDim2.new(1, 0, 1, 0)
		selfPage.BackgroundTransparency = 1
		selfPage.Visible = false
		
		local pages = { Player = playerPage, Mandiri = selfPage }
		local activeTabButton = nil

		local function switchTab(button, page)
			if activeTabButton then
				activeTabButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			end
			for _, p in pairs(pages) do p.Visible = false end
			
			button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			page.Visible = true
			activeTabButton = button
		end

		local function createTab(text)
			local button = Instance.new("TextButton", tabsFrame)
			button.Size = UDim2.new(0, 80, 1, 0)
			button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			button.Text = text
			button.Font = Enum.Font.SourceSansBold
			button.TextSize = 14
			button.TextColor3 = Color3.fromRGB(220, 220, 220)
			
			button.MouseButton1Click:Connect(function()
				switchTab(button, pages[text])
			end)
			return button
		end

		local playerTabButton = createTab("Player")
		local selfTabButton = createTab("Mandiri")
		
		-- === PLAYER PAGE CONTENT ===
		local playerList = Instance.new("ScrollingFrame", playerPage)
		playerList.Size = UDim2.new(0.4, -5, 1, -30)
		playerList.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		Instance.new("UIListLayout", playerList).Padding = UDim.new(0, 2)

		local selectedPlayerLabel = Instance.new("TextLabel", playerPage)
		selectedPlayerLabel.Size = UDim2.new(0.4, -5, 0, 25)
		selectedPlayerLabel.Position = UDim2.new(0, 0, 1, -25)
		selectedPlayerLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		selectedPlayerLabel.Font = Enum.Font.SourceSansBold
		selectedPlayerLabel.Text = "Pemain: " .. selectedPlayerName
		selectedPlayerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		
		local playerCommandsFrame = Instance.new("Frame", playerPage)
		playerCommandsFrame.Size = UDim2.new(0.6, -5, 1, 0)
		playerCommandsFrame.Position = UDim2.new(0.4, 5, 0, 0)
		playerCommandsFrame.BackgroundTransparency = 1
		Instance.new("UIListLayout", playerCommandsFrame).Padding = UDim.new(0, 5)
		
		local valueInput = Instance.new("TextBox", playerCommandsFrame)
		valueInput.Size = UDim2.new(1, 0, 0, 30)
		valueInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		valueInput.PlaceholderText = "Value (untuk speed/jump)"
		valueInput.Font = Enum.Font.SourceSans
		valueInput.TextSize = 14
		valueInput.TextColor3 = Color3.fromRGB(220, 220, 220)

		-- === SELF PAGE CONTENT ===
		Instance.new("UIListLayout", selfPage).Padding = UDim.new(0, 5)

		-- === STATUS LABEL ===
		local statusLabel = Instance.new("TextLabel", mainFrame)
		statusLabel.Size = UDim2.new(1, -10, 0, 20)
		statusLabel.Position = UDim2.new(0.5, -195, 1, -20)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.SourceSans
		statusLabel.TextSize = 14
		statusLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left

		-- ================== FUNCTIONS ==================
		local function fireCommand(command, args)
			AdminEvent:FireServer("ExecuteCommand", {Command = command, Args = args or {}})
		end
		
		local function createPlayerCmdButton(text, command)
			local button = Instance.new("TextButton", playerCommandsFrame)
			button.Size = UDim2.new(1, 0, 0, 35)
			button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			button.Text = text
			button.Font = Enum.Font.SourceSansBold
			button.TextColor3 = Color3.fromRGB(255, 255, 255)
			
			button.MouseButton1Click:Connect(function()
				local args = {selectedPlayerName}
				if command == "speed" or command == "jumppower" then
					table.insert(args, valueInput.Text)
				end
				fireCommand(command, args)
			end)
		end

		local function createSelfCmdButton(text, command)
			local button = Instance.new("TextButton", selfPage)
			button.Name = command
			button.Size = UDim2.new(1, 0, 0, 35)
			button.BackgroundColor3 = Color3.fromRGB(180, 50, 50) -- Default OFF color
			button.Text = text .. " [OFF]"
			button.Font = Enum.Font.SourceSansBold
			button.TextColor3 = Color3.fromRGB(255, 255, 255)
			
			button.MouseButton1Click:Connect(function()
				fireCommand(command, {player.Name})
			end)
			return button
		end

		-- Create buttons
		createPlayerCmdButton("Kill", "kill")
		createPlayerCmdButton("Heal", "heal")
		createPlayerCmdButton("Set Speed", "speed")
		createPlayerCmdButton("Set Jump", "jumppower")
		local flyButton = createSelfCmdButton("Fly", "fly")
		local godButton = createSelfCmdButton("God Mode", "god")

		-- PLAYER LIST MANAGEMENT
		local playerButtons = {}

		function updatePlayerList(action, info)
			if action == "Add" then
				local button = Instance.new("TextButton", playerList)
				button.Size = UDim2.new(1, 0, 0, 25)
				button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
				button.Text = info.Name
				button.Font = Enum.Font.SourceSans
				button.TextColor3 = Color3.fromRGB(200, 200, 200)
				
				button.MouseButton1Click:Connect(function()
					selectedPlayerName = info.Name
					selectedPlayerLabel.Text = "Pemain: " .. info.Name
				end)
				playerButtons[info.UserId] = button
			elseif action == "Remove" then
				if playerButtons[info.UserId] then
					playerButtons[info.UserId]:Destroy()
					playerButtons[info.UserId] = nil
				end
			end
		end
		
		-- ================== EVENT LISTENERS ==================
		PlayerListEvent.OnClientEvent:Connect(updatePlayerList)
		
		AdminEvent.OnClientEvent:Connect(function(action, data)
			if action == "Feedback" then
				statusLabel.Text = data.Message
				statusLabel.TextColor3 = data.IsError and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(0, 255, 127)
				wait(4)
				if statusLabel.Text == data.Message then statusLabel.Text = "" end
			elseif action == "UpdateToggle" then
				local button = selfPage:FindFirstChild(data.Command)
				commandToggles[data.Command] = data.State
				if data.State then -- ON
					button.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
					button.Text = button.Text:gsub("OFF", "ON")
				else -- OFF
					button.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
					button.Text = button.Text:gsub("ON", "OFF")
				end
			end
		end)
		
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == Enum.KeyCode.Semicolon then
				mainFrame.Visible = not mainFrame.Visible
			end
		end)
		
		-- Final setup
		switchTab(playerTabButton, playerPage)
		screenGui.Parent = player:WaitForChild("PlayerGui")
		
		-- Initial player list population
		for _, p in ipairs(game.Players:GetPlayers()) do
			updatePlayerList("Add", {Name = p.Name, UserId = p.UserId})
		end
	]]
	
	local newScript = Instance.new("LocalScript")
	newScript.Name = "AdminClient"
	newScript.Source = adminGuiScript
	newScript.Parent = player:WaitForChild("PlayerGui")
end)

Players.PlayerRemoving:Connect(function(player)
	-- Hapus status & update list di semua client
	if playerStatus[player.UserId] then
		playerStatus[player.UserId] = nil
	end
	updatePlayerLists("Remove", {UserId = player.UserId})
end)
