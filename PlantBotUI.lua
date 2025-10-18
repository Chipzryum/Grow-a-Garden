-- Standalone executor-friendly UI with tabs: Main (Equip / Autobuy) and Shop (Seeds / Gear)

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

-- config
local Config = {
	defaultEquipInterval = 10,
	buyDelayBetweenItems = 0.5,
	cycleDelay = 60.0,           -- 60 seconds between auto-buy cycles (per request)
}

local Plants = {
	"Cactus","Strawberry","Pumpkin","Sunflower","Dragon Fruit","Eggplant",
	"Watermelon","Grape","Cocotank","Carnivorous Plant","Mr Carrot",
	"Tomatrio","Shroombino","Mango","King Limone",
}

local GearItems = {
	"Water Bucket","Frost Grenade","Banana Gun","Frost Blaster","Carrot Launcher",
}

-- runtime state
local state = {
	equipEnabled = false,
	equipInterval = Config.defaultEquipInterval,
	autobuySeedsEnabled = false,
	autobuyGearEnabled = false,
	selectedSeeds = {}, -- set of item names (e.g., "Sunflower Seed")
	selectedGear = {},
	uiVisible = true,
}

-- helper: safe remote call
local function SafeFire(remote, ...)
	local args = {...}
	pcall(function() remote:FireServer(table.unpack(args)) end)
end

local function ItemNameFor(display) return display .. " Seed" end
local function GearNameFor(display) return display end

-- cleanup previous UI instances
for _, child in ipairs(PlayerGui:GetChildren()) do
	if child.Name == "PlantBotUI" or child.Name == "PlantBot_OpenButton" then
		child:Destroy()
	end
end

-- small "Open UI" button
local openButton = Instance.new("ScreenGui")
openButton.Name = "PlantBot_OpenButton"
openButton.ResetOnSpawn = false
openButton.Parent = PlayerGui

local openFrame = Instance.new("TextButton")
openFrame.Name = "OpenBtn"
openFrame.Size = UDim2.new(0, 130, 0, 36)
openFrame.Position = UDim2.new(1, -140, 1, -90)
openFrame.Text = "Open PlantBot"
openFrame.BackgroundColor3 = Color3.fromRGB(45,45,45)
openFrame.TextColor3 = Color3.fromRGB(230,230,230)
openFrame.Font = Enum.Font.SourceSansSemibold
openFrame.TextSize = 14
openFrame.Parent = openButton
Instance.new("UICorner", openFrame).CornerRadius = UDim.new(0,6)

openFrame.MouseButton1Click:Connect(function()
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
frame.Size = UDim2.new(0, 520, 0, 460)
frame.Position = UDim2.new(0.5, -260, 0.5, -230)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(28,28,30)
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
local stroke = Instance.new("UIStroke", frame); stroke.Color = Color3.fromRGB(60,60,60); stroke.Thickness = 1

-- title and tab buttons
local title = Instance.new("TextLabel", frame)
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -16, 0, 36)
title.Position = UDim2.new(0, 8, 0, 8)
title.Text = "PlantBot — Automation"
title.TextColor3 = Color3.fromRGB(235,235,235)
title.Font = Enum.Font.SourceSansSemibold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.new(0,28,0,28); closeBtn.Position = UDim2.new(1, -40, 0, 8)
closeBtn.Text = "✕"; closeBtn.Font = Enum.Font.SourceSansBold; closeBtn.TextSize = 16
closeBtn.BackgroundColor3 = Color3.fromRGB(55,55,55); closeBtn.TextColor3 = Color3.fromRGB(230,230,230)
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

local minimizeBtn = Instance.new("TextButton", frame)
minimizeBtn.Size = UDim2.new(0,28,0,28); minimizeBtn.Position = UDim2.new(1, -80, 0, 8)
minimizeBtn.Text = "—"; minimizeBtn.Font = Enum.Font.SourceSansBold; minimizeBtn.TextSize = 18
minimizeBtn.BackgroundColor3 = Color3.fromRGB(55,55,55); minimizeBtn.TextColor3 = Color3.fromRGB(230,230,230)
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0,6)

-- Tab buttons
local tabsFrame = Instance.new("Frame", frame)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Position = UDim2.new(0,8,0,48)
tabsFrame.Size = UDim2.new(1, -16, 0, 34)

