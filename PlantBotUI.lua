-- Standalone executor-friendly UI: Equip Best Brainrots + Auto-buy (no external libs)

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

-- config
local Config = {
	defaultEquipInterval = 10,    -- seconds
	buyDelayBetweenItems = 0.5,   -- delay between buy attempts for each item
	cycleDelay = 1.0,             -- small pause between full cycles (prevents tight loop)
}

local Plants = {
	"Cactus","Strawberry","Pumpkin","Sunflower","Dragon Fruit","Eggplant",
	"Watermelon","Grape","Cocotank","Carnivorous Plant","Mr Carrot",
	"Tomatrio","Shroombino","Mango","King Limone",
}

local Gear = {
	"Water Bucket", "Frost Grenade", "Banana Gun", "Frost Blower", "Carrot Launcher"
}

-- runtime state
local state = {
	equipEnabled = false,
	equipInterval = Config.defaultEquipInterval,
	buyEnabled = false,         -- for seeds
	gearBuyEnabled = false,   -- for gear
	selectedPlants = {},      -- set of server item names (e.g., "Sunflower Seed")
	selectedGear = {},        -- set of gear item names
	uiVisible = true,
}

-- safe remote fire that forwards varargs properly through pcall
local function SafeFire(remote, ...)
	local args = {...}
	pcall(function() remote:FireServer(table.unpack(args)) end)
end

local function ItemNameFor(display)
	return display .. " Seed"
end

-- remove any existing UI
for _, child in ipairs(PlayerGui:GetChildren()) do
	if child.Name == "PlantBotUI" or child.Name == "PlantBot_OpenButton" then
		child:Destroy()
	end
end

-- small "Open UI" button (shown when main UI minimized/hidden)
local openButton = Instance.new("ScreenGui")
openButton.Name = "PlantBot_OpenButton"
openButton.ResetOnSpawn = false
openButton.Parent = PlayerGui

local openFrame = Instance.new("TextButton")
openFrame.Name = "OpenBtn"
openFrame.Size = UDim2.new(0, 120, 0, 34)
openFrame.Position = UDim2.new(1, -130, 1, -80)
openFrame.AnchorPoint = Vector2.new(0,0)
openFrame.Text = "Open PlantBot"
openFrame.BackgroundColor3 = Color3.fromRGB(45,45,45)
openFrame.TextColor3 = Color3.fromRGB(230,230,230)
openFrame.Font = Enum.Font.SourceSansSemibold
openFrame.TextSize = 14
openFrame.Parent = openButton

local openCorner = Instance.new("UICorner", openFrame)
openCorner.CornerRadius = UDim.new(0, 6)

openFrame.MouseButton1Click:Connect(function()
	-- show main UI if present; otherwise create it
	local gui = PlayerGui:FindFirstChild("PlantBotUI")
	if gui and gui:IsA("ScreenGui") then
		gui.Enabled = true
		openButton.Enabled = false
	end
end)

-- main UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlantBotUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Name = "Window"
frame.Size = UDim2.new(0, 460, 0, 420)
frame.Position = UDim2.new(0.5, -230, 0.5, -210)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(28,28,30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner", frame)
frameCorner.CornerRadius = UDim.new(0, 8)

local frameStroke = Instance.new("UIStroke", frame)
frameStroke.Color = Color3.fromRGB(60,60,60)
frameStroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -12, 0, 34)
title.Position = UDim2.new(0, 8, 0, 8)
title.Text = "PlantBot — Automation"
title.TextColor3 = Color3.fromRGB(235,235,235)
title.Font = Enum.Font.SourceSansSemibold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 8)
closeBtn.AnchorPoint = Vector2.new(0,0)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 16
closeBtn.BackgroundColor3 = Color3.fromRGB(55,55,55)
closeBtn.TextColor3 = Color3.fromRGB(230,230,230)
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -72, 0, 8)
minimizeBtn.Text = "—"
minimizeBtn.Font = Enum.Font.SourceSansBold
minimizeBtn.TextSize = 18
minimizeBtn.BackgroundColor3 = Color3.fromRGB(55,55,55)
minimizeBtn.TextColor3 = Color3.fromRGB(230,230,230)
minimizeBtn.Parent = frame
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0,6)

