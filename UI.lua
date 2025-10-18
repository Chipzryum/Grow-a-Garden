local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
	Name = "Plants vs Brainrots Bot UI",
	LoadingTitle = "Loading...",
	LoadingSubtitle = "by Grok",
	ConfigurationSaving = {
		Enabled = false,
		FolderName = nil,
		FileName = "PvB Bot"
	}
})
local AutomationTab = Window:CreateTab("Automation")
local EquipToggle = AutomationTab:CreateToggle({
	Name = "Enable Equip Best Brainrots",
	CurrentValue = false,
	Flag = "equip_toggle",
	Callback = function(Value)
		if Value then
			startEquipLoop()
		else
			stopEquipLoop()
		end
	end,
})

local TimeInput = AutomationTab:CreateInput({
	Name = "Equip Interval (seconds)",
	PlaceholderText = "60",
	RemoveTextAfterFocusLost = false,
	Flag = "time_input", -- added flag so the toggle loop can read it
	Callback = function(Text)
		-- The time is read in the loop
	end,
})
AutomationTab:CreateParagraph({Title = "Auto Buy Settings", Content = "Buys selected plants every 5 minutes if in stock."})
local AutoBuyToggle = AutomationTab:CreateToggle({
	Name = "Enable Auto Buy",
	CurrentValue = false,
	Flag = "autobuy_toggle",
	Callback = function(Value)
		if Value then
			startBuyLoop()
		else
			stopBuyLoop()
		end
	end,
})

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

-- runtime threads/state
local equipThread = nil
local buyThread = nil

local function SafeFire(remote, ...)
	pcall(function() remote:FireServer(...) end)
end

local function performEquipOnce()
	local ok, equipRemote = pcall(function() return remotesFolder:WaitForChild("EquipBestBrainrots") end)
	if ok and equipRemote then
		SafeFire(equipRemote)
	end
end

local function startEquipLoop()
	if equipThread then return end
	local ok, equipRemote = pcall(function() return remotesFolder:WaitForChild("EquipBestBrainrots") end)
	equipThread = spawn(function()
		if not (ok and equipRemote) then
			-- try to fetch later
			equipRemote = remotesFolder:WaitForChild("EquipBestBrainrots")
		end
		while Rayfield.Flags.equip_toggle do
			local time = tonumber(Rayfield.Flags.time_input) or 60
			SafeFire(equipRemote)
			wait(time)
		end
		equipThread = nil
	end)
end

local function stopEquipLoop()
	Rayfield.Flags.equip_toggle = false
	-- the loop checks Rayfield.Flags and will stop; equipThread cleared in loop
end

local function performBuyOnce()
	local ok, buyRemote = pcall(function() return remotesFolder:WaitForChild("BuyItem") end)
	if not ok or not buyRemote then
		buyRemote = remotesFolder:WaitForChild("BuyItem")
	end
	local selected = Rayfield.Flags.plants_dropdown
	local toBuy = {}
	if type(selected) == "table" then
		toBuy = selected
	elseif type(selected) == "string" and selected ~= "" then
		toBuy = { selected }
	end
	for _, plant in ipairs(toBuy) do
		local itemName = plant .. " Seed"
		SafeFire(buyRemote, itemName, true)
		wait(0.4)
	end
end

local function startBuyLoop()
	if buyThread then return end
	local ok, buyRemote = pcall(function() return remotesFolder:WaitForChild("BuyItem") end)
	buyThread = spawn(function()
		if not (ok and buyRemote) then
			buyRemote = remotesFolder:WaitForChild("BuyItem")
		end
		while Rayfield.Flags.autobuy_toggle do
			performBuyOnce()
			wait(tonumber(Rayfield.Flags.buy_interval) or 300)
		end
		buyThread = nil
	end)
end

local function stopBuyLoop()
	Rayfield.Flags.autobuy_toggle = false
end

-- Save button
AutomationTab:CreateButton({
	Name = "Save & Apply Settings",
	Callback = function()
		-- persist (if writefile available)
		local ok, err = pcall(function()
			if writefile and type(writefile) == "function" then
				local data = HttpService:JSONEncode(Rayfield.Flags or {})
				writefile("PvB_Bot_Config.json", data)
			end
		end)
		-- perform immediate actions
		performEquipOnce()
		performBuyOnce()
		-- start loops if toggles enabled
		if Rayfield.Flags.equip_toggle then
			startEquipLoop()
		end
		if Rayfield.Flags.autobuy_toggle then
			startBuyLoop()
		end
	end
})

local plants = {
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
	"King Limone"
}
local PlantsDropdown = AutomationTab:CreateDropdown({
	Name = "Plants to Buy",
	Options = plants,
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "plants_dropdown",
	Callback = function(Option)
		-- Selected options are in Flag
	end,
})