local mainTabBtn = Instance.new("TextButton", tabsFrame)
mainTabBtn.Text = "Main"; mainTabBtn.Size = UDim2.new(0,100,1,0); mainTabBtn.Position = UDim2.new(0,0,0,0)
mainTabBtn.BackgroundColor3 = Color3.fromRGB(70,70,70); mainTabBtn.TextColor3 = Color3.fromRGB(235,235,235)
Instance.new("UICorner", mainTabBtn).CornerRadius = UDim.new(0,6)

local shopTabBtn = Instance.new("TextButton", tabsFrame)
shopTabBtn.Text = "Shop"; shopTabBtn.Size = UDim2.new(0,100,1,0); shopTabBtn.Position = UDim2.new(0,108,0,0)
shopTabBtn.BackgroundColor3 = Color3.fromRGB(50,50,50); shopTabBtn.TextColor3 = Color3.fromRGB(200,200,200)
Instance.new("UICorner", shopTabBtn).CornerRadius = UDim.new(0,6)

-- content area
local content = Instance.new("Frame", frame)
content.BackgroundTransparency = 1
content.Position = UDim2.new(0,8,0,92)
content.Size = UDim2.new(1, -16, 1, -100)

-- Main tab frame
local mainFrame = Instance.new("Frame", content)
mainFrame.Size = UDim2.new(1,0,1,0); mainFrame.BackgroundTransparency = 1

-- Shop tab frame
local shopFrame = Instance.new("Frame", content)
shopFrame.Size = UDim2.new(1,0,1,0); shopFrame.BackgroundTransparency = 1
shopFrame.Visible = false

-- --- Main UI contents: Equip and (no main autobuy) ---
-- Equip section
local equipSection = Instance.new("Frame", mainFrame)
equipSection.Size = UDim2.new(1,0,0,90); equipSection.Position = UDim2.new(0,0,0,0); equipSection.BackgroundTransparency = 1

local equipLabel = Instance.new("TextLabel", equipSection)
equipLabel.Text = "Equip Best Brainrots"; equipLabel.Size = UDim2.new(1,0,0,20); equipLabel.BackgroundTransparency = 1
equipLabel.Position = UDim2.new(0,0,0,0); equipLabel.TextColor3 = Color3.fromRGB(220,220,220); equipLabel.Font = Enum.Font.SourceSans; equipLabel.TextSize = 14

local equipToggle = Instance.new("TextButton", equipSection)
equipToggle.Name = "EquipToggle"; equipToggle.Size = UDim2.new(0,120,0,32); equipToggle.Position = UDim2.new(0,0,0,26)
equipToggle.Text = "Enable"; equipToggle.Font = Enum.Font.SourceSans; equipToggle.TextSize = 14
equipToggle.BackgroundColor3 = Color3.fromRGB(60,60,60); equipToggle.TextColor3 = Color3.fromRGB(235,235,235)
Instance.new("UICorner", equipToggle).CornerRadius = UDim.new(0,6)

local equipIntervalBox = Instance.new("TextBox", equipSection)
equipIntervalBox.Name = "EquipInterval"; equipIntervalBox.PlaceholderText = tostring(Config.defaultEquipInterval)
equipIntervalBox.Text = ""; equipIntervalBox.Size = UDim2.new(0,120,0,32); equipIntervalBox.Position = UDim2.new(0,140,0,26)
equipIntervalBox.ClearTextOnFocus = false; equipIntervalBox.BackgroundColor3 = Color3.fromRGB(45,45,45); equipIntervalBox.TextColor3 = Color3.fromRGB(235,235,235)
equipIntervalBox.Font = Enum.Font.SourceSans; equipIntervalBox.TextSize = 14
Instance.new("UICorner", equipIntervalBox).CornerRadius = UDim.new(0,6)

local equipHint = Instance.new("TextLabel", equipSection)
equipHint.Text = "interval (seconds)"; equipHint.BackgroundTransparency = 1; equipHint.Position = UDim2.new(0,280,0,28)
equipHint.Size = UDim2.new(0,180,0,24); equipHint.TextColor3 = Color3.fromRGB(170,170,170); equipHint.Font = Enum.Font.SourceSans; equipHint.TextSize = 12

-- --- Shop tab contents: Seeds and Gear ---
local shopSeedsSection = Instance.new("Frame", shopFrame)
shopSeedsSection.Size = UDim2.new(0.5, -6, 1, 0); shopSeedsSection.Position = UDim2.new(0,0,0,0); shopSeedsSection.BackgroundTransparency = 1