-- Tab buttons
local tabsContainer = Instance.new("Frame", frame)
tabsContainer.Name = "Tabs"
tabsContainer.BackgroundTransparency = 1
tabsContainer.Position = UDim2.new(0, 12, 0, 50)
tabsContainer.Size = UDim2.new(1, -24, 0, 30)

local homeTabBtn = Instance.new("TextButton", tabsContainer)
homeTabBtn.Name = "HomeTab"
homeTabBtn.Size = UDim2.new(0, 80, 1, 0)
homeTabBtn.Text = "Home"
homeTabBtn.Font = Enum.Font.SourceSansSemibold
homeTabBtn.TextSize = 14
homeTabBtn.BackgroundColor3 = Color3.fromRGB(45,45,45) -- Active
homeTabBtn.TextColor3 = Color3.fromRGB(235,235,235)
Instance.new("UICorner", homeTabBtn).CornerRadius = UDim.new(0,6)

local shopsTabBtn = Instance.new("TextButton", tabsContainer)
shopsTabBtn.Name = "ShopsTab"
shopsTabBtn.Position = UDim2.new(0, 88, 0, 0)
shopsTabBtn.Size = UDim2.new(0, 80, 1, 0)
shopsTabBtn.Text = "Shops"
shopsTabBtn.Font = Enum.Font.SourceSansSemibold
shopsTabBtn.TextSize = 14
shopsTabBtn.BackgroundColor3 = Color3.fromRGB(28,28,30) -- Inactive
shopsTabBtn.TextColor3 = Color3.fromRGB(170,170,170)
Instance.new("UICorner", shopsTabBtn).CornerRadius = UDim.new(0,6)

-- pages container
local pages = Instance.new("Frame", frame)
pages.Name = "Pages"
pages.BackgroundTransparency = 1
pages.Position = UDim2.new(0, 12, 0, 88)
pages.Size = UDim2.new(1, -24, 1, -100)

-- Home Page
local homePage = Instance.new("Frame", pages)
homePage.Name = "HomePage"
homePage.Size = UDim2.new(1, 0, 1, 0)
homePage.BackgroundTransparency = 1
homePage.Visible = true

-- Shops Page
local shopsPage = Instance.new("Frame", pages)
shopsPage.Name = "ShopsPage"
shopsPage.Size = UDim2.new(1, 0, 1, 0)
shopsPage.BackgroundTransparency = 1
shopsPage.Visible = false

-- Tab switching logic
homeTabBtn.MouseButton1Click:Connect(function()
	homePage.Visible = true
	shopsPage.Visible = false
	homeTabBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
	homeTabBtn.TextColor3 = Color3.fromRGB(235,235,235)
	shopsTabBtn.BackgroundColor3 = Color3.fromRGB(28,28,30)
	shopsTabBtn.TextColor3 = Color3.fromRGB(170,170,170)
end)

shopsTabBtn.MouseButton1Click:Connect(function()
	homePage.Visible = false
	shopsPage.Visible = true
	shopsTabBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
	shopsTabBtn.TextColor3 = Color3.fromRGB(235,235,235)
	homeTabBtn.BackgroundColor3 = Color3.fromRGB(28,28,30)
	homeTabBtn.TextColor3 = Color3.fromRGB(170,170,170)
end)

-- Equip section (on Home Page)
local equipSection = Instance.new("Frame", homePage)
equipSection.Size = UDim2.new(1, 0, 0, 90)
equipSection.BackgroundTransparency = 1

