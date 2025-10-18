-- Minimal executor-friendly UI for automation: Equip Best Brainrots and Auto-buy shop items.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

-- ...configuration...
local Config = {
	defaultEquipInterval = 10,    -- seconds
	defaultBuyInterval = 300,     -- 5 minutes
	buyDelayBetweenItems = 0.5,   -- short delay between buy attempts
}

-- Plant list (display name => server item name). Most servers use "<Name> Seed".
local Plants = {
	"Cactus",
	"Strawberry",
	"Pumpkin",
	"Sunflower",
	"Dragon Fruit",
	"Eggplant",
	"Watermelon",
	"Grape",
	"Cocotank",
	"Carnivorous Plant",
	"Mr Carrot",
	"Tomatrio",
	"Shroombino",
	"Mango",
	"King Limone",
}

-- runtime state
local state = {
	equipEnabled = false,
	equipInterval = Config.defaultEquipInterval,
	buyEnabled = false,
	buyInterval = Config.defaultBuyInterval,
	selectedPlants = {}, -- set of item names (strings)
}

-- helper for safe remote calling
local function SafeFire(remote, ...)
	local ok, err = pcall(function() remote:FireServer(...) end)
	if not ok then
		-- swallow errors; executor console will show prints if needed
		-- print("Remote error:", err)
	end
end

-- map display name -> seed item name
local function ItemNameFor(display)
	return display .. " Seed"
end