local seedsLabel = Instance.new("TextLabel", shopSeedsSection)
seedsLabel.Text = "Seed Shop"; seedsLabel.BackgroundTransparency = 1; seedsLabel.Position = UDim2.new(0,0,0,0)
seedsLabel.Size = UDim2.new(1,0,0,20); seedsLabel.TextColor3 = Color3.fromRGB(220,220,220); seedsLabel.Font = Enum.Font.SourceSans; seedsLabel.TextSize = 14

local seedsScroll = Instance.new("ScrollingFrame", shopSeedsSection)
seedsScroll.Position = UDim2.new(0,0,0,26); seedsScroll.Size = UDim2.new(1,0,0,330); seedsScroll.CanvasSize = UDim2.new(0,0,0,#Plants * 34)
seedsScroll.BackgroundTransparency = 1; seedsScroll.ScrollBarImageTransparency = 0.7
local seedsList = Instance.new("UIListLayout", seedsScroll); seedsList.Padding = UDim.new(0,6)

local autoSeedsToggleBtn = Instance.new("TextButton", shopSeedsSection)
autoSeedsToggleBtn.Text = "AutoBuy Selected Seeds (1/min)"; autoSeedsToggleBtn.Size = UDim2.new(0,230,0,34); autoSeedsToggleBtn.Position = UDim2.new(0,0,1,-40)
autoSeedsToggleBtn.BackgroundColor3 = Color3.fromRGB(70,70,70); autoSeedsToggleBtn.TextColor3 = Color3.fromRGB(235,235,235)
Instance.new("UICorner", autoSeedsToggleBtn).CornerRadius = UDim.new(0,6)

local shopGearSection = Instance.new("Frame", shopFrame)
shopGearSection.Size = UDim2.new(0.5, -6, 1, 0); shopGearSection.Position = UDim2.new(0.5, 12, 0, 0); shopGearSection.BackgroundTransparency = 1

local gearLabel = Instance.new("TextLabel", shopGearSection)
gearLabel.Text = "Gear Store"; gearLabel.BackgroundTransparency = 1; gearLabel.Position = UDim2.new(0,0,0,0)
gearLabel.Size = UDim2.new(1,0,0,20); gearLabel.TextColor3 = Color3.fromRGB(220,220,220); gearLabel.Font = Enum.Font.SourceSans; gearLabel.TextSize = 14

local gearScroll = Instance.new("ScrollingFrame", shopGearSection)
gearScroll.Position = UDim2.new(0,0,0,26); gearScroll.Size = UDim2.new(1,0,0,330); gearScroll.CanvasSize = UDim2.new(0,0,0,#GearItems * 34)
gearScroll.BackgroundTransparency = 1; gearScroll.ScrollBarImageTransparency = 0.7
local gearList = Instance.new("UIListLayout", gearScroll); gearList.Padding = UDim.new(0,6)

local autoGearToggleBtn = Instance.new("TextButton", shopGearSection)
autoGearToggleBtn.Text = "AutoBuy Selected Gear (1/min)"; autoGearToggleBtn.Size = UDim2.new(0,230,0,34); autoGearToggleBtn.Position = UDim2.new(0,0,1,-40)
autoGearToggleBtn.BackgroundColor3 = Color3.fromRGB(70,70,70); autoGearToggleBtn.TextColor3 = Color3.fromRGB(235,235,235)
Instance.new("UICorner", autoGearToggleBtn).CornerRadius = UDim.new(0,6)

-- create seed buttons
for i, name in ipairs(Plants) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 28)
	btn.Position = UDim2.new(0, 4, 0, (i-1) * 34)
	btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
	btn.TextColor3 = Color3.fromRGB(235,235,235)
	btn.Font = Enum.Font.SourceSans
	btn.TextSize = 14
	btn.Text = name
	btn.Parent = seedsScroll
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

	btn.MouseButton1Click:Connect(function()
		local item = ItemNameFor(name)
		if state.selectedSeeds[item] then
			state.selectedSeeds[item] = nil
			btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
		else
			state.selectedSeeds[item] = true
			btn.BackgroundColor3 = Color3.fromRGB(65,125,65)
		end
	end)
end

-- create gear buttons
for i, name in ipairs(GearItems) do
	local btn = Instance.new("TextButton")
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
		local item = GearNameFor(name)
		if state.selectedGear[item] then
			state.selectedGear[item] = nil
			btn.BackgroundColor3 = Color3.fromRGB(48,48,48)
		else
			state.selectedGear[item] = true
			btn.BackgroundColor3 = Color3.fromRGB(65,125,65)
		end
	end)
end