local equipLabel = Instance.new("TextLabel", equipSection)
equipLabel.Text = "Equip Best Brainrots"
equipLabel.BackgroundTransparency = 1
equipLabel.Position = UDim2.new(0,0,0,0)
equipLabel.Size = UDim2.new(1, 0, 0, 20)
equipLabel.TextColor3 = Color3.fromRGB(220,220,220)
equipLabel.Font = Enum.Font.SourceSans
equipLabel.TextSize = 14
equipLabel.TextXAlignment = Enum.TextXAlignment.Left

local equipToggle = Instance.new("TextButton", equipSection)
equipToggle.Name = "EquipToggle"
equipToggle.Size = UDim2.new(0, 120, 0, 30)
equipToggle.Position = UDim2.new(0, 0, 0, 26)
equipToggle.Text = "Enable"
equipToggle.Font = Enum.Font.SourceSans
equipToggle.TextSize = 14
equipToggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
equipToggle.TextColor3 = Color3.fromRGB(235,235,235)
Instance.new("UICorner", equipToggle).CornerRadius = UDim.new(0,6)

local equipIntervalBox = Instance.new("TextBox", equipSection)
equipIntervalBox.Name = "EquipInterval"
equipIntervalBox.PlaceholderText = tostring(Config.defaultEquipInterval)
equipIntervalBox.Text = ""
equipIntervalBox.Size = UDim2.new(0, 120, 0, 30)
equipIntervalBox.Position = UDim2.new(0, 140, 0, 26)
equipIntervalBox.ClearTextOnFocus = false
equipIntervalBox.BackgroundColor3 = Color3.fromRGB(45,45,45)
equipIntervalBox.TextColor3 = Color3.fromRGB(235,235,235)
equipIntervalBox.Font = Enum.Font.SourceSans
equipIntervalBox.TextSize = 14
Instance.new("UICorner", equipIntervalBox).CornerRadius = UDim.new(0,6)

local equipHint = Instance.new("TextLabel", equipSection)
equipHint.Text = "interval (seconds)"
equipHint.BackgroundTransparency = 1
equipHint.Position = UDim2.new(0, 280, 0, 28)
equipHint.Size = UDim2.new(0, 160, 0, 24)
equipHint.TextColor3 = Color3.fromRGB(170,170,170)
equipHint.Font = Enum.Font.SourceSans
equipHint.TextSize = 12
equipHint.TextXAlignment = Enum.TextXAlignment.Left

-- Seed Shop section (on Shops Page)
local seedShopSection = Instance.new("Frame", shopsPage)
seedShopSection.Position = UDim2.new(0, 0, 0, 0)
seedShopSection.Size = UDim2.new(0.5, -4, 1, 0)
seedShopSection.BackgroundTransparency = 1

local shopLabel = Instance.new("TextLabel", seedShopSection)
shopLabel.Text = "Auto-buy Seeds"
shopLabel.BackgroundTransparency = 1
shopLabel.Position = UDim2.new(0,0,0,0)
shopLabel.Size = UDim2.new(1, 0, 0, 20)
shopLabel.TextColor3 = Color3.fromRGB(220,220,220)
shopLabel.Font = Enum.Font.SourceSans
shopLabel.TextSize = 14
shopLabel.TextXAlignment = Enum.TextXAlignment.Left