-- create UI
local function CreateUI()
	-- remove previous instance if present
	for _, child in ipairs(PlayerGui:GetChildren()) do
		if child.Name == "PlantBotUI" then
			child:Destroy()
		end
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PlantBotUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = PlayerGui

	-- Simple draggable window
	local frame = Instance.new("Frame")
	frame.Name = "Window"
	frame.Size = UDim2.new(0, 420, 0, 360)
	frame.Position = UDim2.new(0.5, -210, 0.5, -180)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local uiCorner = Instance.new("UICorner", frame)
	uiCorner.CornerRadius = UDim.new(0, 6)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -12, 0, 30)
	title.Position = UDim2.new(0, 6, 0, 6)
	title.Text = "PlantBot — Automation"
	title.TextColor3 = Color3.fromRGB(230, 230, 230)
	title.Font = Enum.Font.SourceSansSemibold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	-- Tab label
	local tabLabel = Instance.new("TextLabel")
	tabLabel.BackgroundTransparency = 1
	tabLabel.Position = UDim2.new(0, 6, 0, 40)
	tabLabel.Size = UDim2.new(1, -12, 0, 18)
	tabLabel.Text = "Automation"
	tabLabel.TextColor3 = Color3.fromRGB(200,200,200)
	tabLabel.Font = Enum.Font.SourceSans
	tabLabel.TextSize = 14
	tabLabel.TextXAlignment = Enum.TextXAlignment.Left
	tabLabel.Parent = frame

	-- Equip Best section
	local equipSection = Instance.new("Frame")
	equipSection.Name = "EquipSection"
	equipSection.BackgroundTransparency = 1
	equipSection.Position = UDim2.new(0, 6, 0, 66)
	equipSection.Size = UDim2.new(1, -12, 0, 70)
	equipSection.Parent = frame

	local equipLabel = Instance.new("TextLabel")
	equipLabel.BackgroundTransparency = 1
	equipLabel.Position = UDim2.new(0, 0, 0, 0)
	equipLabel.Size = UDim2.new(1, 0, 0, 18)
	equipLabel.Text = "Equip Best Brainrots"
	equipLabel.TextSize = 14
	equipLabel.Font = Enum.Font.SourceSans
	equipLabel.TextColor3 = Color3.fromRGB(210,210,210)
	equipLabel.TextXAlignment = Enum.TextXAlignment.Left
	equipLabel.Parent = equipSection

	-- Equip toggle
	local equipToggle = Instance.new("TextButton")
	equipToggle.Name = "EquipToggle"
	equipToggle.Size = UDim2.new(0, 110, 0, 28)
	equipToggle.Position = UDim2.new(0, 0, 0, 22)
	equipToggle.BackgroundColor3 = Color3.fromRGB(50,50,50)
	equipToggle.TextColor3 = Color3.fromRGB(230,230,230)
	equipToggle.Font = Enum.Font.SourceSans
	equipToggle.TextSize = 14
	equipToggle.Text = "Enable"
	equipToggle.Parent = equipSection

	local equipIntervalBox = Instance.new("TextBox")
	equipIntervalBox.Name = "EquipInterval"
	equipIntervalBox.PlaceholderText = tostring(Config.defaultEquipInterval)
	equipIntervalBox.Text = ""
	equipIntervalBox.Size = UDim2.new(0, 120, 0, 28)
	equipIntervalBox.Position = UDim2.new(0, 120, 0, 22)
	equipIntervalBox.ClearTextOnFocus = false
	equipIntervalBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
	equipIntervalBox.TextColor3 = Color3.fromRGB(230,230,230)
	equipIntervalBox.Font = Enum.Font.SourceSans
	equipIntervalBox.TextSize = 14
	equipIntervalBox.Parent = equipSection

	local equipHint = Instance.new("TextLabel")
	equipHint.BackgroundTransparency = 1
	equipHint.Position = UDim2.new(0, 250, 0, 22)
	equipHint.Size = UDim2.new(0, 150, 0, 28)
	equipHint.Text = "interval (seconds)"
	equipHint.TextSize = 12
	equipHint.Font = Enum.Font.SourceSans
	equipHint.TextColor3 = Color3.fromRGB(170,170,170)
	equipHint.TextXAlignment = Enum.TextXAlignment.Left
	equipHint.Parent = equipSection

	-- Shop section
	local shopSection = Instance.new("Frame")
	shopSection.Name = "ShopSection"
	shopSection.BackgroundTransparency = 1
	shopSection.Position = UDim2.new(0, 6, 0, 150)
	shopSection.Size = UDim2.new(1, -12, 0, 200)
	shopSection.Parent = frame

	local shopLabel = Instance.new("TextLabel")
	shopLabel.BackgroundTransparency = 1
	shopLabel.Position = UDim2.new(0, 0, 0, 0)
	shopLabel.Size = UDim2.new(1, 0, 0, 18)
	shopLabel.Text = "Auto-buy Shop (multi-select)"
	shopLabel.TextSize = 14
	shopLabel.Font = Enum.Font.SourceSans
	shopLabel.TextColor3 = Color3.fromRGB(210,210,210)
	shopLabel.TextXAlignment = Enum.TextXAlignment.Left
	shopLabel.Parent = shopSection

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "PlantList"
	scroll.Position = UDim2.new(0, 0, 0, 22)
	scroll.Size = UDim2.new(1, 0, 0, 120)
	scroll.CanvasSize = UDim2.new(0, 0, 0, #Plants * 30)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarImageTransparency = 0.7
	scroll.Parent = shopSection

	local uiList = Instance.new("UIListLayout", scroll)
	uiList.Padding = UDim.new(0, 6)
	uiList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	uiList.SortOrder = Enum.SortOrder.LayoutOrder

	-- create plant buttons
	for i, name in ipairs(Plants) do
		local btn = Instance.new("TextButton")
		btn.Name = "Plant_" .. tostring(i)
		btn.Size = UDim2.new(1, -8, 0, 24)
		btn.Position = UDim2.new(0, 4, 0, (i-1) * 30)
		btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
		btn.TextColor3 = Color3.fromRGB(220,220,220)
		btn.Font = Enum.Font.SourceSans
		btn.TextSize = 14
		btn.Text = name
		btn.Parent = scroll

		-- toggle selection on click
		btn.MouseButton1Click:Connect(function()
			local item = ItemNameFor(name)
			if state.selectedPlants[item] then
				state.selectedPlants[item] = nil
				btn.BackgroundColor3 = Color3.fromRGB(45,45,45)
			else
				state.selectedPlants[item] = true
				btn.BackgroundColor3 = Color3.fromRGB(65,125,65)
			end
		end)
	end

	local buyControls = Instance.new("Frame")
	buyControls.BackgroundTransparency = 1
	buyControls.Position = UDim2.new(0, 0, 0, 150)
	buyControls.Size = UDim2.new(1, 0, 0, 44)
	buyControls.Parent = shopSection

	local buyToggle = Instance.new("TextButton")
	buyToggle.Name = "BuyToggle"
	buyToggle.Size = UDim2.new(0, 110, 0, 28)
	buyToggle.Position = UDim2.new(0, 0, 0, 0)
	buyToggle.BackgroundColor3 = Color3.fromRGB(50,50,50)
	buyToggle.TextColor3 = Color3.fromRGB(230,230,230)
	buyToggle.Font = Enum.Font.SourceSans
	buyToggle.TextSize = 14
	buyToggle.Text = "Start Buying"
	buyToggle.Parent = buyControls

	local buyIntervalBox = Instance.new("TextBox")
	buyIntervalBox.Name = "BuyInterval"
	buyIntervalBox.PlaceholderText = tostring(Config.defaultBuyInterval)
	buyIntervalBox.Text = ""
	buyIntervalBox.Size = UDim2.new(0, 120, 0, 28)
	buyIntervalBox.Position = UDim2.new(0, 120, 0, 0)
	buyIntervalBox.ClearTextOnFocus = false
	buyIntervalBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
	buyIntervalBox.TextColor3 = Color3.fromRGB(230,230,230)
	buyIntervalBox.Font = Enum.Font.SourceSans
	buyIntervalBox.TextSize = 14
	buyIntervalBox.Parent = buyControls

	local buyHint = Instance.new("TextLabel")
	buyHint.BackgroundTransparency = 1
	buyHint.Position = UDim2.new(0, 250, 0, 0)
	buyHint.Size = UDim2.new(0, 150, 0, 28)
	buyHint.Text = "interval (seconds)"
	buyHint.TextSize = 12
	buyHint.Font = Enum.Font.SourceSans
	buyHint.TextColor3 = Color3.fromRGB(170,170,170)
	buyHint.TextXAlignment = Enum.TextXAlignment.Left
	buyHint.Parent = buyControls

	-- UX: clicking title will close
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			screenGui:Destroy()
		end
	end)

	-- button interactions
	equipToggle.MouseButton1Click:Connect(function()
		state.equipEnabled = not state.equipEnabled
		equipToggle.Text = state.equipEnabled and "Disable" or "Enable"
		equipToggle.BackgroundColor3 = state.equipEnabled and Color3.fromRGB(70,140,70) or Color3.fromRGB(50,50,50)

		-- read interval
		local v = tonumber(equipIntervalBox.Text)
		if v and v > 0 then state.equipInterval = v end

		-- spawn loop if enabled
		if state.equipEnabled then
			spawn(function()
				local remote = RemotesFolder:WaitForChild("EquipBestBrainrots")
				while state.equipEnabled do
					pcall(function()
						SafeFire(remote)
					end)
					local i = state.equipInterval or Config.defaultEquipInterval
					wait(i)
				end
			end)
		end
	end)

	buyToggle.MouseButton1Click:Connect(function()
		state.buyEnabled = not state.buyEnabled
		buyToggle.Text = state.buyEnabled and "Stop Buying" or "Start Buying"
		buyToggle.BackgroundColor3 = state.buyEnabled and Color3.fromRGB(70,140,70) or Color3.fromRGB(50,50,50)

		-- read interval
		local v = tonumber(buyIntervalBox.Text)
		if v and v > 0 then state.buyInterval = v end

		if state.buyEnabled then
			spawn(function()
				local buyRemote = RemotesFolder:WaitForChild("BuyItem")
				while state.buyEnabled do
					-- iterate selected plants
					for itemName, _ in pairs(state.selectedPlants) do
						-- build args expected by server
						local args = { itemName, true }
						SafeFire(buyRemote, unpack(args))
						wait(Config.buyDelayBetweenItems)
					end
					local i = state.buyInterval or Config.defaultBuyInterval
					wait(i)
				end
			end)
		end
	end)
end

-- run
CreateUI()

-- optional: expose toggles to getgenv for quick control from console
getgenv().PlantBot = {
	state = state,
	toggleEquip = function(val) state.equipEnabled = val end,
	toggleBuy = function(val) state.buyEnabled = val end,
}