-- Utils: numeric-only enforcement and deactivating equip toggle on change
local function enforceNumeric(textbox, onChangeDisableToggle)
	textbox:GetPropertyChangedSignal("Text"):Connect(function()
		local filtered = textbox.Text:gsub("%D", "")
		if textbox.Text ~= filtered then
			textbox.Text = filtered
		end
		if onChangeDisableToggle then onChangeDisableToggle() end
	end)
	textbox.FocusLost:Connect(function()
		local v = tonumber(textbox.Text)
		if not v or v <= 0 then textbox.Text = "" end
	end)
end

local function disableEquipToggle() 
	if state.equipEnabled then
		state.equipEnabled = false
		equipToggle.Text = "Enable"
		equipToggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
	end
end

enforceNumeric(equipIntervalBox, disableEquipToggle)

-- Dragging logic for main frame
local dragging = false
local dragStart, startPos
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true; dragStart = input.Position; startPos = frame.Position
		input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Tab switching
mainTabBtn.MouseButton1Click:Connect(function()
	mainTabBtn.BackgroundColor3 = Color3.fromRGB(70,70,70); shopTabBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
	mainFrame.Visible = true; shopFrame.Visible = false
end)
shopTabBtn.MouseButton1Click:Connect(function()
	shopTabBtn.BackgroundColor3 = Color3.fromRGB(70,70,70); mainTabBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
	mainFrame.Visible = false; shopFrame.Visible = true
end)

-- Buttons behaviors
closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false; openButton.Enabled = true
end)
minimizeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false; openButton.Enabled = true
end)

-- Equip toggle behavior
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

-- Auto-buy Seeds toggle behavior: buys one of each selected seed every 60 seconds
autoSeedsToggleBtn.MouseButton1Click:Connect(function()
	state.autobuySeedsEnabled = not state.autobuySeedsEnabled
	autoSeedsToggleBtn.Text = state.autobuySeedsEnabled and "Stop AutoBuy Seeds" or "AutoBuy Selected Seeds (1/min)"
	autoSeedsToggleBtn.BackgroundColor3 = state.autobuySeedsEnabled and Color3.fromRGB(70,140,70) or Color3.fromRGB(70,70,70)

	if state.autobuySeedsEnabled then
		spawn(function()
			local buyRemote = RemotesFolder:WaitForChild("BuyItem")
			while state.autobuySeedsEnabled do
				for itemName, _ in pairs(state.selectedSeeds) do
					SafeFire(buyRemote, itemName, true)
					wait(Config.buyDelayBetweenItems)
				end
				wait(Config.cycleDelay)
			end
		end)
	end
end)

-- Auto-buy Gear toggle behavior: buys one of each selected gear every 60 seconds
autoGearToggleBtn.MouseButton1Click:Connect(function()
	state.autobuyGearEnabled = not state.autobuyGearEnabled
	autoGearToggleBtn.Text = state.autobuyGearEnabled and "Stop AutoBuy Gear" or "AutoBuy Selected Gear (1/min)"
	autoGearToggleBtn.BackgroundColor3 = state.autobuyGearEnabled and Color3.fromRGB(70,140,70) or Color3.fromRGB(70,70,70)

	if state.autobuyGearEnabled then
		spawn(function()
			local buyGearRemote = RemotesFolder:WaitForChild("BuyGear")
			while state.autobuyGearEnabled do
				for gearName, _ in pairs(state.selectedGear) do
					SafeFire(buyGearRemote, gearName, true)
					wait(Config.buyDelayBetweenItems)
				end
				wait(Config.cycleDelay)
			end
		end)
	end
end)

-- run: hide open button while UI visible
openButton.Enabled = false

-- expose quick console controls
getgenv().PlantBot = {
	state = state,
	toggleEquip = function(val) state.equipEnabled = val end,
	toggleAutobuySeeds = function(val) state.autobuySeedsEnabled = val end,
	toggleAutobuyGear = function(val) state.autobuyGearEnabled = val end,
	performEquip = function() SafeFire(RemotesFolder:WaitForChild("EquipBestBrainrots")) end,
	performBuyOnce = function()
		local buyRemote = RemotesFolder:WaitForChild("BuyItem")
		local buyGearRemote = RemotesFolder:WaitForChild("BuyGear")
		for itemName,_ in pairs(state.selectedSeeds) do SafeFire(buyRemote, itemName, true); wait(0.05) end
		for gearName,_ in pairs(state.selectedGear) do SafeFire(buyGearRemote, gearName, true); wait(0.05) end
	end,
}