local scroll = Instance.new("ScrollingFrame", seedShopSection)
scroll.Name = "PlantList"
scroll.Position = UDim2.new(0,0,0,26)
scroll.Size = UDim2.new(1, 0, 1, -78)
scroll.BackgroundTransparency = 1
scroll.ScrollBarImageTransparency = 0.7
scroll.CanvasSize = UDim2.new(0,0,0,#Plants * 34)
local uiList = Instance.new("UIListLayout", scroll)
uiList.Padding = UDim.new(0,6)
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Left
uiList.SortOrder = Enum.SortOrder.LayoutOrder

local buyToggle = Instance.new("TextButton", seedShopSection)
buyToggle.Name = "BuyToggle"
buyToggle.Size = UDim2.new(1, 0, 0, 34)
buyToggle.Position = UDim2.new(0, 0, 1, -46)
buyToggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
buyToggle.TextColor3 = Color3.fromRGB(235,235,235)
buyToggle.Font = Enum.Font.SourceSans
buyToggle.TextSize = 14
buyToggle.Text = "Start Auto-Buy"
Instance.new("UICorner", buyToggle).CornerRadius = UDim.new(0,6)

-- create plant buttons (toggle selection)
for i, name in ipairs(Plants) do
	local btn = Instance.new("TextButton")
	btn.Name = "Plant_" .. tostring(i)
	btn.Size = UDim2.new(1, -8, 0, 28)
	btn.Position = UDim2.new(0, 4, 0, (i-1) * 34)
	btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
	btn.TextColor3 = Color3.fromRGB(235,235,235)
	btn.Font = Enum.Font.SourceSans
	btn.TextSize = 14
	btn.Text = name
	btn.Parent = scroll
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

	btn.MouseButton1Click:Connect(function()
		local item = ItemNameFor(name)
		if state.selectedPlants[item] then
			state.selectedPlants[item] = nil
			btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
		else
			state.selectedPlants[item] = true
			btn.BackgroundColor3 = Color3.fromRGB(65,125,65)
		end
	end)
end

-- Gear Shop section (on Shops Page)
local gearShopSection = Instance.new("Frame", shopsPage)
gearShopSection.Position = UDim2.new(0.5, 4, 0, 0)
gearShopSection.Size = UDim2.new(0.5, -4, 1, 0)
gearShopSection.BackgroundTransparency = 1

local gearShopLabel = Instance.new("TextLabel", gearShopSection)
gearShopLabel.Text = "Auto-buy Gear"
gearShopLabel.BackgroundTransparency = 1
gearShopLabel.Position = UDim2.new(0,0,0,0)
gearShopLabel.Size = UDim2.new(1, 0, 0, 20)
gearShopLabel.TextColor3 = Color3.fromRGB(220,220,220)
gearShopLabel.Font = Enum.Font.SourceSans
gearShopLabel.TextSize = 14
gearShopLabel.TextXAlignment = Enum.TextXAlignment.Left

local gearScroll = Instance.new("ScrollingFrame", gearShopSection)
gearScroll.Name = "GearList"
gearScroll.Position = UDim2.new(0,0,0,26)
gearScroll.Size = UDim2.new(1, 0, 1, -78)
gearScroll.BackgroundTransparency = 1
gearScroll.ScrollBarImageTransparency = 0.7
gearScroll.CanvasSize = UDim2.new(0,0,0,#Gear * 34)
local gearUiList = Instance.new("UIListLayout", gearScroll)
gearUiList.Padding = UDim.new(0,6)
gearUiList.HorizontalAlignment = Enum.HorizontalAlignment.Left
gearUiList.SortOrder = Enum.SortOrder.LayoutOrder

local gearBuyToggle = Instance.new("TextButton", gearShopSection)
gearBuyToggle.Name = "GearBuyToggle"
gearBuyToggle.Size = UDim2.new(1, 0, 0, 34)
gearBuyToggle.Position = UDim2.new(0, 0, 1, -46)
gearBuyToggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
gearBuyToggle.TextColor3 = Color3.fromRGB(235,235,235)
gearBuyToggle.Font = Enum.Font.SourceSans
gearBuyToggle.TextSize = 14
gearBuyToggle.Text = "Start Auto-Buy"
Instance.new("UICorner", gearBuyToggle).CornerRadius = UDim.new(0,6)

-- create gear buttons (toggle selection)
for i, name in ipairs(Gear) do
	local btn = Instance.new("TextButton")
	btn.Name = "Gear_" .. tostring(i)
	btn.Size = UDim2.new(1, -8, 0, 28)
	btn.Position = UDim2.new(0, 4, 0, (i-1) * 34)
	btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
	btn.TextColor3 = Color3.fromRGB(235,235,235)
	btn.Font = Enum.Font.SourceSans
	btn.TextSize = 14
	btn.Text = name
	btn.Parent = gearScroll
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

	btn.MouseButton1Click:Connect(function()
		if state.selectedGear[name] then
			state.selectedGear[name] = nil
			btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
		else
			state.selectedGear[name] = true
			btn.BackgroundColor3 = Color3.fromRGB(65,125,65)
		end
	end)
end

-- Dragging logic for main frame
local dragging = false
local dragStart = nil
local startPos = nil

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- button behaviors
closeBtn.MouseButton1Click:Connect(function()
	-- fully close UI and show open button
	screenGui.Enabled = false
	openButton.Enabled = true
end)

minimizeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
	openButton.Enabled = true
end)

equipToggle.MouseButton1Click:Connect(function()
	state.equipEnabled = not state.equipEnabled
	equipToggle.Text = state.equipEnabled and "Disable" or "Enable"
	equipToggle.BackgroundColor3 = state.equipEnabled and Color3.fromRGB(70,140,70) or Color3.fromRGB(60,60,60)

	local v = tonumber(equipIntervalBox.Text)
	if v and v > 0 then state.equipInterval = v end

	if state.equipEnabled then
		spawn(function()
			local remote = RemotesFolder:WaitForChild("EquipBestBrainrots")
			while state.equipEnabled do
				SafeFire(remote)
				local i = state.equipInterval or Config.defaultEquipInterval
				wait(i)
			end
		end)
	end
end)

buyToggle.MouseButton1Click:Connect(function()
	state.buyEnabled = not state.buyEnabled
	buyToggle.Text = state.buyEnabled and "Stop Auto-Buy" or "Start Auto-Buy"
	buyToggle.BackgroundColor3 = state.buyEnabled and Color3.fromRGB(70,140,70) or Color3.fromRGB(60,60,60)

	if state.buyEnabled then
		spawn(function()
			local buyRemote = RemotesFolder:WaitForChild("BuyItem")
			while state.buyEnabled do
				-- iterate selected plants and attempt buy
				for itemName, _ in pairs(state.selectedPlants) do
					SafeFire(buyRemote, itemName, true)
					wait(Config.buyDelayBetweenItems)
				end
				-- small cycle delay to avoid tight loop (essential for stability)
				wait(Config.cycleDelay)
			end
		end)
	end
end)

gearBuyToggle.MouseButton1Click:Connect(function()
	state.gearBuyEnabled = not state.gearBuyEnabled
	gearBuyToggle.Text = state.gearBuyEnabled and "Stop Auto-Buy" or "Start Auto-Buy"
	gearBuyToggle.BackgroundColor3 = state.gearBuyEnabled and Color3.fromRGB(70,140,70) or Color3.fromRGB(60,60,60)

	if state.gearBuyEnabled then
		spawn(function()
			local buyRemote = RemotesFolder:WaitForChild("BuyGear")
			while state.gearBuyEnabled do
				for itemName, _ in pairs(state.selectedGear) do
					SafeFire(buyRemote, itemName, true)
					wait(Config.buyDelayBetweenItems)
				end
				wait(Config.cycleDelay)
			end
		end)
	end
end)

-- run: ensure open button hidden when main UI visible
openButton.Enabled = false

-- expose quick console controls
getgenv().PlantBot = {
	state = state,
	toggleEquip = function(val) state.equipEnabled = val end,
	toggleBuy = function(val) state.buyEnabled = val end,
	toggleGearBuy = function(val) state.gearBuyEnabled = val end,
	performEquip = function() SafeFire(RemotesFolder:WaitForChild("EquipBestBrainrots")) end,
	performBuy = function()
		local buyRemote = RemotesFolder:WaitForChild("BuyItem")
		for itemName, _ in pairs(state.selectedPlants) do
			SafeFire(buyRemote, itemName, true)
		end
	end,
	performGearBuy = function()
		local buyRemote = RemotesFolder:WaitForChild("BuyGear")
		for itemName, _ in pairs(state.selectedGear) do
			SafeFire(buyRemote, itemName, true)
		end
	end,
}
