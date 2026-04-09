
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer

local success, err = pcall(function()
    assert(getgc, "executor missing required function getgc")
    assert(debug and debug.info, "executor missing required function debug.info (somehow)")
    assert(hookfunction, "executor missing required function hookfunction")
    assert(getconnections, "executor missing required function getconnections")
    assert(newcclosure, "executor missing required function newcclosure")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LogService = game:GetService("LogService")
    local ScriptContext = game:GetService("ScriptContext")
    task.spawn(function()
        for _, v in pairs(getgc(true)) do
            if typeof(v) == "function" then
                local ok, src = pcall(function()
                    return debug.info(v, "s")
                end)
                if ok and type(src) == "string" and string.find(src, "AnalyticsPipelineController") then
                    local oldfn
                    oldfn = hookfunction(v, newcclosure(function(...)
                        return wait(9e9)
                    end))
                end
            end
        end
    end)
    task.spawn(function()
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AnalyticsPipeline"):WaitForChild("RemoteEvent")
        end)
        if ok and remote and remote.OnClientEvent then
            for _, conn in pairs(getconnections(remote.OnClientEvent)) do
                if conn and conn.Function then
                    pcall(function()
                        hookfunction(conn.Function, newcclosure(function(...)
                        end))
                    end)
                end
            end
        end
    end)
    task.spawn(function()
        for _, conn in pairs(getconnections(LogService.MessageOut)) do
            if conn and conn.Function then
                pcall(function()
                    hookfunction(conn.Function, newcclosure(function(...)
                    end))
                end)
            end
        end
    end)
    task.spawn(function()
        for _, conn in ipairs(getconnections(ScriptContext.Error)) do
            pcall(function()
                conn:Disable()
            end)
        end
        pcall(function()
            hookfunction(ScriptContext.Error.Connect, newcclosure(function(...)
                return nil
            end))
        end)
    end)
    task.spawn(function()
        local KickNames = {
            "Kick",
            "kick"
        }
        for _, name in ipairs(KickNames) do
            local fn = LocalPlayer[name]
            if type(fn) == "function" then
                local oldkick
                oldkick = hookfunction(fn, newcclosure(function(self, ...)
                    if self == LocalPlayer then
                        return
                    end
                    return oldkick(self, ...)
                end))
            end
        end
    end)
end)
if not success then
    warn("Rivals Anticheat Disabler failed: " .. tostring(err))
    Players.LocalPlayer:Kick("Couldn't bypass anticheat")
end
local oldtable; oldtable = hookfunction(getrenv().setmetatable, newcclosure(function(Table, Metatable)
if Metatable and typeof(Metatable) == "table" and rawget(Metatable, "__mode") == "kv" then
local trace = debug.traceback()
if trace:find("MiscellaneousController") then
return oldtable({1, 2, 3}, {})
end
end
return oldtable(Table, Metatable)
end))
-- §01 SERVICES & ROBLOX APIS -------------------------------------------------
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local function TryRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

-- §02 GAME MODULES (Rivals / shared libs) ------------------------------------
-- required modules for the skin changers
local ItemLib = TryRequire(ReplicatedStorage:FindFirstChild("Modules") and
                         ReplicatedStorage.Modules:FindFirstChild("ItemLibrary"))
local CosmeticLib = TryRequire(ReplicatedStorage:FindFirstChild("Modules") and
                            ReplicatedStorage.Modules:FindFirstChild("CosmeticLibrary"))
local AnimLib = TryRequire(ReplicatedStorage:FindFirstChild("Modules") and
                        ReplicatedStorage.Modules:FindFirstChild("AnimationLibrary"))
local EnumLib = TryRequire(ReplicatedStorage:FindFirstChild("Modules") and
                        ReplicatedStorage.Modules:FindFirstChild("EnumLibrary"))
local Constants = TryRequire(ReplicatedStorage:FindFirstChild("Modules") and
                          ReplicatedStorage.Modules:FindFirstChild("CONSTANTS"))

local PlayerScripts = player:WaitForChild("PlayerScripts")
local Controllers   = PlayerScripts:WaitForChild("Controllers")
local PlayerDataController = TryRequire(Controllers:FindFirstChild("PlayerDataController"))
-- controllers
repeat task.wait() until (not PlayerDataController) or PlayerDataController.CurrentData
local CurrentData = PlayerDataController and PlayerDataController.CurrentData

-- §03 CONFIG & TAGS ----------------------------------------------------------
local Config = {}

local SkinAppliedTag = "abv"

local function SaveConfig() end

local function CloneCosmetic(name, cosmeticType)
    if not name or name:lower() == "none" then return nil end
    if not CosmeticLib or not CosmeticLib.Cosmetics then return nil end
    local data = CosmeticLib.Cosmetics[name]
    if not data then return nil end
    local clone = {}
    for k, v in pairs(data) do clone[k] = v end
    clone.Name = name
    clone.Type = cosmeticType
    clone.Seed = math.random(1, 1000000)
    pcall(function()
        if EnumLib then
            local enum = EnumLib:ToEnum(name)
            if enum then clone.Enum = enum; clone.ObjectID = enum end
        end
    end)
    return clone
end

-- §04 COSMETIC DOMAIN — inventory item + viewmodel wiring --------------------
local function WeaponData(weaponName)
    if not CurrentData then return end
    local inventory = CurrentData:Get("WeaponInventory")
    if not inventory then return end
    for _, item in pairs(inventory) do
        if item.Name == weaponName then
            local cfg = Config[weaponName]
            if cfg then
                item.Skin    = cfg.Skin
                item.Wrap    = cfg.Wrap
                item.Charm   = cfg.Charm
                item.Finisher = cfg.Finisher
            end
            return item
        end
    end
end

--[[ Skins were lagging because only _ViewModel was touched; wraps use item.ViewModel + rawset + ClientFighter:Set (see ForceWrap). ]]
local function applyCosmeticsToClientItem(item)
    if not item or type(item) ~= "table" then return end
    local weaponName = item.Name
    if type(weaponName) ~= "string" or not Config[weaponName] then return end
    local cfg = Config[weaponName]
    pcall(function()
        if cfg.Skin    then item:Set("Skin",     cfg.Skin)    end
        if cfg.Wrap    then item:Set("Wrap",     cfg.Wrap)    end
        if cfg.Charm   then item:Set("Charm",    cfg.Charm)   end
        if cfg.Finisher then item:Set("Finisher", cfg.Finisher) end
        if cfg.Skin then
            pcall(function() rawset(item, "_skin", cfg.Skin) end)
            if item.ClientFighter and item.ClientFighter.Set then
                pcall(item.ClientFighter.Set, item.ClientFighter, "Skin", cfg.Skin)
            end
        end
        local vms = { rawget(item, "_ViewModel"), rawget(item, "ViewModel") }
        for _, vm in ipairs(vms) do
            if vm then
                if cfg.Skin then
                    if vm.Set then pcall(vm.Set, vm, "Skin", cfg.Skin) end
                    if vm.SetSkin then pcall(vm.SetSkin, vm, cfg.Skin) end
                    pcall(function() rawset(vm, "_skin", cfg.Skin) end)
                    if vm._UpdateSkin then pcall(vm._UpdateSkin, vm)
                    elseif vm.UpdateSkin then pcall(vm.UpdateSkin, vm) end
                end
                if cfg.Wrap then
                    if vm.SetWrap then pcall(vm.SetWrap, vm, cfg.Wrap) end
                    if vm._UpdateWrap then pcall(vm._UpdateWrap, vm)
                    elseif vm.UpdateWrap then pcall(vm.UpdateWrap, vm) end
                end
                if cfg.Charm then
                    if vm.SetCharm then pcall(vm.SetCharm, vm, cfg.Charm) end
                    if vm._UpdateCharm then pcall(vm._UpdateCharm, vm)
                    elseif vm.UpdateCharm then pcall(vm.UpdateCharm, vm) end
                end
            end
        end
    end)
end

--[[ Items + Inventory slots + EquippedItem — same surfaces as WrapAll so the held gun updates without re-equipping. ]]
local function collectFighterClientItems(fighter)
    local list = {}
    local seen = {}
    local function add(item)
        if item and type(item) == "table" and not seen[item] then
            seen[item] = true
            table.insert(list, item)
        end
    end
    if fighter.Items then
        for _, it in pairs(fighter.Items) do
            add(it)
        end
    end
    local inv = nil
    if fighter.Get then
        local ok, i = pcall(fighter.Get, fighter, "Inventory")
        if ok then inv = i end
    end
    if not inv and rawget(fighter, "Inventory") then
        inv = fighter.Inventory
    end
    if inv then
        for i = 1, 10 do
            local slotItem = nil
            if inv.Get then
                local ok, sl = pcall(inv.Get, inv, i)
                if ok then slotItem = sl end
            elseif inv[i] then
                slotItem = inv[i]
            end
            add(slotItem)
        end
    end
    local eq = rawget(fighter, "EquippedItem")
    if eq == nil and fighter.Get then
        local ok, res = pcall(fighter.Get, fighter, "EquippedItem")
        if ok then eq = res end
    end
    add(eq)
    return list
end

local function clearForcedSkinCachesForWeapon(weaponName)
    if type(weaponName) ~= "string" then return end
    local ok, FighterController = pcall(function()
        return require(Controllers:WaitForChild("FighterController", 10))
    end)
    if not ok or not FighterController then return end
    local fighter = FighterController:GetFighter(player)
    if not fighter then return end
    for _, item in ipairs(collectFighterClientItems(fighter)) do
        if item.Name == weaponName then
            pcall(function() rawset(item, "_skin", nil) end)
            for _, vm in ipairs({ rawget(item, "_ViewModel"), rawget(item, "ViewModel") }) do
                if vm then pcall(function() rawset(vm, "_skin", nil) end) end
            end
        end
    end
end

local function ActiveWeapon()
    local ok, FighterController = pcall(function()
        return require(Controllers:WaitForChild("FighterController", 10))
    end)
    if not ok or not FighterController then return end
    local fighter = FighterController:GetFighter(player)
    if not fighter then return end
    for _, item in ipairs(collectFighterClientItems(fighter)) do
        applyCosmeticsToClientItem(item)
    end
end

pcall(function()
    local ClientItem = require(PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
    local OldCreate = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName  = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        if weaponPlayer == player and Config[weaponName] and Config[weaponName].Skin then
            local cfg = Config[weaponName]
            pcall(function()
                if viewmodelRef and viewmodelRef.Data then
                    viewmodelRef.Data.Skin = cfg.Skin
                    viewmodelRef.Data.Name = cfg.Skin.Name
                else
                    local RC = require(ReplicatedStorage.Modules.ReplicatedClass)
                    local dk = RC:ToEnum("Data")
                    local sk = RC:ToEnum("Skin")
                    local nk = RC:ToEnum("Name")
                    if viewmodelRef and viewmodelRef[dk] then
                        viewmodelRef[dk][sk] = cfg.Skin
                        viewmodelRef[dk][nk] = cfg.Skin.Name
                    end
                end
            end)
        end
        return OldCreate(self, viewmodelRef)
    end
end)

pcall(function()
    local vmModule = PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
    if not vmModule then return end
    local ClientViewModel = require(vmModule)

    local OldWrap = ClientViewModel.GetWrap
    ClientViewModel.GetWrap = function(self)
        local item = self.ClientItem
        if not item then return OldWrap(self) end
        local wName   = item.Name
        local wPlayer = item.ClientFighter and item.ClientFighter.Player
        if wPlayer == player and Config[wName] and Config[wName].Wrap then
            return Config[wName].Wrap
        end
        return OldWrap(self)
    end

    if type(ClientViewModel.GetSkin) == "function" then
        local OldGetSkin = ClientViewModel.GetSkin
        ClientViewModel.GetSkin = function(self)
            local item = self.ClientItem
            if not item then return OldGetSkin(self) end
            local wName = item.Name
            local wPlayer = item.ClientFighter and item.ClientFighter.Player
            if wPlayer == player and Config[wName] and Config[wName].Skin then
                return Config[wName].Skin
            end
            return OldGetSkin(self)
        end
    end

    local OldNew = ClientViewModel.new
    ClientViewModel.new = function(repData, clientItem)
        if not clientItem then return OldNew(repData, clientItem) end
        local wPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
        local wName   = clientItem.Name
        if wPlayer == player and Config[wName] then
            pcall(function()
                local RC = require(ReplicatedStorage.Modules.ReplicatedClass)
                local dk = RC:ToEnum("Data")
                repData[dk] = repData[dk] or {}
                local c = Config[wName]
                if c.Skin    then repData[dk][RC:ToEnum("Skin")]    = c.Skin    end
                if c.Wrap    then repData[dk][RC:ToEnum("Wrap")]    = c.Wrap    end
                if c.Charm   then repData[dk][RC:ToEnum("Charm")]   = c.Charm   end
            end)
        end
        local result = OldNew(repData, clientItem)
        if result and wPlayer == player and Config[wName] then
            local c = Config[wName]
            pcall(function()
                if c.Wrap and result._UpdateWrap then result:_UpdateWrap() end
                if c.Skin and result._UpdateSkin then result:_UpdateSkin() end
            end)
        end
        return result
    end
end)

local function EquipCosmetic(weaponName, cosmeticName, cosmeticTypeProper)
    if cosmeticName:lower() == "none" then
        if Config[weaponName] then
            Config[weaponName][cosmeticTypeProper] = nil
            if not next(Config[weaponName]) then Config[weaponName] = nil end
            WeaponData(weaponName)
            ActiveWeapon()
            SaveConfig()
            pcall(function() CurrentData:Replicate("WeaponInventory") end)
            if cosmeticTypeProper == "Skin" then
                clearForcedSkinCachesForWeapon(weaponName)
                pcall(EquipSkinInGame, weaponName, nil)
                pcall(function()
                    local char = player.Character
                    if char then
                        local wf = char:FindFirstChild("Weapons")
                        if wf then
                            local wm = wf:FindFirstChild(weaponName)
                            if wm then
                                local t = wm:FindFirstChild(SkinAppliedTag)
                                if t then t:Destroy() end
                            end
                        end
                    end
                end)
            end
            task.defer(ActiveWeapon)
        end
        return
    end
    local cloned = CloneCosmetic(cosmeticName, cosmeticTypeProper)
    if not cloned then return end
    if not Config[weaponName] then Config[weaponName] = {} end
    Config[weaponName][cosmeticTypeProper] = cloned
    WeaponData(weaponName)
    ActiveWeapon()
    SaveConfig()
    pcall(function() CurrentData:Replicate("WeaponInventory") end)
    if cosmeticTypeProper == "Skin" then
        pcall(EquipSkinInGame, weaponName, cosmeticName)
        pcall(function()
            local char = player.Character
            if char then
                local wf = char:FindFirstChild("Weapons")
                if wf then
                    local wm = wf:FindFirstChild(weaponName)
                    if wm then
                        local t = wm:FindFirstChild(SkinAppliedTag)
                        if t then t:Destroy() end
                    end
                end
            end
        end)
        pcall(function()
            if ViewModels then
                for _, vm in pairs(ViewModels:GetDescendants()) do
                    if vm:IsA("Model") and vm.Name == weaponName then
                        local t = vm:FindFirstChild(SkinAppliedTag)
                        if t then t:Destroy() end
                    end
                end
            end
        end)
    end
    task.defer(ActiveWeapon)
end

local function WaitAssets(timeout)
    local startTime = tick()
    local assets, charmsFolder = nil, nil
    while tick() - startTime < (timeout or 10) do
        pcall(function()
            local ps = player:FindFirstChild("PlayerScripts")
            if ps then
                assets = ps:FindFirstChild("Assets")
                if assets then charmsFolder = assets:FindFirstChild("Charms") end
            end
        end)
        if assets and charmsFolder then return assets, charmsFolder end
        task.wait(0.1)
    end
    return assets, charmsFolder
end

local Assets, CharmsFolder = WaitAssets(15)

if not CharmsFolder then
    pcall(function()
        local ss = StarterPlayer:WaitForChild("StarterPlayerScripts", 5)
        if ss then
            local sa = ss:FindFirstChild("Assets")
            if sa then CharmsFolder = sa:FindFirstChild("Charms") end
        end
    end)
end

local function Hex2RGB(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1,2), 16) / 255
    local g = tonumber(hex:sub(3,4), 16) / 255
    local b = tonumber(hex:sub(5,6), 16) / 255
    return Color3.new(r, g, b)
end

local Colors = { -- this the rarity colors dont change it unless you want to
    Common      = Hex2RGB("6dda2d"),
    Rare        = Hex2RGB("0097b0"),
    Legendary   = Hex2RGB("c51314"),
    Mythical    = Hex2RGB("7f7fff"),
    Special     = Hex2RGB("ff9b00"),
    Glorious    = Hex2RGB("e6ba67"),
    Unobtainable = Hex2RGB("919296")
}

local Order = { -- sort by u couuld make this better if u check the modules
    Common=1, Rare=2, Legendary=3, Mythical=4,
    Special=5, Glorious=6, Unobtainable=7
}
-- get rarity function
local function GetRarity(skin, weapon)
    local common = {
        "Phoenix Rifle","Compound Bow","Pine Burst","Spectral Burst","Crossbone",
        "Cyber Distortion","Lamethrower","Boneblade","Crude Gunblade","Elf's Gunblade",
        "Pumpkin Minigun","Wrapped Minigun","Ketchup Gun","Ice Permafrost","Snowman Permafrost",
        "Pencil Launcher","Cactus Shotgun","Wrapped Shotgun","Eyething Sniper","Paper Planes",
        "Shurikens","Midnight Festive Exogun","Wrapped Flare Gun","Gumball Handgun","Pumpkin Handgun",
        "Towerstone Handgun","Warp Handgun","Lovely Shorty","Not So Shorty","Too Shorty",
        "Wrapped Shorty","Goalpost","Stick","Lovely Spray","Nail Gun","Pine Spray",
        "Pine Uzi","Ban Axe","Nordic Axe","Brass Knuckles","Festive Fists","Pumpkin Claws",
        "Chancla","Machete","Ice Maul","Door","Sled","Tombstone Shield","Lightbulb",
        "Skullbang","Wrapped Freeze Ray","Dynamite","Frozen Grenade","Spider Web","Trampoline",
        "Coffee","Torch","Bag o' Money","Notebook Satchel","Suspicious Gift","Balance",
        "DIY Tripmine","Trick or Treat","Mammoth Horn","Megaphone","Warpbone","Cyber Warpstone"
    }
    local rare = {
        "AK-47","Boneclaw Rifle","Bat Bow","Dream Bow","Frostbite Bow","Raven Bow",
        "Aqua Burst","Frostbite Crossbow","Harpoon Crossbow","Violin Crossbow","Electropunk Distortion",
        "Magma Distortion","Plasma Distortion","Sleighstortion","New Year Energy Rifle","Apex Rifle",
        "Hacker Rifle","Hydro Rifle","Glitterthrower","Jack O' Thrower","Snowblower",
        "Gearnade Launcher","Snowball Launcher","Uranium Launcher","Brain Gun","Slime Gun",
        "Snowball Gun","Squid Launcher","Broomstick","Gingerbread Sniper","Aces","Bat Daggers",
        "Cookies","New Year Energy Pistols","Apex Pistols","Hacker Pistols","Hydro Pistols",
        "Wondergun","Exogourd","Ray Gun","Dynamite Gun","Blaster","Gingerbread Handgun",
        "Boneclaw Revolver","Desert Eagle","Demon Shorty","Boneshot","Reindeer Slingshot",
        "Boneclaw Spray","Demon Uzi","Water Uzi","Electropunk Warper","Frost Warper","Glitter Warper",
        "Cerulean Axe","Blobsaw","Fists of Hurt","Boxing Gloves","New Year Katana","Evil Trident",
        "Lightning Bolt","Stellar Katana","Sleigh Maul","Energy Shield","Masterpiece",
        "Anchor","Bat Scythe","Cryo Scythe","Sakura Scythe","Scythe of Death","Garden Shovel",
        "Paintbrush","Plastic Shovel","Pumpkin Carver","Snow Shovel","Shining Star","Bubble Ray",
        "Gum Ray","Jingle Grenade","Water Balloon","Bounce House","Jolly Man","Shady Chicken Sandwhich",
        "Briefcase","Lava Lamp","Advanced Satchel","Potion Satchel","Hourglass","Snowglobe",
        "Spring","Air Horn","Boneclaw Horn","Trumpet","Electropunk Warpstone","Unstable Warpstone"
    }
    local legendary = {
        "AUG","Gingerbread AUG","Tommy Gun","Balloon Bow","Beloved Bow","Electro Rifle",
        "FAMAS","Pixel Burst","Pixel Crossbow","Experiment D15","Soul Rifle","Void Rifle",
        "Pixel Flamethrower","Rainbowthrower","Balloon Launcher","Skull Launcher","Swashbuckler",
        "Gunsaw","Hyper Gunblade","Fighter Jet","Lasergun 3000","Pixel Minigun","Paintballoon Gun",
        "Boba Gun","Firework Launcher","Nuke Launcher","Pumpkin Launcher","Rocket Launcher",
        "Spaceship Launcher","Balloon Shotgun","Hyper Shotgun","Event Horizon","Hyper Sniper",
        "Pixel Sniper","Broken Hearts","Hyperlaser Guns","Soul Pistols","Void Pistols",
        "Repulsor","Singularity","Banana Flare","Firework Gun","Vexed Flare Gun","Hand-Gun",
        "Pixel Handgun","Peppergun","Peppermint Sheriff","Sheriff","Balloon Shorty","Harp",
        "Lucky Horseshoe","Spray Bottle","Electro Uzi","Money Gun","Arcane Warper","Experiment W4",
        "Hotel Bell","Balloon Axe","Mimic Axe","The Shred","Buzzsaw","Festive Buzzsaw",
        "Handsaws","Mega Drill","Fist","Linked Sword","Pixel Katana","Saber","Balisong",
        "Candy Cane","Karambit","Caladbolg","Ban Hammer","Camera","Disco Ball","Pixel Flashbang",
        "Spider Ray","Temporal Ray","Cuddle Bomb","Soul Grenade","Whoopee Cushion","Box of Chocolates",
        "Bucket of Candy","Laptop","Milk & Cookies","Medkitty","Sandwich","Hot Coals",
        "Vexed Candle","Emoji Cloud","Eyeball","Don't Press","Dev-in-the-Box","Pot o' Keys",
        "Teleport Disc","Warpstar"
    }
    local mythical = {
        "AKEY-47","Keybow","Keyst Rifle","Arch Crossbow","Keythrower","RPKey","Shotkey",
        "Keyper","Keynais","Crystal Daggers","Keyvolver","Key Spray","Keyzi","Keyttle Axe",
        "Arch Katana","Crystal Katana","Keytana","Keyrambit","Keylisong","Keythe","Crystal Scythe",
        "Keynade","Arch Molotov","Warpeye"
    }
    local special = { "10B Visits" }
    local glorious = {
        "Glorious","Glorious Assault Rifle","Glorious Bow","Glorious Burst Rifle","Glorious Crossbow",
        "Glorious Distortion","Glorious Energy Rifle","Glorious Flamethrower","Glorious Grenade Launcher",
        "Glorious Gunblade","Glorious Minigun","Glorious Paintball Gun","Glorious Permafrost",
        "Glorious RPG","Glorious Shotgun","Glorious Sniper","Glorious Daggers","Glorious Energy Pistols",
        "Glorious Exogun","Glorious Flare Gun","Glorious Handgun","Glorious Revolver","Glorious Shorty",
        "Glorious Slingshot","Glorious Spray","Glorious Uzi","Glorious Warper","Glorious Battle Axe",
        "Glorious Chainsaw","Glorious Fists","Glorious Katana","Glorious Knife","Glorious Riot Shield",
        "Glorious Scythe","Glorious Maul","Glorious Trowel","Glorious Flashbang","Glorious Freeze Ray",
        "Glorious Grenade","Glorious Jump Pad","Glorious Medkit","Glorious Molotov","Glorious Satchel",
        "Glorious Smoke Grenade","Glorious Subspace Tripmine","Glorious War Horn","Glorious Warpstone"
    }
    local unobtainable = { "Stealth Handgun","Armature.001","Bug Net" }

    if table.find(common, skin)      then return "Common"      end
    if table.find(rare, skin)        then return "Rare"        end
    if table.find(legendary, skin)   then return "Legendary"   end
    if table.find(mythical, skin)    then return "Mythical"    end
    if table.find(special, skin)     then return "Special"     end
    if table.find(glorious, skin)    then return "Glorious"    end
    if table.find(unobtainable, skin) then return "Unobtainable" end
    return "Common"
end

local function SortSkins(list, weapon)
    local with_rarity = {}
    for _, name in ipairs(list) do
        local r = GetRarity(name, weapon)
        table.insert(with_rarity, {name=name, r_order=Order[r] or 1})
    end
    table.sort(with_rarity, function(a,b) return a.r_order < b.r_order end)
    local sorted = {}
    for _, item in ipairs(with_rarity) do table.insert(sorted, item.name) end
    return sorted
end

local WrapConfig = {
    enabled    = false,
    per_weapon = {},
    inverted   = false
}
local WrappedCache = {}

local function LocalFighter()
    local ok, ctrl = pcall(require, player.PlayerScripts.Controllers.FighterController)
    if not ok or not ctrl then return nil end
    if ctrl.WaitForLocalFighter then
        local ok2, lf = pcall(ctrl.WaitForLocalFighter, ctrl)
        if ok2 then return lf end
    end
    return ctrl.LocalFighter
end

local function ForcedWrap(item)
    if not WrapConfig.enabled or not item then return nil end
    local weapon = item.Name
    local data   = WrapConfig.per_weapon[weapon]
    if not data or not data.name or data.name == '' or data.name == 'None' then return nil end
    return { Name = data.name, Inverted = data.inverted or false }
end

local function ForceWrap(item)
    if not item then return false end
    local forced = ForcedWrap(item)
    if not forced then return false end
    if item.Set then pcall(item.Set, item, 'Wrap', forced) end
    pcall(function() rawset(item, '_wrap', forced) end)
    local vm = item.ViewModel
    if vm then
        if vm.Set then pcall(vm.Set, vm, 'Wrap', forced) end
        pcall(function() rawset(vm, '_wrap', forced) end)
        if vm._UpdateWrap then pcall(vm._UpdateWrap, vm)
        elseif vm.UpdateWrap then pcall(vm.UpdateWrap, vm) end
    end
    if item.ClientFighter and item.ClientFighter.Set then
        pcall(item.ClientFighter.Set, item.ClientFighter, 'Wrap', forced)
    end
    return true
end

local function WrapAll()
    local lf = LocalFighter()
    if not lf then return end
    local inv = nil
    if lf.Get then
        local ok, i = pcall(lf.Get, lf, 'Inventory')
        if ok then inv = i end
    end
    if not inv and rawget(lf, 'Inventory') then inv = lf.Inventory end
    if not inv then return end
    for i = 1, 10 do
        local item = nil
        if inv.Get then
            local ok, slot = pcall(inv.Get, inv, i)
            if ok then item = slot end
        elseif inv[i] then
            item = inv[i]
        end
        if item then
            if ForceWrap(item) then WrappedCache[item] = true end
        end
    end
    local equipped = lf.EquippedItem
    if equipped then ForceWrap(equipped) end
end

local function WrapEquipped()
    local lf = LocalFighter()
    if not lf then return end
    local item = lf.EquippedItem
    if not item and type(lf.Get) == 'function' then
        local ok, res = pcall(lf.Get, lf, 'EquippedItem')
        if ok then item = res end
    end
    if item then ForceWrap(item) end
end

local function HookFighter()
    local lf = LocalFighter()
    if not lf or lf.__wrapFighterHooked then return end
    lf.__wrapFighterHooked = true
    if lf.EquippedItemChanged and lf.EquippedItemChanged.Connect then
        lf.EquippedItemChanged:Connect(function(item)
            if item then task.wait(0.05); ForceWrap(item) end
        end)
    end
    if lf.EquippedItem then WrapEquipped() end
    task.spawn(function()
        wait(0.5)
        if WrapConfig.enabled then WrapAll() end
    end)
end

task.spawn(function()
    while task.wait(0.3) do
        pcall(function()
            HookFighter()
            if WrapConfig.enabled then WrapAll() end
        end)
    end
end)

local function UpdateWraps()
    if WrapConfig.enabled then
        WrappedCache = {}
        WrapAll()
        WrapEquipped()
    end
end

RunService.Heartbeat:Connect(ActiveWeapon)

task.wait(5)
local psAssets = player:FindFirstChild("PlayerScripts")
if not psAssets then return end

local function WaitChild(parent, name, timeout)
    timeout = timeout or 5
    local start = tick()
    while tick() - start < timeout do
        local child = parent:FindFirstChild(name)
        if child then return child end
        task.wait(0.1)
    end
    return nil
end

local Assets      = WaitChild(psAssets, "Assets", 10)
local ViewModels  = Assets and WaitChild(Assets, "ViewModels", 10)
if not ViewModels then return end

local StarterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local starter_assets = StarterPlayerScripts and WaitChild(StarterPlayerScripts, "Assets", 10)
local starter_views  = starter_assets and WaitChild(starter_assets, "ViewModels", 10)

-- §05 WEAPON LISTS, BUCKETS, GetSkins/GetWraps/GetWeapons -------------------
local excluded = { ["Glass Cannon"]=true, ["Glast Shard"]=true, ["Elixir"]=true, ["Scepter"]=true }

--[[ Buckets for Skins/Wraps/Charms UI; overrides ItemLib.Type when needed. ]]
local WEAPON_CATEGORY_OVERRIDES = {
	["Flamethrower"] = "Gun",
	["Warper"] = "Gun",
	["Jump Pad"] = "Throwable",
	["Medkit"] = "Throwable",
	["Subspace Tripmine"] = "Throwable",
	["War Horn"] = "Throwable",
}

local function resolveWeaponCategory(itemName, itemData)
	local o = WEAPON_CATEGORY_OVERRIDES[itemName]
	if o then
		return o
	end
	if itemData then
		local t = itemData.Type
		if t == "Gun" or t == "Melee" or t == "Throwable" then
			return t
		end
	end
	return "Other"
end

local function shouldIncludeWeaponFromItemLib(name, data)
	if WEAPON_CATEGORY_OVERRIDES[name] then
		return true
	end
	if data and (data.Type == "Gun" or data.Type == "Melee" or data.Type == "Throwable") then
		return true
	end
	return false
end

local function insertWeaponByCategory(cat, name, guns, melees, utils, extras)
	if cat == "Gun" then
		table.insert(guns, name)
	elseif cat == "Melee" then
		table.insert(melees, name)
	elseif cat == "Throwable" then
		table.insert(utils, name)
	else
		table.insert(extras, name)
	end
end

local function EquipSkinInGame(weaponName, skinName)
    if not ItemLib or not CosmeticLib then return false end
    local viewmodels = ItemLib.ViewModels
    local cosmetics  = CosmeticLib.Cosmetics
    local ogVM = viewmodels and viewmodels[weaponName]
    if not ogVM then return false end

    if not skinName or skinName == "" or skinName == "None" then
        return true
    end

    local skinCosmetic = cosmetics and cosmetics[skinName]
    if not skinCosmetic or skinCosmetic.Type ~= "Skin" then return false end

    local skinVM = viewmodels and viewmodels[skinName]
    if not skinVM then return false end

    ogVM.Image                    = skinVM.Image                    or ogVM.Image
    ogVM.ImageHighResolution      = skinVM.ImageHighResolution      or ogVM.ImageHighResolution
    ogVM.ImageCentered            = skinVM.ImageCentered            or ogVM.ImageCentered
    ogVM.EliminationFeedImage     = skinVM.EliminationFeedImage     or ogVM.EliminationFeedImage
    ogVM.EliminationFeedImageScale = skinVM.EliminationFeedImageScale or ogVM.EliminationFeedImageScale
    ogVM.RootPartOffset           = skinVM.RootPartOffset           or ogVM.RootPartOffset

    ogVM.Animations = {}
    for animType, animName in pairs(skinVM.Animations or {}) do
        ogVM.Animations[animType] = animName
    end
    return true
end

local function ApplySkinModelToWeapon(wModel, skinName)
    if not skinName or skinName == "" or skinName == "None" then return end
    if not starter_views then return end
    local skinModel = starter_views:FindFirstChild(skinName, true)
    if not skinModel or not skinModel:IsA("Model") then return end
    wModel:ClearAllChildren()
    for _, part in ipairs(skinModel:GetChildren()) do
        part:Clone().Parent = wModel
    end
end


local function GetWeapons()
    local seen = {}
    local guns, melees, utils, extras = {}, {}, {}, {}

    if ItemLib and ItemLib.Items then
        for name, data in pairs(ItemLib.Items) do
            if excluded[name] then continue end
            if name == "MISSING_WEAPON" or name == "MISSING_SKIN" then continue end
            if not shouldIncludeWeaponFromItemLib(name, data) then continue end
            seen[name] = true
            local cat = resolveWeaponCategory(name, data)
            insertWeaponByCategory(cat, name, guns, melees, utils, extras)
        end
    end

    if CosmeticLib and CosmeticLib.Cosmetics then
        for _, data in pairs(CosmeticLib.Cosmetics) do
            if data.Type == "Skin" and data.ItemName then
                local n = data.ItemName
                if not seen[n] and not excluded[n] and n ~= "MISSING_WEAPON" then
                    seen[n] = true
                    local itemData = ItemLib and ItemLib.Items and ItemLib.Items[n]
                    local cat = resolveWeaponCategory(n, itemData)
                    insertWeaponByCategory(cat, n, guns, melees, utils, extras)
                end
            end
        end
    end

    table.sort(guns); table.sort(melees); table.sort(utils); table.sort(extras)
    local all = {}
    for _, w in ipairs(guns)   do table.insert(all, w) end
    for _, w in ipairs(melees) do table.insert(all, w) end
    for _, w in ipairs(utils)  do table.insert(all, w) end
    for _, w in ipairs(extras) do table.insert(all, w) end
    return all
end

local function GetSkins(weapon)
    local skins = {}
    if CosmeticLib and CosmeticLib.Cosmetics then
        for name, data in pairs(CosmeticLib.Cosmetics) do
            if data.Type == "Skin" and data.ItemName == weapon and name ~= "MISSING_SKIN" then
                local display = name
                if display == "Glorious Assault Rifle" then display = "Glorious AR" end
                table.insert(skins, display)
            end
        end
    end
    return SortSkins(skins, weapon)
end

local function GetAllWraps()
    local wraps = {}
    if CosmeticLib and CosmeticLib.Cosmetics then
        for name, data in pairs(CosmeticLib.Cosmetics) do
            if data.Type == "Wrap" then table.insert(wraps, name) end
        end
    end
    table.sort(wraps)
    return wraps
end

local function GetAllCharms()
    local charms = {}
    if CosmeticLib and CosmeticLib.Cosmetics then
        for name, data in pairs(CosmeticLib.Cosmetics) do
            if data.Type == "Charm" then table.insert(charms, name) end
        end
    end
    table.sort(charms)
    return charms
end

--[[ Split weapon list for Obsidian-style skin rows (one dropdown per gun). ]]
local function GetWeaponsPartitioned()
    local guns, melees, utils, extras = {}, {}, {}, {}
    for _, w in ipairs(GetWeapons()) do
        local itemData = ItemLib and ItemLib.Items and ItemLib.Items[w]
        local cat = resolveWeaponCategory(w, itemData)
        insertWeaponByCategory(cat, w, guns, melees, utils, extras)
    end
    return guns, melees, utils, extras
end

local function skinDisplayToReal(display)
    if display == "Glorious AR" then return "Glorious Assault Rifle" end
    return display
end

local function skinDropdownIdx(weaponName)
    local base = string.gsub(weaponName, "[^%w]", "_")
    local idx = "SkinW_" .. base
    if #idx > 72 then
        idx = "SkinW_" .. tostring(#weaponName) .. "_" .. string.sub(base, 1, 50)
    end
    return idx
end

-- §06 ACIDHUB UI — remote fallback + Library load ----------------------------
local repo = "https://raw.githubusercontent.com/justhereforagoodtime42/library/refs/heads/main/"

local function tryLoadfile(path)
	local lf = loadfile
	if type(lf) ~= "function" then
		return nil
	end
	local okChunk, chunk = pcall(lf, path)
	if not okChunk or type(chunk) ~= "function" then
		return nil
	end
	local ok, res = pcall(chunk)
	return ok and res or nil
end

-- HttpGet can fail or return nil (blocked / rate limit); never pass nil to loadstring
local function httpGetString(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok or type(body) ~= "string" or body == "" then
		return nil
	end
	return body
end

local function loadRemoteLua(url, label)
	local src = httpGetString(url)
	if not src then
		error(
			"[AcidHub] "
				.. (label or "script")
				.. " failed to download (HttpGet empty or blocked). Use local files via loadfile or check URL: "
				.. tostring(url),
			0
		)
	end
	local fn, err = loadstring(src, label or "remote")
	if not fn then
		error("[AcidHub] loadstring failed: " .. tostring(err), 0)
	end
	return fn()
end

local Library = tryLoadfile("ui/library.lua")
if not Library then
	Library = loadRemoteLua(repo .. "main.lua", "main.lua")
end
local ThemeManager = tryLoadfile("ui/addons/ThemeManager.lua")
if not ThemeManager then
	ThemeManager = loadRemoteLua(repo .. "thememanager", "thememanager")
end
local SaveManager = tryLoadfile("ui/addons/SaveManager.lua")
if not SaveManager then
	SaveManager = loadRemoteLua(repo .. "savemanager", "savemanager")
end

local Options = Library.Options
local Toggles = Library.Toggles
local genv = (getgenv or function()
	return shared
end)()
if genv == nil then
	genv = shared
end
genv.AcidHubLibrary = Library

-- §07 UI HELPERS — per-weapon dropdowns (Skins / Wraps / Charms) ------------
local function addSkinDropdownForWeapon(weaponName, group)
	local skins = GetSkins(weaponName)
	if #skins == 0 then
		return false
	end
	local opts = { "None" }
	for _, s in ipairs(skins) do
		table.insert(opts, s)
	end
	local defaultIx = 1
	local cfg = Config[weaponName]
	if cfg and cfg.Skin and cfg.Skin.Name then
		local rn = cfg.Skin.Name
		for i = 2, #opts do
			local disp = opts[i]
			if skinDisplayToReal(disp) == rn or disp == rn then
				defaultIx = i
				break
			end
		end
	end
	local idx = skinDropdownIdx(weaponName)
	group:AddDropdown({
		Text = weaponName,
		Options = opts,
		Default = defaultIx,
		Idx = idx,
	})
	local reg = Options[idx]
	if reg and reg.OnChanged then
		reg:OnChanged(function()
			local v = reg.Value
			if v == "None" then
				EquipCosmetic(weaponName, "None", "Skin")
			else
				EquipCosmetic(weaponName, skinDisplayToReal(v), "Skin")
			end
		end)
	end
	return true
end

local function wrapDropdownIdx(weaponName)
	local base = string.gsub(weaponName, "[^%w]", "_")
	local idx = "WrapW_" .. base
	if #idx > 72 then
		idx = "WrapW_" .. tostring(#weaponName) .. "_" .. string.sub(base, 1, 50)
	end
	return idx
end

local function charmDropdownIdx(weaponName)
	local base = string.gsub(weaponName, "[^%w]", "_")
	local idx = "CharmW_" .. base
	if #idx > 72 then
		idx = "CharmW_" .. tostring(#weaponName) .. "_" .. string.sub(base, 1, 50)
	end
	return idx
end

local function addWrapDropdownForWeapon(weaponName, group)
	local wraps = GetAllWraps()
	local opts = { "None" }
	for _, w in ipairs(wraps) do
		table.insert(opts, w)
	end
	local defaultIx = 1
	local stored = WrapConfig.per_weapon[weaponName]
	if stored and stored.name and stored.name ~= "" and stored.name ~= "None" then
		for i = 2, #opts do
			if opts[i] == stored.name then
				defaultIx = i
				break
			end
		end
	end
	local idx = wrapDropdownIdx(weaponName)
	group:AddDropdown({
		Text = weaponName,
		Options = opts,
		Default = defaultIx,
		Idx = idx,
	})
	local reg = Options[idx]
	if reg and reg.OnChanged then
		reg:OnChanged(function()
			local v = reg.Value
			if v == "None" then
				WrapConfig.per_weapon[weaponName] = nil
			else
				WrapConfig.per_weapon[weaponName] = {
					name = v,
					inverted = Toggles.WrapInvert.Value,
				}
			end
			WrapConfig.enabled = next(WrapConfig.per_weapon) ~= nil
			UpdateWraps()
		end)
	end
	return true
end

local function addCharmDropdownForWeapon(weaponName, group)
	local charms = GetAllCharms()
	local opts = { "None" }
	for _, c in ipairs(charms) do
		table.insert(opts, c)
	end
	local defaultIx = 1
	local cfg = Config[weaponName]
	if cfg and cfg.Charm and cfg.Charm.Name then
		local cn = cfg.Charm.Name
		for i = 2, #opts do
			if opts[i] == cn then
				defaultIx = i
				break
			end
		end
	end
	local idx = charmDropdownIdx(weaponName)
	group:AddDropdown({
		Text = weaponName,
		Options = opts,
		Default = defaultIx,
		Idx = idx,
	})
	local reg = Options[idx]
	if reg and reg.OnChanged then
		reg:OnChanged(function()
			local v = reg.Value
			if v == "None" then
				EquipCosmetic(weaponName, "None", "Charm")
			else
				EquipCosmetic(weaponName, v, "Charm")
			end
		end)
	end
	return true
end

-- §08 WINDOW & TAB REFERENCES -----------------------------------------------
local Window = Library.new({
	Title = "AcidHub",
	Subtitle = "Rivals | v1.0 | discord.gg/acidhub",
	TitleIcon = 114741603622587,
	Size = Vector2.new(640, 560),
	NotifySide = "Right",
	MultiDropdownByDefault = false,
})

local Tabs = {
    Main = Window:AddTab({ Name = "Main", Icon = "crosshair", SplitColumns = true }),
    Visuals = Window:AddTab({ Name = "Visuals", Icon = "eye", SplitColumns = true }),
	Skins = Window:AddTab({ Name = "Skins", Icon = "bow-arrow", SplitColumns = true }),
	Wraps = Window:AddTab({ Name = "Wraps", Icon = "sticky-note", SplitColumns = true }),
	Charms = Window:AddTab({ Name = "Charms", Icon = "banana", SplitColumns = true }),
	["UI Settings"] = Window:AddTab({ Name = "UI Settings", Icon = "settings", SplitColumns = true }),
}

-- §09 MAIN TAB — Aimbot tabbox (Silent Aim + Aimbot) -------------------------
local Rivals_UnloadSilentAim
local Rivals_UnloadWeaponMods
do
local AimbotTabbox = Tabs.Main:AddLeftTabbox("Aimbot")
local SilentAimTabPage = AimbotTabbox:AddTab("Silent Aim")
local AimbotSubTabPage = AimbotTabbox:AddTab("Aimbot")

local SilentAimSettings = {
	Enabled = false,
	ClassName = "AcidHub",
	ToggleKey = "",
	TeamCheck = false,
	VisibleCheck = false,
	TargetPart = "HumanoidRootPart",
	FOVRadius = 130,
	FOVVisible = false,
	HitChance = 100,
}
--[[ Aimbot: viewport FOV + optional wall LOS + mouse movement (mousemoverel). ]]
local AimbotSettings = {
	Enabled = false,
	WallCheck = false,
	FOVCircleVisible = false,
	Fov = 120,
	FovColor = Color3.fromRGB(255, 255, 255),
	SmoothingEnabled = true,
	Smoothing = 0,
	TeamCheck = false,
	AimPart = "Head",
	Key = Enum.UserInputType.MouseButton2,
	KeyName = "MouseButton2",
	PredictionEnabled = false,
	PredictionAmount = 0,
}
genv.SilentAimSettings = SilentAimSettings
genv.AimbotSettings = AimbotSettings

genv.RivalsWeaponMods = {
	RapidFire = false,
	RapidFireSpeed = 0.01,
	NoRecoil = false,
	RecoilReduction = 100,
	NoSpread = false,
	NoWeaponBob = false,
	InstantADS = false,
	InfiniteAmmo = false,
	InstantBulletTravel = false,
	GunModule = nil,
	GameplayUtility = nil,
	ViewModelModule = nil,
	OriginalStartShooting = nil,
	OriginalRecoil = nil,
	OriginalStartAiming = nil,
	OriginalGetAimSpeed = nil,
	OriginalLocalTracers = nil,
	OriginalGetSpread = nil,
	OriginalViewModelNew = nil,
}

task.spawn(function()
	local success, GunModule = pcall(function()
		return require(player.PlayerScripts.Modules.ItemTypes.Gun)
	end)
	if not success or not GunModule then
		return
	end
	local R = genv.RivalsWeaponMods
	R.GunModule = GunModule
	if GunModule.StartShooting then
		R.OriginalStartShooting = GunModule.StartShooting
		GunModule.StartShooting = function(self, p26, p27)
			local useRapidFire = R.RapidFire
			local useInfiniteAmmo = R.InfiniteAmmo
			if useInfiniteAmmo then
				local currentAmmo = self:Get("Ammo")
				if currentAmmo <= 0 then
					self:SetReplicate("Ammo", self.Info.MaxAmmo)
				end
			end
			local oldShootCooldown, oldBurstCooldown
			if useRapidFire then
				oldShootCooldown = self.Info.ShootCooldown
				oldBurstCooldown = self.Info.ShootBurstCooldown
				self.Info.ShootCooldown = R.RapidFireSpeed or 0.01
				self.Info.ShootBurstCooldown = R.RapidFireSpeed or 0.01
			end
			local result = { R.OriginalStartShooting(self, p26, p27) }
			if useRapidFire then
				self.Info.ShootCooldown = oldShootCooldown
				self.Info.ShootBurstCooldown = oldBurstCooldown
			end
			return table.unpack(result)
		end
	end
	if GunModule._Recoil then
		R.OriginalRecoil = GunModule._Recoil
		GunModule._Recoil = function(self, multiplier)
			if R.NoRecoil then
				local reduction = R.RecoilReduction or 100
				local newMultiplier = multiplier * (1 - reduction / 100)
				if newMultiplier <= 0.001 then
					return
				end
				return R.OriginalRecoil(self, newMultiplier)
			end
			return R.OriginalRecoil(self, multiplier)
		end
	end
	if GunModule.StartAiming then
		R.OriginalStartAiming = GunModule.StartAiming
		GunModule.StartAiming = function(self, p71)
			if R.InstantADS then
				self:SetReplicate("IsAiming", true)
				self.StopSprinting:Fire()
				self.ViewModel:SetAiming(true)
				self:SetReplicate("FOVOffset", self.Info.AimFOVOffset)
				if self.ViewModel.CurrentAimValue then
					self.ViewModel.CurrentAimValue = 1
				end
				return true, "StartAiming"
			end
			return R.OriginalStartAiming(self, p71)
		end
	end
	if GunModule.GetAimSpeed then
		R.OriginalGetAimSpeed = GunModule.GetAimSpeed
		GunModule.GetAimSpeed = function(self)
			if R.InstantADS then
				return 999
			end
			return R.OriginalGetAimSpeed(self)
		end
	end
	if GunModule._LocalTracers then
		R.OriginalLocalTracers = GunModule._LocalTracers
		GunModule._LocalTracers = function(self, p109, p110)
			if R.InstantBulletTravel then
				local originalPierce = self.Info.RaycastPierceCount
				local originalBounce = self.Info.RaycastBounceCount
				local originalBounceAngle = self.Info.RaycastBounceRedirectionAngle
				self.Info.RaycastPierceCount = 999
				self.Info.RaycastBounceCount = 0
				self.Info.RaycastBounceRedirectionAngle = 0
				local result = { R.OriginalLocalTracers(self, p109, p110) }
				self.Info.RaycastPierceCount = originalPierce
				self.Info.RaycastBounceCount = originalBounce
				self.Info.RaycastBounceRedirectionAngle = originalBounceAngle
				return table.unpack(result)
			end
			return R.OriginalLocalTracers(self, p109, p110)
		end
	end
end)

task.spawn(function()
	local success, GameplayUtility = pcall(function()
		return require(ReplicatedStorage.Modules.GameplayUtility)
	end)
	if not success or not GameplayUtility or not GameplayUtility.GetSpread then
		return
	end
	local R = genv.RivalsWeaponMods
	R.GameplayUtility = GameplayUtility
	R.OriginalGetSpread = GameplayUtility.GetSpread
	GameplayUtility.GetSpread = function(spread, aimMultiplier, isAiming, isCrouching, pelletIndex, totalPellets, consistent)
		if R.NoSpread then
			return CFrame.new()
		end
		return R.OriginalGetSpread(
			spread,
			aimMultiplier,
			isAiming,
			isCrouching,
			pelletIndex,
			totalPellets,
			consistent
		)
	end
end)

task.spawn(function()
	local success, ViewModelModule = pcall(function()
		return require(player.PlayerScripts.Modules.ViewModel)
	end)
	if not success or not ViewModelModule or not ViewModelModule.new then
		return
	end
	local R = genv.RivalsWeaponMods
	R.ViewModelModule = ViewModelModule
	R.OriginalViewModelNew = ViewModelModule.new
	local originalNew = ViewModelModule.new
	ViewModelModule.new = function(...)
		local viewModel = originalNew(...)
		if viewModel.Update then
			local originalUpdate = viewModel.Update
			viewModel.Update = function(self, ...)
				if R.NoWeaponBob then
					if self.BobSpeed then
						self.BobSpeed = 0
					end
					if self.BobIntensity then
						self.BobIntensity = 0
					end
				end
				return originalUpdate(self, ...)
			end
		end
		return viewModel
	end
end)

local Camera = workspace.CurrentCamera
local LocalPlayer = player

local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local GetMouseLocation = UserInputService.GetMouseLocation

local ValidTargetParts = { "Head", "HumanoidRootPart" }

local hitChanceRng = Random.new()

local fov_circle
do
	local ok, cir = pcall(function()
		local d = Drawing
		return d and d.new("Circle")
	end)
	if ok and cir then
		fov_circle = cir
		fov_circle.Thickness = 1
		fov_circle.NumSides = 100
		fov_circle.Radius = SilentAimSettings.FOVRadius
		fov_circle.Filled = false
		fov_circle.Visible = SilentAimSettings.FOVVisible
		fov_circle.ZIndex = 999
		fov_circle.Transparency = 1
		fov_circle.Color = Color3.fromRGB(255, 255, 255)
	end
end

local aimbot_fov_circle
do
	local ok, cir = pcall(function()
		local d = Drawing
		return d and d.new("Circle")
	end)
	if ok and cir then
		aimbot_fov_circle = cir
		aimbot_fov_circle.Thickness = 2
		aimbot_fov_circle.NumSides = 64
		aimbot_fov_circle.Radius = AimbotSettings.Fov
		aimbot_fov_circle.Filled = false
		aimbot_fov_circle.Visible = false
		aimbot_fov_circle.ZIndex = 998
		aimbot_fov_circle.Transparency = 0.5
		aimbot_fov_circle.Color = AimbotSettings.FovColor
	end
end

local ExpectedArguments = {
	Raycast = {
		ArgCountRequired = 3,
		Args = {
			"Instance",
			"Vector3",
			"Vector3",
			"RaycastParams",
		},
	},
}

local function CalculateChance(Percentage)
	Percentage = math.floor(Percentage)
	return math.floor(hitChanceRng:NextNumber(0, 1) * 100) / 100 <= Percentage / 100
end

local function getPositionOnScreen(Vector)
	local Vec3, OnScreen = WorldToScreen(Camera, Vector)
	return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
	local Matches = 0
	if #Args < RayMethod.ArgCountRequired then
		return false
	end
	for Pos, Argument in next, Args do
		if typeof(Argument) == RayMethod.Args[Pos] then
			Matches = Matches + 1
		end
	end
	return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
	return (Position - Origin).Unit * 1000
end

local function validateRaycastArgs(Arguments)
	if #Arguments < 3 then
		return false
	end
	if typeof(Arguments[1]) ~= "Instance" then
		return false
	end
	if typeof(Arguments[2]) ~= "Vector3" or typeof(Arguments[3]) ~= "Vector3" then
		return false
	end
	local fourth = Arguments[4]
	if fourth ~= nil and typeof(fourth) ~= "RaycastParams" then
		return false
	end
	return true
end

local function getMousePosition()
	return GetMouseLocation(UserInputService)
end

local isCustomCharacterSystemAim = genv and genv.characters ~= nil

local function GetAllCharactersForAimbot()
	local allCharacters = {}
	if isCustomCharacterSystemAim and genv.characters then
		for playerName, characterData in pairs(genv.characters) do
			if characterData and characterData.character then
				table.insert(allCharacters, {
					name = playerName,
					character = characterData.character,
					player = characterData.player or nil,
					team = characterData.team or nil,
				})
			end
		end
	else
		for _, pl in pairs(Players:GetPlayers()) do
			if pl ~= LocalPlayer and pl.Character then
				table.insert(allCharacters, {
					name = pl.Name,
					character = pl.Character,
					player = pl,
					team = pl.Team,
				})
			end
		end
	end
	return allCharacters
end

local aimbotWallRayParams = RaycastParams.new()
local function aimbotWallVisibleObsidian(targetPart)
	if not AimbotSettings.WallCheck then
		return true
	end
	local cam = Workspace.CurrentCamera
	if not cam or not targetPart then
		return false
	end
	local ignore = { LocalPlayer.Character, cam }
	local dir = (targetPart.Position - cam.CFrame.Position).Unit * 500
	local origin = cam.CFrame.Position
	local ray = Ray.new(origin, dir)
	if type(Workspace.FindPartOnRayWithIgnoreList) == "function" then
		local ok, hit = pcall(Workspace.FindPartOnRayWithIgnoreList, Workspace, ray, ignore)
		if ok then
			return not hit or hit:IsDescendantOf(targetPart.Parent)
		end
	end
	aimbotWallRayParams.FilterType = Enum.RaycastFilterType.Blacklist
	aimbotWallRayParams.FilterDescendantsInstances = ignore
	local r = Workspace:Raycast(origin, dir, aimbotWallRayParams)
	return not r or r.Instance:IsDescendantOf(targetPart.Parent)
end

local aimbotCachedPart, aimbotCacheTime, AIMBOT_CACHE_REFRESH = nil, 0, 0.06

local function aimbotIsTeammatePlayer(pl)
	if not AimbotSettings.TeamCheck or not pl then
		return false
	end
	return pl.Team ~= nil and LocalPlayer.Team ~= nil and pl.Team == LocalPlayer.Team
end

local function aimbotIsTeammateFromData(characterData)
	if not AimbotSettings.TeamCheck then
		return false
	end
	local pl = characterData.player or Players:GetPlayerFromCharacter(characterData.character)
	if pl then
		return aimbotIsTeammatePlayer(pl)
	end
	if characterData.team and LocalPlayer.Team then
		return characterData.team == LocalPlayer.Team
	end
	return false
end

local function resolveAimbotPart(character)
	if not character then
		return nil
	end
	local ap = AimbotSettings.AimPart
	local targetPart = nil
	if ap == "Head" then
		targetPart = character:FindFirstChild("Head") or character:FindFirstChild("Head", true)
	elseif ap == "HumanoidRootPart" then
		targetPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("HumanoidRootPart", true)
	elseif ap == "Torso" then
		targetPart = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	elseif ap == "UpperTorso" then
		targetPart = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	end
	if not targetPart then
		targetPart = character:FindFirstChild("HumanoidRootPart")
			or character:FindFirstChild("HumanoidRootPart", true)
			or character:FindFirstChild("Head")
			or character:FindFirstChild("Head", true)
	end
	return targetPart
end

local function aimbotGetTarget()
	local now = tick()
	if now - aimbotCacheTime < AIMBOT_CACHE_REFRESH and aimbotCachedPart and aimbotCachedPart.Parent then
		local hum = aimbotCachedPart.Parent and aimbotCachedPart.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			return aimbotCachedPart
		end
	end
	local mouse = getMousePosition()
	local best, bestDist = nil, AimbotSettings.Fov or 120
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end

	local function checkModel(model)
		if model == LocalPlayer.Character then
			return
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Parent ~= model or hum.Health <= 0 then
			return
		end
		local aimPart = resolveAimbotPart(model)
		if not aimPart then
			return
		end
		local sp, on = cam:WorldToViewportPoint(aimPart.Position)
		if not on then
			return
		end
		local dist = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
		if dist < bestDist then
			if not aimbotWallVisibleObsidian(aimPart) then
				return
			end
			best = aimPart
			bestDist = dist
		end
	end

	for _, characterData in ipairs(GetAllCharactersForAimbot()) do
		local char = characterData.character
		if char and not aimbotIsTeammateFromData(characterData) then
			checkModel(char)
		end
	end
	aimbotCachedPart = best
	aimbotCacheTime = now
	return best
end

local function aimbotKeyHeld()
	local key = AimbotSettings.Key
	if typeof(key) == "EnumItem" then
		if key.EnumType == Enum.UserInputType then
			return UserInputService:IsMouseButtonPressed(key)
		elseif key.EnumType == Enum.KeyCode then
			return UserInputService:IsKeyDown(key)
		end
	end
	return false
end

-- Many executors expose mouse movement only on getgenv(), not as a global
local aimbotMouseMoveRel = (function()
	if typeof(mousemoverel) == "function" then
		return mousemoverel
	end
	if getgenv then
		local ok, g = pcall(getgenv)
		if ok and g and typeof(g.mousemoverel) == "function" then
			return g.mousemoverel
		end
	end
	return function() end
end)()

local function aimbotMoveMouseTowardWorld(worldPos)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local sp, onScr = cam:WorldToViewportPoint(worldPos)
	if not onScr then
		return
	end
	local m = UserInputService:GetMouseLocation()
	local dx = sp.X - m.X
	local dy = sp.Y - m.Y
	if math.abs(dx) < 0.02 and math.abs(dy) < 0.02 then
		return
	end
	local factor = 1
	if AimbotSettings.SmoothingEnabled and AimbotSettings.Smoothing > 0 then
		factor = math.clamp(AimbotSettings.Smoothing, 0.01, 1)
	end
	dx *= factor
	dy *= factor
	aimbotMouseMoveRel(dx, dy)
end

local function shouldRedirectRaycast(origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return false
	end
	if direction.Magnitude < 25 then
		return false
	end
	if (origin - Camera.CFrame.Position).Magnitude > 20 then
		return false
	end
	return true
end

local function IsPlayerVisible(TargetPlayer)
	local PlayerCharacter = TargetPlayer.Character
	local LocalPlayerCharacter = LocalPlayer.Character

	if not (PlayerCharacter or LocalPlayerCharacter) then
		return
	end

	local PlayerRoot = FindFirstChild(PlayerCharacter, Options.TargetPart.Value)
		or FindFirstChild(PlayerCharacter, "HumanoidRootPart")

	if not PlayerRoot then
		return
	end

	local CastPoints, IgnoreList =
		{ PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter },
		{ LocalPlayerCharacter, PlayerCharacter }
	local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)

	return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function getClosestPlayer()
	if not Options.TargetPart.Value then
		return
	end
	local Closest
	local DistanceToMouse
	local teamCheck = Toggles.TeamCheck.Value
	local localTeam = teamCheck and LocalPlayer.Team
	for _, Plr in next, GetPlayers(Players) do
		if Plr == LocalPlayer then
			continue
		end
		if teamCheck and Plr.Team and localTeam and Plr.Team == localTeam then
			continue
		end

		local Character = Plr.Character
		if not Character then
			continue
		end

		if Toggles.VisibleCheck.Value and not IsPlayerVisible(Plr) then
			continue
		end

		local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
		local Humanoid = FindFirstChild(Character, "Humanoid")
		if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then
			continue
		end

		local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
		if not OnScreen then
			continue
		end

		local fovLimit = Options.Radius.Value or SilentAimSettings.FOVRadius or 2000
		local Distance = (getMousePosition() - ScreenPosition).Magnitude
		if Distance <= fovLimit and (not DistanceToMouse or Distance < DistanceToMouse) then
			Closest = (
				(
					Options.TargetPart.Value == "Random"
						and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]
				)
				or Character[Options.TargetPart.Value]
			)
			DistanceToMouse = Distance
		end
	end
	return Closest
end

local SilentAimGroup = SilentAimTabPage:AddLeftGroupbox("Silent Aim", { Icon = "target" })

SilentAimGroup:AddToggle({
	Text = "Enable Silent Aim",
	Default = SilentAimSettings.Enabled,
	Idx = "aim_Enabled",
}):AddKeybind({
	Default = false,
	Idx = "aim_Enabled_Key",
	SyncToggleState = true,
})

Toggles.aim_Enabled:OnChanged(function()
	SilentAimSettings.Enabled = Toggles.aim_Enabled.Value
end)

SilentAimGroup:AddToggle({
	Text = "Team Check",
	Default = SilentAimSettings.TeamCheck,
	Idx = "TeamCheck",
})
Toggles.TeamCheck:OnChanged(function()
	SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value
end)

local _fovVis = SilentAimGroup:AddToggle({
	Text = "Show FOV Circle",
	Default = SilentAimSettings.FOVVisible,
	Idx = "Visible",
})
if typeof(_fovVis.AddColorPicker) == "function" then
	_fovVis:AddColorPicker({
		Default = fov_circle and fov_circle.Color or Color3.fromRGB(255, 255, 255),
		Idx = "Color",
	})
else
	SilentAimGroup:AddColorPicker({
		Text = "FOV circle color",
		Default = fov_circle and fov_circle.Color or Color3.fromRGB(255, 255, 255),
		Idx = "Color",
	})
end

Toggles.Visible:OnChanged(function()
	if fov_circle then
		fov_circle.Visible = Toggles.Visible.Value
	end
	SilentAimSettings.FOVVisible = Toggles.Visible.Value
end)
Options.Color:OnChanged(function()
	if fov_circle then
		fov_circle.Color = Options.Color.Value
	end
end)

SilentAimGroup:AddToggle({
	Text = "Visible Check",
	Default = SilentAimSettings.VisibleCheck,
	Idx = "VisibleCheck",
})
Toggles.VisibleCheck:OnChanged(function()
	SilentAimSettings.VisibleCheck = Toggles.VisibleCheck.Value
end)

SilentAimGroup:AddDropdown({
	Text = "Target Part",
	AllowNull = false,
	Options = { "Head", "HumanoidRootPart", "Random" },
	Default = SilentAimSettings.TargetPart,
	Idx = "TargetPart",
})
Options.TargetPart:OnChanged(function()
	SilentAimSettings.TargetPart = Options.TargetPart.Value
end)

SilentAimGroup:AddSlider({
	Text = "Hit chance",
	Min = 0,
	Max = 100,
	Default = SilentAimSettings.HitChance,
	Rounding = 1,
	Idx = "HitChance",
})
Options.HitChance:OnChanged(function()
	SilentAimSettings.HitChance = Options.HitChance.Value
end)

SilentAimGroup:AddSlider({
	Text = "FOV Circle Radius",
	Min = 0,
	Max = 360,
	Default = SilentAimSettings.FOVRadius,
	Rounding = 0,
	Idx = "Radius",
})
Options.Radius:OnChanged(function()
	if fov_circle then
		fov_circle.Radius = Options.Radius.Value
	end
	SilentAimSettings.FOVRadius = Options.Radius.Value
end)

if Options.Radius and Options.Radius.Value and fov_circle then
	fov_circle.Radius = Options.Radius.Value
end
if Options.Color and Options.Color.Value and fov_circle then
	fov_circle.Color = Options.Color.Value
end

local MiscWeaponGroup = SilentAimTabPage:AddLeftGroupbox("Misc", { Icon = "zap", DefaultExpanded = true })

MiscWeaponGroup:AddToggle({
	Text = "Rapid Fire",
	Default = false,
	Idx = "rivmisc_RapidFire",
})
MiscWeaponGroup:AddSlider({
	Text = "Rapid fire cooldown",
	Min = 0.001,
	Max = 0.5,
	Rounding = 3,
	Default = 0.01,
	Idx = "rivmisc_RapidFireSpeed",
})
MiscWeaponGroup:AddToggle({
	Text = "No Recoil",
	Default = false,
	Idx = "rivmisc_NoRecoil",
})
MiscWeaponGroup:AddSlider({
	Text = "Recoil reduction %",
	Min = 0,
	Max = 100,
	Rounding = 0,
	Default = 100,
	Idx = "rivmisc_RecoilReduction",
})
MiscWeaponGroup:AddToggle({
	Text = "No Spread",
	Default = false,
	Idx = "rivmisc_NoSpread",
})
MiscWeaponGroup:AddToggle({
	Text = "No Weapon Bob",
	Default = false,
	Idx = "rivmisc_NoWeaponBob",
})
MiscWeaponGroup:AddToggle({
	Text = "Instant ADS",
	Default = false,
	Idx = "rivmisc_InstantADS",
})
MiscWeaponGroup:AddToggle({
	Text = "Infinite Ammo",
	Default = false,
	Idx = "rivmisc_InfiniteAmmo",
})
MiscWeaponGroup:AddToggle({
	Text = "Instant Bullet Travel",
	Default = false,
	Idx = "rivmisc_InstantBulletTravel",
})

local function syncRivalsWeaponModsFromOptions()
	local R = genv.RivalsWeaponMods
	if not R then
		return
	end
	R.RapidFire = Toggles.rivmisc_RapidFire.Value
	R.RapidFireSpeed = Options.rivmisc_RapidFireSpeed.Value
	R.NoRecoil = Toggles.rivmisc_NoRecoil.Value
	R.RecoilReduction = Options.rivmisc_RecoilReduction.Value
	R.NoSpread = Toggles.rivmisc_NoSpread.Value
	R.NoWeaponBob = Toggles.rivmisc_NoWeaponBob.Value
	R.InstantADS = Toggles.rivmisc_InstantADS.Value
	R.InfiniteAmmo = Toggles.rivmisc_InfiniteAmmo.Value
	R.InstantBulletTravel = Toggles.rivmisc_InstantBulletTravel.Value
end

Toggles.rivmisc_RapidFire:OnChanged(syncRivalsWeaponModsFromOptions)
Options.rivmisc_RapidFireSpeed:OnChanged(syncRivalsWeaponModsFromOptions)
Toggles.rivmisc_NoRecoil:OnChanged(syncRivalsWeaponModsFromOptions)
Options.rivmisc_RecoilReduction:OnChanged(syncRivalsWeaponModsFromOptions)
Toggles.rivmisc_NoSpread:OnChanged(syncRivalsWeaponModsFromOptions)
Toggles.rivmisc_NoWeaponBob:OnChanged(syncRivalsWeaponModsFromOptions)
Toggles.rivmisc_InstantADS:OnChanged(syncRivalsWeaponModsFromOptions)
Toggles.rivmisc_InfiniteAmmo:OnChanged(syncRivalsWeaponModsFromOptions)
Toggles.rivmisc_InstantBulletTravel:OnChanged(syncRivalsWeaponModsFromOptions)

local aimbotActivateKeyMap = {
	MouseButton2 = Enum.UserInputType.MouseButton2,
	X = Enum.KeyCode.X,
}

local AimbotGroup = AimbotSubTabPage:AddLeftGroupbox("Aimbot", { Icon = "crosshair" })

AimbotGroup:AddToggle({
	Text = "Enabled",
	Default = AimbotSettings.Enabled,
	Idx = "aimbot_Enabled",
}):AddKeybind({
	Default = false,
	Idx = "aimbot_Enabled_Key",
	SyncToggleState = true,
})
Toggles.aimbot_Enabled:OnChanged(function()
	AimbotSettings.Enabled = Toggles.aimbot_Enabled.Value
end)

AimbotGroup:AddToggle({
	Text = "Prediction",
	Default = AimbotSettings.PredictionEnabled,
	Idx = "aimbot_Prediction",
}):AddKeybind({
	Default = false,
	Idx = "aimbot_Prediction_Key",
	SyncToggleState = true,
})
Toggles.aimbot_Prediction:OnChanged(function()
	AimbotSettings.PredictionEnabled = Toggles.aimbot_Prediction.Value
end)

AimbotGroup:AddToggle({
	Text = "Smoothing",
	Default = AimbotSettings.SmoothingEnabled,
	Idx = "aimbot_SmoothingEnabled",
})
Toggles.aimbot_SmoothingEnabled:OnChanged(function()
	AimbotSettings.SmoothingEnabled = Toggles.aimbot_SmoothingEnabled.Value
end)

AimbotGroup:AddToggle({
	Text = "Wall Check",
	Default = AimbotSettings.WallCheck,
	Idx = "aimbot_WallCheck",
}):AddKeybind({
	Default = false,
	Idx = "aimbot_WallCheck_Key",
	SyncToggleState = true,
})
Toggles.aimbot_WallCheck:OnChanged(function()
	AimbotSettings.WallCheck = Toggles.aimbot_WallCheck.Value
end)

AimbotGroup:AddToggle({
	Text = "Team Check",
	Default = AimbotSettings.TeamCheck,
	Idx = "aimbot_TeamCheck",
})
Toggles.aimbot_TeamCheck:OnChanged(function()
	AimbotSettings.TeamCheck = Toggles.aimbot_TeamCheck.Value
end)

local _aimbotFovVis = AimbotGroup:AddToggle({
	Text = "Show Aimbot FOV",
	Default = AimbotSettings.FOVCircleVisible,
	Idx = "aimbot_FOVCircleVisible",
})
if typeof(_aimbotFovVis.AddColorPicker) == "function" then
	_aimbotFovVis:AddColorPicker({
		Default = Color3.fromRGB(255, 255, 255),
		Idx = "aimbot_FOVCircleColor",
	})
else
	AimbotGroup:AddColorPicker({
		Text = "Aimbot FOV color",
		Default = Color3.fromRGB(255, 255, 255),
		Idx = "aimbot_FOVCircleColor",
	})
end
Toggles.aimbot_FOVCircleVisible:OnChanged(function()
	AimbotSettings.FOVCircleVisible = Toggles.aimbot_FOVCircleVisible.Value
end)
Options.aimbot_FOVCircleColor:OnChanged(function()
	local c = Options.aimbot_FOVCircleColor.Value
	AimbotSettings.FovColor = c
	if aimbot_fov_circle then
		aimbot_fov_circle.Color = c
	end
end)

AimbotGroup:AddSlider({
	Text = "Aimbot FOV (px)",
	Min = 20,
	Max = 400,
	Rounding = 0,
	Default = AimbotSettings.Fov,
	Idx = "aimbot_FOV",
})
Options.aimbot_FOV:OnChanged(function()
	local r = Options.aimbot_FOV.Value
	AimbotSettings.Fov = r
	if aimbot_fov_circle then
		aimbot_fov_circle.Radius = r
	end
end)

AimbotGroup:AddSlider({
	Text = "Prediction (s)",
	Min = 0,
	Max = 0.25,
	Rounding = 3,
	Default = AimbotSettings.PredictionAmount,
	Idx = "aimbot_PredictionAmount",
})
Options.aimbot_PredictionAmount:OnChanged(function()
	AimbotSettings.PredictionAmount = Options.aimbot_PredictionAmount.Value
end)

AimbotGroup:AddSlider({
	Text = "Smoothing",
	Min = 0,
	Max = 1,
	Rounding = 2,
	Default = AimbotSettings.Smoothing,
	Idx = "aimbot_Smoothing",
})
Options.aimbot_Smoothing:OnChanged(function()
	AimbotSettings.Smoothing = Options.aimbot_Smoothing.Value
end)

AimbotGroup:AddDropdown({
	Text = "Aim Part",
	Options = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" },
	Default = AimbotSettings.AimPart,
	Idx = "aimbot_AimPart",
})
Options.aimbot_AimPart:OnChanged(function()
	AimbotSettings.AimPart = Options.aimbot_AimPart.Value
end)

AimbotGroup:AddDropdown({
	Text = "Aim Key",
	Options = { "MouseButton2", "X" },
	Default = AimbotSettings.KeyName,
	Idx = "aimbot_ActivateKey",
})
local function syncAimbotActivateKey()
	local name = Options.aimbot_ActivateKey.Value
	if name and aimbotActivateKeyMap[name] then
		AimbotSettings.KeyName = name
		AimbotSettings.Key = aimbotActivateKeyMap[name]
	end
end
Options.aimbot_ActivateKey:OnChanged(syncAimbotActivateKey)
syncAimbotActivateKey()

if Options.aimbot_FOV and Options.aimbot_FOV.Value and aimbot_fov_circle then
	aimbot_fov_circle.Radius = Options.aimbot_FOV.Value
end
if Options.aimbot_FOVCircleColor and Options.aimbot_FOVCircleColor.Value and aimbot_fov_circle then
	aimbot_fov_circle.Color = Options.aimbot_FOVCircleColor.Value
	AimbotSettings.FovColor = Options.aimbot_FOVCircleColor.Value
end

local silentAimAndAimbotRenderConn

local oldNamecall
if typeof(hookmetamethod) == "function" and typeof(newcclosure) == "function" and typeof(getnamecallmethod) == "function" and typeof(checkcaller) == "function" then
	oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
		if checkcaller() then
			return oldNamecall(...)
		end
		local Method = getnamecallmethod()
		local Arguments = { ... }
		local self = Arguments[1]
		if not Toggles.aim_Enabled.Value or self ~= Workspace then
			return oldNamecall(...)
		end
		local hc = SilentAimSettings.HitChance
		if hc < 100 and not CalculateChance(hc) then
			return oldNamecall(...)
		end
		if Method == "Raycast" then
			if not validateRaycastArgs(Arguments) and not ValidateArguments(Arguments, ExpectedArguments.Raycast) then
				return oldNamecall(...)
			end
			local A_Origin = Arguments[2]
			local A_Direction = Arguments[3]

			if not shouldRedirectRaycast(A_Origin, A_Direction) then
				return oldNamecall(...)
			end

			local HitPart = getClosestPlayer()
			if HitPart then
				Arguments[3] = getDirection(A_Origin, HitPart.Position)
				return oldNamecall(unpack(Arguments))
			end
		end
		return oldNamecall(...)
	end))
else
	warn("[AcidHub] Silent Aim: namecall hook unavailable in this environment")
end

silentAimAndAimbotRenderConn = RunService.RenderStepped:Connect(function()
	local cursor = getMousePosition()
	if Toggles.Visible.Value and fov_circle then
		fov_circle.Visible = true
		local col = Options.Color and Options.Color.Value
		if col then
			fov_circle.Color = col
		end
		fov_circle.Position = cursor
	elseif fov_circle then
		fov_circle.Visible = false
	end

	if aimbot_fov_circle then
		aimbot_fov_circle.Position = cursor
		aimbot_fov_circle.Radius = AimbotSettings.Fov
		aimbot_fov_circle.Color = AimbotSettings.FovColor
		aimbot_fov_circle.Visible = AimbotSettings.FOVCircleVisible and AimbotSettings.Enabled
	end

	if AimbotSettings.Enabled and aimbotKeyHeld() then
		local t = aimbotGetTarget()
		if t then
			local vel = (AimbotSettings.PredictionEnabled and t.AssemblyLinearVelocity) or Vector3.zero
			local ap = t.Position + vel * AimbotSettings.PredictionAmount
			aimbotMoveMouseTowardWorld(ap)
		end
	end
end)

Rivals_UnloadWeaponMods = function()
	local R = genv.RivalsWeaponMods
	if not R then
		return
	end
	local GunModule = R.GunModule
	if GunModule then
		if R.OriginalStartShooting then
			GunModule.StartShooting = R.OriginalStartShooting
		end
		if R.OriginalRecoil then
			GunModule._Recoil = R.OriginalRecoil
		end
		if R.OriginalStartAiming then
			GunModule.StartAiming = R.OriginalStartAiming
		end
		if R.OriginalGetAimSpeed then
			GunModule.GetAimSpeed = R.OriginalGetAimSpeed
		end
		if R.OriginalLocalTracers then
			GunModule._LocalTracers = R.OriginalLocalTracers
		end
	end
	local GameplayUtility = R.GameplayUtility
	if GameplayUtility and R.OriginalGetSpread then
		GameplayUtility.GetSpread = R.OriginalGetSpread
	end
	local ViewModelModule = R.ViewModelModule
	if ViewModelModule and R.OriginalViewModelNew then
		ViewModelModule.new = R.OriginalViewModelNew
	end
	genv.RivalsWeaponMods = nil
end

Rivals_UnloadSilentAim = function()
	Rivals_UnloadWeaponMods()
	if silentAimAndAimbotRenderConn then
		silentAimAndAimbotRenderConn:Disconnect()
		silentAimAndAimbotRenderConn = nil
	end
	pcall(function()
		if aimbot_fov_circle then
			aimbot_fov_circle:Remove()
		end
	end)
	if oldNamecall and typeof(hookmetamethod) == "function" then
		pcall(function()
			hookmetamethod(game, "__namecall", oldNamecall)
		end)
	end
end
end

-- §09b MAIN — Teleport & Movement -------------------------------------------
local Rivals_UnloadMovement
do
local movementCameraFlightCF
local movCharacter
local movRoot
local movHumanoid

local MovementSettings = {
	flightConnection = nil,
	speedConnection = nil,
	infJumpConnection = nil,
	noclipConnection = nil,
	noclipOriginalCollisions = {},
	FlightSpeed = 50,
	WalkSpeed = 16,
}

local function movGetCharacterReferences()
	local currentCharacter = player.Character
	if not currentCharacter or not currentCharacter.Parent then
		movCharacter, movRoot, movHumanoid = nil, nil, nil
		movementCameraFlightCF = nil
		return nil, nil, nil
	end
	if movCharacter ~= currentCharacter then
		movCharacter = currentCharacter
		movRoot = nil
		movHumanoid = nil
		movementCameraFlightCF = nil
	end
	if not movRoot or movRoot.Parent ~= movCharacter then
		movRoot = movCharacter:FindFirstChild("HumanoidRootPart")
	end
	if not movHumanoid or movHumanoid.Parent ~= movCharacter then
		movHumanoid = movCharacter:FindFirstChildOfClass("Humanoid")
	end
	return movCharacter, movRoot, movHumanoid
end

local function movFlightStep(dt)
	local _, currentRoot, currentHumanoid = movGetCharacterReferences()
	if not (currentRoot and currentHumanoid) then
		return
	end
	if not movementCameraFlightCF then
		movementCameraFlightCF = CFrame.new(currentRoot.CFrame.Position)
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camCF = cam.CFrame
	local speed = MovementSettings.FlightSpeed
	local force = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		force += camCF.LookVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		force -= camCF.LookVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		force -= camCF.RightVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		force += camCF.RightVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		force += camCF.UpVector * speed
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		force -= camCF.UpVector * speed
	end
	force *= dt
	movementCameraFlightCF = movementCameraFlightCF * CFrame.new(force)
	currentRoot.CFrame = CFrame.lookAt(
		movementCameraFlightCF.Position,
		camCF.Position + camCF.LookVector * 10000
	)
	currentRoot.AssemblyLinearVelocity = Vector3.zero
end

local function movTpWalkStep(dt)
	local currentCharacter, _, currentHumanoid = movGetCharacterReferences()
	if not (currentCharacter and currentHumanoid) then
		return
	end
	if currentHumanoid.MoveDirection.Magnitude > 0 then
		local speedMultiplier = MovementSettings.WalkSpeed / 16
		currentCharacter:TranslateBy(currentHumanoid.MoveDirection * speedMultiplier * dt * 10)
	end
end

local function movSetPartCollisions(enabled)
	local currentCharacter = movGetCharacterReferences()
	if not currentCharacter then
		return
	end
	for _, part in ipairs(currentCharacter:GetDescendants()) do
		if part:IsA("BasePart") then
			if not enabled then
				if MovementSettings.noclipOriginalCollisions[part] == nil then
					MovementSettings.noclipOriginalCollisions[part] = part.CanCollide
				end
				part.CanCollide = false
			else
				local originalState = MovementSettings.noclipOriginalCollisions[part]
				if originalState ~= nil then
					part.CanCollide = originalState
					MovementSettings.noclipOriginalCollisions[part] = nil
				else
					part.CanCollide = true
				end
			end
		end
	end
end

local function movToggleNoclip(enabled)
	if MovementSettings.noclipConnection then
		MovementSettings.noclipConnection:Disconnect()
		MovementSettings.noclipConnection = nil
	end
	if enabled then
		movSetPartCollisions(false)
		MovementSettings.noclipConnection = RunService.Heartbeat:Connect(function()
			local currentCharacter = movGetCharacterReferences()
			if not currentCharacter then
				return
			end
			for _, part in ipairs(currentCharacter:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					if MovementSettings.noclipOriginalCollisions[part] == nil then
						MovementSettings.noclipOriginalCollisions[part] = true
					end
					part.CanCollide = false
				end
			end
		end)
	else
		movSetPartCollisions(true)
	end
end

local function rivBuildTeleportNames()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player then
			table.insert(list, pl.Name)
		end
	end
	table.sort(list)
	if #list == 0 then
		table.insert(list, "(No other players)")
	end
	return list
end

local function rivRefreshTeleportDropdown()
	if not Options.teleport_target then
		return
	end
	local opts = rivBuildTeleportNames()
	local prev = Options.teleport_target.Value
	Options.teleport_target:SetValues(opts)
	if prev and table.find(opts, prev) then
		Options.teleport_target:SetValue(prev)
	end
end

local MovementGroup = Tabs.Main:AddRightGroupbox("Movement", { Icon = "person-standing", DefaultExpanded = true })

MovementGroup:AddToggle({
	Text = "Flight",
	Default = false,
	Idx = "mov_Flight",
})
Toggles.mov_Flight:OnChanged(function(v)
	if MovementSettings.flightConnection then
		MovementSettings.flightConnection:Disconnect()
		MovementSettings.flightConnection = nil
	end
	movementCameraFlightCF = nil
	if v then
		MovementSettings.flightConnection = RunService.Heartbeat:Connect(movFlightStep)
	end
end)

MovementGroup:AddToggle({
	Text = "Walk speed",
	Default = false,
	Idx = "mov_WalkSpeed",
})
Toggles.mov_WalkSpeed:OnChanged(function(v)
	if MovementSettings.speedConnection then
		MovementSettings.speedConnection:Disconnect()
		MovementSettings.speedConnection = nil
	end
	if v then
		MovementSettings.speedConnection = RunService.Heartbeat:Connect(movTpWalkStep)
	end
end)

MovementGroup:AddToggle({
	Text = "Inf Jump",
	Default = false,
	Idx = "mov_InfJump",
})
Toggles.mov_InfJump:OnChanged(function(v)
	if MovementSettings.infJumpConnection then
		MovementSettings.infJumpConnection:Disconnect()
		MovementSettings.infJumpConnection = nil
	end
	if v then
		MovementSettings.infJumpConnection = UserInputService.JumpRequest:Connect(function()
			local _, _, hum = movGetCharacterReferences()
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end
end)

MovementGroup:AddToggle({
	Text = "Noclip",
	Default = false,
	Idx = "mov_Noclip",
})
Toggles.mov_Noclip:OnChanged(function(v)
	movToggleNoclip(v)
end)

MovementGroup:AddSlider({
	Text = "Flight speed",
	Min = 0,
	Max = 500,
	Default = MovementSettings.FlightSpeed,
	Rounding = 0,
	Idx = "mov_FlightSpeed",
})
Options.mov_FlightSpeed:OnChanged(function()
	MovementSettings.FlightSpeed = Options.mov_FlightSpeed.Value
end)

MovementGroup:AddSlider({
	Text = "Speed value",
	Min = 0,
	Max = 500,
	Default = MovementSettings.WalkSpeed,
	Rounding = 0,
	Idx = "mov_WalkSpeedVal",
})
Options.mov_WalkSpeedVal:OnChanged(function()
	MovementSettings.WalkSpeed = Options.mov_WalkSpeedVal.Value
end)

if Options.mov_FlightSpeed and Options.mov_FlightSpeed.Value then
	MovementSettings.FlightSpeed = Options.mov_FlightSpeed.Value
end
if Options.mov_WalkSpeedVal and Options.mov_WalkSpeedVal.Value then
	MovementSettings.WalkSpeed = Options.mov_WalkSpeedVal.Value
end

local TELEPORT_COOLDOWN_SEC = 1
local rivTeleportLastAt = 0
local teleportBehindConn = nil

local function rivApplyBehindSelectedTarget()
	local name = Options.teleport_target and Options.teleport_target.Value
	if not name or name == "(No other players)" then
		return false
	end
	local targetPlr = Players:FindFirstChild(name)
	if not targetPlr or not targetPlr:IsA("Player") or targetPlr == player then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local tChar = targetPlr.Character
	local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
	if not (hrp and tHrp) then
		return false
	end
	local look = tHrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.05 then
		flat = flat.Unit
	else
		flat = look.Unit
	end
	local backOffset = 5
	-- Same vertical level as target (no +Y); avoids floating above them when going "behind"
	local pos = tHrp.Position - flat * backOffset
	hrp.CFrame = CFrame.lookAt(pos, tHrp.Position)
	hrp.AssemblyLinearVelocity = Vector3.zero
	return true
end

local TeleportGroup = Tabs.Main:AddRightGroupbox("Teleport", { Icon = "map-pin", DefaultExpanded = true })
TeleportGroup:AddDropdown({
	Text = "Player",
	Options = rivBuildTeleportNames(),
	Default = 1,
	Searchable = true,
	Idx = "teleport_target",
})
TeleportGroup:AddButton({
	Text = "Teleport to player",
	Func = function()
		local name = Options.teleport_target and Options.teleport_target.Value
		if not name or name == "(No other players)" then
			return
		end
		local targetPlr = Players:FindFirstChild(name)
		if not targetPlr or not targetPlr:IsA("Player") or targetPlr == player then
			return
		end
		local now = tick()
		local since = now - rivTeleportLastAt
		if since < TELEPORT_COOLDOWN_SEC then
			task.wait(TELEPORT_COOLDOWN_SEC - since)
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local tChar = targetPlr.Character
		local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
		if not (hrp and tHrp) then
			return
		end
		local behind = Toggles.teleport_behind and Toggles.teleport_behind.Value
		if behind then
			rivApplyBehindSelectedTarget()
		else
			hrp.CFrame = tHrp.CFrame + Vector3.new(0, 2.5, 0)
		end
		rivTeleportLastAt = tick()
	end,
})
TeleportGroup:AddToggle({
	Text = "Teleport to player",
	Default = false,
	Idx = "teleport_behind",
})
Toggles.teleport_behind:OnChanged(function(v)
	if teleportBehindConn then
		teleportBehindConn:Disconnect()
		teleportBehindConn = nil
	end
	if v then
		teleportBehindConn = RunService.Heartbeat:Connect(function()
			rivApplyBehindSelectedTarget()
		end)
	end
end)

local teleportListConns = {}
table.insert(
	teleportListConns,
	Players.PlayerAdded:Connect(function()
		task.defer(rivRefreshTeleportDropdown)
	end)
)
	table.insert(
	teleportListConns,
	Players.PlayerRemoving:Connect(function()
		task.defer(rivRefreshTeleportDropdown)
	end)
)

Rivals_UnloadMovement = function()
	if teleportBehindConn then
		teleportBehindConn:Disconnect()
		teleportBehindConn = nil
	end
	for _, c in ipairs(teleportListConns) do
		if c then
			c:Disconnect()
		end
	end
	table.clear(teleportListConns)
	if MovementSettings.flightConnection then
		MovementSettings.flightConnection:Disconnect()
		MovementSettings.flightConnection = nil
	end
	if MovementSettings.speedConnection then
		MovementSettings.speedConnection:Disconnect()
		MovementSettings.speedConnection = nil
	end
	if MovementSettings.infJumpConnection then
		MovementSettings.infJumpConnection:Disconnect()
		MovementSettings.infJumpConnection = nil
	end
	if MovementSettings.noclipConnection then
		MovementSettings.noclipConnection:Disconnect()
		MovementSettings.noclipConnection = nil
	end
	for part, state in pairs(MovementSettings.noclipOriginalCollisions) do
		pcall(function()
			if part and part.Parent then
				part.CanCollide = state
			end
		end)
	end
	table.clear(MovementSettings.noclipOriginalCollisions)
	movementCameraFlightCF = nil
	movCharacter = nil
	movRoot = nil
	movHumanoid = nil
end
end

-- §10 VISUALS TAB — ESP (world + Drawing overlays) --------------------------
local Rivals_UnloadESP
do
local ESPSettings = {
	Box = { Enabled = false, BoxColor = Color3.fromRGB(75, 0, 10), TeamColor = Color3.fromRGB(0, 255, 0) },
	Names = { Enabled = false, Color = Color3.fromRGB(255, 255, 255), TeamColor = Color3.fromRGB(0, 255, 0) },
	Distance = { Enabled = false, Color = Color3.fromRGB(255, 255, 255), TeamColor = Color3.fromRGB(0, 255, 0) },
	Health = { Enabled = false, Type = "Both", Color = Color3.fromRGB(255, 255, 255), TeamColor = Color3.fromRGB(0, 255, 0) },
	Tracers = {
		Enabled = false,
		Origin = "Top",
		Visibility = "On Screen Only",
		Color = Color3.fromRGB(255, 255, 255),
		TeamColor = Color3.fromRGB(0, 255, 0),
		Thickness = 1,
	},
	Skeleton = { Enabled = false, Color = Color3.fromRGB(255, 255, 255), TeamColor = Color3.fromRGB(0, 255, 0), Thickness = 2 },
	Chams = {
		Enabled = false,
		FillColor = Color3.fromRGB(75, 0, 10),
		OutlineColor = Color3.fromRGB(0, 0, 0),
		TeamFillColor = Color3.fromRGB(0, 255, 0),
		TeamOutlineColor = Color3.fromRGB(0, 255, 0),
	},
	TeamCheck = false,
}

local isCustomCharacterSystem = (getgenv and getgenv().characters) ~= nil
local ESPObjects = {}
local espHeartbeatConn

local BoxESPGui = Instance.new("ScreenGui")
BoxESPGui.Name = "AcidHubESP"
BoxESPGui.ResetOnSpawn = false
BoxESPGui.Parent = player:WaitForChild("PlayerGui")

local HighlightGui = Instance.new("ScreenGui")
HighlightGui.Name = "AcidHubChams"
HighlightGui.ResetOnSpawn = false
HighlightGui.Parent = player:WaitForChild("PlayerGui")

local function GetAllCharactersESP()
	local all = {}
	if isCustomCharacterSystem and getgenv().characters then
		for playerName, characterData in pairs(getgenv().characters) do
			if characterData and characterData.character then
				table.insert(all, {
					name = playerName,
					character = characterData.character,
					player = characterData.player,
					team = characterData.team,
				})
			end
		end
	else
		for _, plr in pairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then
				table.insert(all, { name = plr.Name, character = plr.Character, player = plr, team = plr.Team })
			end
		end
	end
	return all
end

local r15Skel = {
	{ "HumanoidRootPart", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "UpperTorso", "Head" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local r6Skel = {
	{ "HumanoidRootPart", "Torso" }, { "Torso", "Head" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function CreateTracerESP(characterData)
	local line
	if Drawing and Drawing.new then
		line = Drawing.new("Line")
		line.Visible = false
		line.Thickness = ESPSettings.Tracers.Thickness
		line.Transparency = 1
		line.Color = ESPSettings.Tracers.Color
	end
	local pl = characterData.player or Players:FindFirstChild(characterData.name)
	if not pl then return end
	ESPObjects[pl] = ESPObjects[pl] or {}
	ESPObjects[pl].TracerLine = line
end

local function CreateSkeletonESP(characterData)
	local maxL = math.max(#r15Skel, #r6Skel)
	local boneLines = {}
	for i = 1, maxL do
		if Drawing and Drawing.new then
			local ln = Drawing.new("Line")
			ln.Visible = false
			ln.Thickness = ESPSettings.Skeleton.Thickness
			ln.Transparency = 1
			boneLines[i] = { line = ln, from = "", to = "" }
		end
	end
	local pl = characterData.player or Players:FindFirstChild(characterData.name)
	if not pl then return end
	ESPObjects[pl] = ESPObjects[pl] or {}
	ESPObjects[pl].SkeletonLines = boneLines
	ESPObjects[pl].R15Connections = r15Skel
	ESPObjects[pl].R6Connections = r6Skel
end

local function CreateBoxESP(characterData)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = characterData.name
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(4, 0, 5.4, 0)
	billboard.ClipsDescendants = false
	billboard.Enabled = false
	billboard.LightInfluence = 0
	billboard.SizeOffset = Vector2.new(0, 0)
	billboard.Parent = BoxESPGui
	local outlines = Instance.new("Frame")
	outlines.Size = UDim2.new(1, 0, 1, 0)
	outlines.BorderSizePixel = 1
	outlines.BackgroundTransparency = 1
	outlines.Parent = billboard
	local left = Instance.new("Frame")
	left.BorderSizePixel = 1
	left.Size = UDim2.new(0, 1, 1, 0)
	left.Parent = outlines
	local right = left:Clone()
	right.Parent = outlines
	right.Size = UDim2.new(0, -1, 1, 0)
	right.Position = UDim2.new(1, 0, 0, 0)
	local up = left:Clone()
	up.Parent = outlines
	up.Size = UDim2.new(1, 0, 0, 1)
	local down = left:Clone()
	down.Parent = outlines
	down.Size = UDim2.new(1, 0, 0, -1)
	down.Position = UDim2.new(0, 0, 1, 0)
	local pl = characterData.player or Players:FindFirstChild(characterData.name)
	if not pl then return end
	ESPObjects[pl] = ESPObjects[pl] or {}
	ESPObjects[pl].Billboard = billboard
	ESPObjects[pl].Elements = { Outlines = outlines, Left = left, Right = right, Up = up, Down = down }
end

local function CreateChamsESP(characterData)
	local pl = characterData.player or Players:FindFirstChild(characterData.name)
	if not pl then
		return
	end
	ESPObjects[pl] = ESPObjects[pl] or {}
	local highlight = Instance.new("Highlight")
	highlight.Name = pl.Name
	highlight.Parent = HighlightGui
	highlight.Enabled = false
	if pl.Character then
		highlight.Adornee = pl.Character
	end
	local charAddedConn = pl.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		local data = ESPObjects[pl]
		if data and data.Highlight then
			data.Highlight.Adornee = char
		end
	end)
	ESPObjects[pl].Highlight = highlight
	ESPObjects[pl].ChamsCharAddedConnection = charAddedConn
end

local function CreateNameESP(characterData)
	local nameText
	if Drawing and Drawing.new then
		nameText = Drawing.new("Text")
		nameText.Text = characterData.name
		nameText.Size = 13
		nameText.Center = true
		nameText.Outline = true
		nameText.OutlineColor = Color3.fromRGB(0, 0, 0)
		nameText.Color = ESPSettings.Names.Color
		nameText.Font = 0
		nameText.Visible = false
	end
	local pl = characterData.player or Players:FindFirstChild(characterData.name)
	if not pl then return end
	ESPObjects[pl] = ESPObjects[pl] or {}
	ESPObjects[pl].NameText = nameText
end

local function CreateDistanceESP(characterData)
	local distanceText
	if Drawing and Drawing.new then
		distanceText = Drawing.new("Text")
		distanceText.Text = "0m"
		distanceText.Size = 12
		distanceText.Center = true
		distanceText.Outline = true
		distanceText.OutlineColor = Color3.fromRGB(0, 0, 0)
		distanceText.Color = ESPSettings.Distance.Color
		distanceText.Font = 2
		distanceText.Visible = false
	end
	local pl = characterData.player or Players:FindFirstChild(characterData.name)
	if not pl then return end
	ESPObjects[pl] = ESPObjects[pl] or {}
	ESPObjects[pl].DistanceText = distanceText
end

local function CreateHealthESP(characterData)
	local healthText
	if Drawing and Drawing.new then
		healthText = Drawing.new("Text")
		healthText.Text = "100"
		healthText.Size = 12
		healthText.Center = true
		healthText.Outline = true
		healthText.OutlineColor = Color3.fromRGB(0, 0, 0)
		healthText.Color = ESPSettings.Health.Color
		healthText.Font = 0
		healthText.Visible = false
	end
	local healthBarGui = Instance.new("BillboardGui")
	healthBarGui.Name = characterData.name .. "_health"
	healthBarGui.Size = UDim2.new(4.5, 0, 6, 0)
	healthBarGui.AlwaysOnTop = true
	healthBarGui.ClipsDescendants = false
	healthBarGui.Enabled = false
	healthBarGui.LightInfluence = 0
	healthBarGui.SizeOffset = Vector2.new(0, 0)
	healthBarGui.Parent = BoxESPGui
	local healthBar = Instance.new("Frame")
	healthBar.Name = "healthbar"
	healthBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	healthBar.BorderColor3 = Color3.fromRGB(0, 0, 0)
	healthBar.Size = UDim2.new(0.04, 0, 0.9, 0)
	healthBar.Position = UDim2.new(0, 0, 0.05, 0)
	healthBar.Parent = healthBarGui
	local bar = Instance.new("Frame")
	bar.Name = "bar"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = Color3.fromRGB(94, 255, 69)
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 0, 1, 0)
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.Parent = healthBar
	local pl = characterData.player or Players:FindFirstChild(characterData.name)
	if not pl then return end
	ESPObjects[pl] = ESPObjects[pl] or {}
	ESPObjects[pl].HealthBarGui = healthBarGui
	ESPObjects[pl].HealthText = healthText
	ESPObjects[pl].HealthBar = healthBar
	ESPObjects[pl].Bar = bar
end

local function spawnESPForCharacterData(cd)
	CreateBoxESP(cd)
	CreateChamsESP(cd)
	CreateNameESP(cd)
	CreateDistanceESP(cd)
	CreateHealthESP(cd)
	CreateTracerESP(cd)
	CreateSkeletonESP(cd)
end

local function UpdateESP()
	local Camera = Workspace.CurrentCamera
	if not Camera then return end
	for plr, espData in pairs(ESPObjects) do
		if not Players:FindFirstChild(plr.Name) then
			if espData.Billboard then espData.Billboard:Destroy() end
			if espData.NameText then pcall(function() espData.NameText:Remove() end) end
			if espData.DistanceText then pcall(function() espData.DistanceText:Remove() end) end
			if espData.HealthBarGui then espData.HealthBarGui:Destroy() end
			if espData.HealthText then pcall(function() espData.HealthText:Remove() end) end
			if espData.TracerLine then pcall(function() espData.TracerLine:Remove() end) end
			if espData.SkeletonLines then
				for _, bd in ipairs(espData.SkeletonLines) do
					if bd and bd.line then pcall(function() bd.line:Remove() end) end
				end
			end
			if espData.Highlight then
				espData.Highlight:Destroy()
			end
			if espData.ChamsCharAddedConnection then
				espData.ChamsCharAddedConnection:Disconnect()
			end
			ESPObjects[plr] = nil
			continue
		end
		local character = plr.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChild("Humanoid")
		local alive = hum and hum.Health > 0
		local isTeammate = ESPSettings.TeamCheck and plr.Team and player.Team and plr.Team == player.Team
		local dist = 0
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and hrp then
			dist = (player.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
		end
		if espData.Billboard and espData.Elements and ESPSettings.Box.Enabled then
			if character and hrp and alive and not isTeammate then
				espData.Billboard.Adornee = hrp
				espData.Billboard.Enabled = true
				espData.Elements.Outlines.Visible = true
				local col = (plr.Team and player.Team and plr.Team == player.Team) and ESPSettings.Box.TeamColor or ESPSettings.Box.BoxColor
				espData.Elements.Left.BackgroundColor3 = col
				espData.Elements.Right.BackgroundColor3 = col
				espData.Elements.Up.BackgroundColor3 = col
				espData.Elements.Down.BackgroundColor3 = col
			else
				espData.Billboard.Enabled = false
			end
		elseif espData.Billboard then
			espData.Billboard.Enabled = false
		end
		if espData.NameText and ESPSettings.Names.Enabled then
			if character and hrp and alive and not isTeammate then
				local sp, onScr = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 4, 0))
				if onScr then
					espData.NameText.Position = Vector2.new(sp.X, sp.Y)
					espData.NameText.Color = (plr.Team and player.Team and plr.Team == player.Team) and ESPSettings.Names.TeamColor or ESPSettings.Names.Color
					espData.NameText.Visible = true
				else
					espData.NameText.Visible = false
				end
			else
				espData.NameText.Visible = false
			end
		elseif espData.NameText then
			espData.NameText.Visible = false
		end
		if espData.DistanceText and ESPSettings.Distance.Enabled then
			if character and hrp and alive and not isTeammate then
				local sp, onScr = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, -3.5, 0))
				if onScr then
					espData.DistanceText.Position = Vector2.new(sp.X, sp.Y)
					espData.DistanceText.Text = tostring(math.floor(dist + 0.5)) .. "m"
					espData.DistanceText.Color = (plr.Team and player.Team and plr.Team == player.Team) and ESPSettings.Distance.TeamColor or ESPSettings.Distance.Color
					espData.DistanceText.Visible = true
				else
					espData.DistanceText.Visible = false
				end
			else
				espData.DistanceText.Visible = false
			end
		elseif espData.DistanceText then
			espData.DistanceText.Visible = false
		end
		if ESPSettings.Health.Enabled and character and hrp and hum and alive and not isTeammate then
			local hp, maxHp = hum.Health, hum.MaxHealth
			local pct = hp / maxHp
			local hcol = (plr.Team and player.Team and plr.Team == player.Team) and ESPSettings.Health.TeamColor or ESPSettings.Health.Color
			if espData.HealthBarGui and espData.Bar and (ESPSettings.Health.Type == "Bar" or ESPSettings.Health.Type == "Both") then
				espData.HealthBarGui.Adornee = hrp
				espData.HealthBarGui.Enabled = true
				espData.Bar.Size = UDim2.new(1, 0, pct, 0)
				if pct > 0.75 then espData.Bar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
				elseif pct >= 0.5 then espData.Bar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
				elseif pct >= 0.25 then espData.Bar.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
				else espData.Bar.BackgroundColor3 = Color3.fromRGB(255, 0, 0) end
			elseif espData.HealthBarGui then
				espData.HealthBarGui.Enabled = false
			end
			if espData.HealthText and (ESPSettings.Health.Type == "Text" or ESPSettings.Health.Type == "Both") then
				local sp, onScr = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.2, 0))
				if onScr then
					espData.HealthText.Position = Vector2.new(sp.X, sp.Y)
					espData.HealthText.Text = tostring(math.floor(hp)) .. "/" .. tostring(math.floor(maxHp))
					espData.HealthText.Color = hcol
					espData.HealthText.Visible = true
				else
					espData.HealthText.Visible = false
				end
			elseif espData.HealthText then
				espData.HealthText.Visible = false
			end
		else
			if espData.HealthBarGui then espData.HealthBarGui.Enabled = false end
			if espData.HealthText then espData.HealthText.Visible = false end
		end
		if espData.TracerLine then
			if character and hrp and alive and ESPSettings.Tracers.Enabled and not isTeammate then
				local hrpPos, onScr = Camera:WorldToViewportPoint(hrp.Position)
				local show = true
				local toPos = Vector2.new(hrpPos.X, hrpPos.Y)
				if ESPSettings.Tracers.Visibility == "On Screen Only" then
					show = onScr
				elseif ESPSettings.Tracers.Visibility == "Everywhere" and not onScr then
					local vs = Camera.ViewportSize
					local m = 50
					toPos = Vector2.new(math.clamp(hrpPos.X, m, vs.X - m), math.clamp(hrpPos.Y, m, vs.Y - m))
				end
				if show then
					local fromPos
					if ESPSettings.Tracers.Origin == "Top" then
						fromPos = Vector2.new(Camera.ViewportSize.X / 2, 0)
					elseif ESPSettings.Tracers.Origin == "Bottom" then
						fromPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
					else
						local mp = UserInputService:GetMouseLocation()
						fromPos = Vector2.new(mp.X, mp.Y)
					end
					espData.TracerLine.From = fromPos
					espData.TracerLine.To = toPos
					espData.TracerLine.Color = (plr.Team and player.Team and plr.Team == player.Team) and ESPSettings.Tracers.TeamColor or ESPSettings.Tracers.Color
					espData.TracerLine.Thickness = ESPSettings.Tracers.Thickness
					espData.TracerLine.Visible = true
				else
					espData.TracerLine.Visible = false
				end
			else
				espData.TracerLine.Visible = false
			end
		end
		if espData.SkeletonLines then
			if ESPSettings.Skeleton.Enabled and character and hrp and alive and not isTeammate then
				local isR15 = character:FindFirstChild("UpperTorso") ~= nil
				local conns = isR15 and espData.R15Connections or espData.R6Connections
				local skCol = (plr.Team and player.Team and plr.Team == player.Team) and ESPSettings.Skeleton.TeamColor or ESPSettings.Skeleton.Color
				for i, conn in ipairs(conns) do
					local bd = espData.SkeletonLines[i]
					if bd and bd.line then bd.from = conn[1]; bd.to = conn[2] end
				end
				for i, bd in ipairs(espData.SkeletonLines) do
					if bd and bd.line and bd.from ~= "" and bd.to ~= "" then
						local fp = character:FindFirstChild(bd.from)
						local tp = character:FindFirstChild(bd.to)
						if fp and tp then
							local fv, fo = Camera:WorldToViewportPoint(fp.Position)
							local tv, to = Camera:WorldToViewportPoint(tp.Position)
							if fo and to then
								bd.line.From = Vector2.new(fv.X, fv.Y)
								bd.line.To = Vector2.new(tv.X, tv.Y)
								bd.line.Color = skCol
								bd.line.Thickness = ESPSettings.Skeleton.Thickness
								bd.line.Visible = true
							else
								bd.line.Visible = false
							end
						else
							bd.line.Visible = false
						end
					elseif bd and bd.line then
						bd.line.Visible = false
					end
				end
			else
				for _, bd in ipairs(espData.SkeletonLines) do
					if bd and bd.line then bd.line.Visible = false end
				end
			end
		end
		if espData.Highlight then
			if ESPSettings.Chams.Enabled and character and hrp and hum and alive and not isTeammate then
				espData.Highlight.Enabled = true
				espData.Highlight.Adornee = character
				local sameTeam = plr.Team and player.Team and plr.Team == player.Team
				if sameTeam then
					espData.Highlight.FillColor = ESPSettings.Chams.TeamFillColor
					espData.Highlight.OutlineColor = ESPSettings.Chams.TeamOutlineColor
				else
					espData.Highlight.FillColor = ESPSettings.Chams.FillColor
					espData.Highlight.OutlineColor = ESPSettings.Chams.OutlineColor
				end
				espData.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				espData.Highlight.OutlineTransparency = 0
				espData.Highlight.FillTransparency = 0.5
			else
				espData.Highlight.Enabled = false
			end
		end
	end
end

local function refreshESPAll() end

local ESPGroup = Tabs.Visuals:AddLeftGroupbox("ESP", { Icon = "scan-eye", DefaultExpanded = true })
ESPGroup:AddToggle({ Text = "Tracers", Default = false, Idx = "esp_tracers" })
Toggles.esp_tracers:OnChanged(function(v) ESPSettings.Tracers.Enabled = v end)
ESPGroup:AddToggle({ Text = "Skeleton ESP", Default = false, Idx = "esp_skeleton" })
Toggles.esp_skeleton:OnChanged(function(v) ESPSettings.Skeleton.Enabled = v end)
ESPGroup:AddToggle({ Text = "Box ESP", Default = false, Idx = "esp_box" })
Toggles.esp_box:OnChanged(function(v) ESPSettings.Box.Enabled = v end)
ESPGroup:AddToggle({ Text = "Chams", Default = false, Idx = "esp_chams" })
Toggles.esp_chams:OnChanged(function(v) ESPSettings.Chams.Enabled = v end)
ESPGroup:AddToggle({ Text = "Show Names", Default = false, Idx = "esp_names" })
Toggles.esp_names:OnChanged(function(v) ESPSettings.Names.Enabled = v end)
ESPGroup:AddToggle({ Text = "Show Distance", Default = false, Idx = "esp_distance" })
Toggles.esp_distance:OnChanged(function(v) ESPSettings.Distance.Enabled = v end)
ESPGroup:AddToggle({ Text = "Show Health", Default = false, Idx = "esp_health" })
Toggles.esp_health:OnChanged(function(v) ESPSettings.Health.Enabled = v end)
ESPGroup:AddToggle({ Text = "Team Check", Default = false, Idx = "esp_teamcheck" })
Toggles.esp_teamcheck:OnChanged(function(v) ESPSettings.TeamCheck = v; refreshESPAll() end)
ESPGroup:AddDropdown({ Text = "Tracer origin", Options = { "Top", "Bottom", "Mouse" }, Default = 1, Idx = "esp_tracer_origin" })
Options.esp_tracer_origin:OnChanged(function() ESPSettings.Tracers.Origin = Options.esp_tracer_origin.Value end)
ESPGroup:AddDropdown({ Text = "Tracer visibility", Options = { "Everywhere", "On Screen Only" }, Default = 2, Idx = "esp_tracer_vis" })
Options.esp_tracer_vis:OnChanged(function() ESPSettings.Tracers.Visibility = Options.esp_tracer_vis.Value end)
ESPGroup:AddDropdown({ Text = "Health type", Options = { "Bar", "Text", "Both" }, Default = 3, Idx = "esp_health_type" })
Options.esp_health_type:OnChanged(function() ESPSettings.Health.Type = Options.esp_health_type.Value end)
ESPGroup:AddSlider({ Text = "Skeleton thickness", Min = 1, Max = 5, Default = 2, Rounding = 0, Idx = "esp_skel_thick" })
Options.esp_skel_thick:OnChanged(function() ESPSettings.Skeleton.Thickness = Options.esp_skel_thick.Value end)
ESPGroup:AddSlider({ Text = "Tracer thickness", Min = 1, Max = 5, Default = 1, Rounding = 0, Idx = "esp_trace_thick" })
Options.esp_trace_thick:OnChanged(function() ESPSettings.Tracers.Thickness = Options.esp_trace_thick.Value end)

local ESPColors = Tabs.Visuals:AddRightGroupbox("ESP Colors", { Icon = "palette", DefaultExpanded = true })
ESPColors:AddColorPicker({ Text = "Box color", Default = ESPSettings.Box.BoxColor, Idx = "esp_col_box" })
Options.esp_col_box:OnChanged(function() ESPSettings.Box.BoxColor = Options.esp_col_box.Value end)
ESPColors:AddColorPicker({ Text = "Box team color", Default = ESPSettings.Box.TeamColor, Idx = "esp_col_boxteam" })
Options.esp_col_boxteam:OnChanged(function() ESPSettings.Box.TeamColor = Options.esp_col_boxteam.Value end)
ESPColors:AddColorPicker({ Text = "Skeleton color", Default = ESPSettings.Skeleton.Color, Idx = "esp_col_skel" })
Options.esp_col_skel:OnChanged(function() ESPSettings.Skeleton.Color = Options.esp_col_skel.Value end)
ESPColors:AddColorPicker({ Text = "Skeleton team color", Default = ESPSettings.Skeleton.TeamColor, Idx = "esp_col_skelteam" })
Options.esp_col_skelteam:OnChanged(function() ESPSettings.Skeleton.TeamColor = Options.esp_col_skelteam.Value end)
ESPColors:AddColorPicker({ Text = "Tracer color", Default = ESPSettings.Tracers.Color, Idx = "esp_col_trace" })
Options.esp_col_trace:OnChanged(function() ESPSettings.Tracers.Color = Options.esp_col_trace.Value end)
ESPColors:AddColorPicker({ Text = "Tracer team color", Default = ESPSettings.Tracers.TeamColor, Idx = "esp_col_traceteam" })
Options.esp_col_traceteam:OnChanged(function() ESPSettings.Tracers.TeamColor = Options.esp_col_traceteam.Value end)
ESPColors:AddColorPicker({ Text = "Name color", Default = ESPSettings.Names.Color, Idx = "esp_col_name" })
Options.esp_col_name:OnChanged(function() ESPSettings.Names.Color = Options.esp_col_name.Value end)
ESPColors:AddColorPicker({ Text = "Name team color", Default = ESPSettings.Names.TeamColor, Idx = "esp_col_nameteam" })
Options.esp_col_nameteam:OnChanged(function() ESPSettings.Names.TeamColor = Options.esp_col_nameteam.Value end)
ESPColors:AddColorPicker({ Text = "Distance color", Default = ESPSettings.Distance.Color, Idx = "esp_col_dist" })
Options.esp_col_dist:OnChanged(function() ESPSettings.Distance.Color = Options.esp_col_dist.Value end)
ESPColors:AddColorPicker({ Text = "Distance team color", Default = ESPSettings.Distance.TeamColor, Idx = "esp_col_distteam" })
Options.esp_col_distteam:OnChanged(function() ESPSettings.Distance.TeamColor = Options.esp_col_distteam.Value end)
ESPColors:AddColorPicker({ Text = "Health color", Default = ESPSettings.Health.Color, Idx = "esp_col_hp" })
Options.esp_col_hp:OnChanged(function() ESPSettings.Health.Color = Options.esp_col_hp.Value end)
ESPColors:AddColorPicker({ Text = "Health team color", Default = ESPSettings.Health.TeamColor, Idx = "esp_col_hpteam" })
Options.esp_col_hpteam:OnChanged(function() ESPSettings.Health.TeamColor = Options.esp_col_hpteam.Value end)
ESPColors:AddColorPicker({ Text = "Chams fill", Default = ESPSettings.Chams.FillColor, Idx = "esp_col_chams_fill" })
Options.esp_col_chams_fill:OnChanged(function() ESPSettings.Chams.FillColor = Options.esp_col_chams_fill.Value end)
ESPColors:AddColorPicker({ Text = "Chams outline", Default = ESPSettings.Chams.OutlineColor, Idx = "esp_col_chams_out" })
Options.esp_col_chams_out:OnChanged(function() ESPSettings.Chams.OutlineColor = Options.esp_col_chams_out.Value end)
ESPColors:AddColorPicker({ Text = "Chams team fill", Default = ESPSettings.Chams.TeamFillColor, Idx = "esp_col_chams_tfill" })
Options.esp_col_chams_tfill:OnChanged(function() ESPSettings.Chams.TeamFillColor = Options.esp_col_chams_tfill.Value end)
ESPColors:AddColorPicker({ Text = "Chams team outline", Default = ESPSettings.Chams.TeamOutlineColor, Idx = "esp_col_chams_tout" })
Options.esp_col_chams_tout:OnChanged(function() ESPSettings.Chams.TeamOutlineColor = Options.esp_col_chams_tout.Value end)

for _, plr in pairs(Players:GetPlayers()) do
	if plr ~= player then
		spawnESPForCharacterData({ name = plr.Name, character = plr.Character, player = plr, team = plr.Team })
	end
end
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		spawnESPForCharacterData({ name = plr.Name, character = char, player = plr, team = plr.Team })
	end)
	if plr.Character then
		spawnESPForCharacterData({ name = plr.Name, character = plr.Character, player = plr, team = plr.Team })
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	local espData = ESPObjects[plr]
	if espData then
		if espData.Billboard then espData.Billboard:Destroy() end
		if espData.NameText then pcall(function() espData.NameText:Remove() end) end
		if espData.DistanceText then pcall(function() espData.DistanceText:Remove() end) end
		if espData.HealthBarGui then espData.HealthBarGui:Destroy() end
		if espData.HealthText then pcall(function() espData.HealthText:Remove() end) end
		if espData.TracerLine then pcall(function() espData.TracerLine:Remove() end) end
		if espData.SkeletonLines then
			for _, bd in ipairs(espData.SkeletonLines) do
				if bd and bd.line then pcall(function() bd.line:Remove() end) end
			end
		end
		if espData.Highlight then
			espData.Highlight:Destroy()
		end
		if espData.ChamsCharAddedConnection then
			espData.ChamsCharAddedConnection:Disconnect()
		end
		ESPObjects[plr] = nil
	end
end)

espHeartbeatConn = RunService.Heartbeat:Connect(UpdateESP)

Rivals_UnloadESP = function()
	if espHeartbeatConn then
		espHeartbeatConn:Disconnect()
		espHeartbeatConn = nil
	end
	for _, espData in pairs(ESPObjects) do
		if espData.ChamsCharAddedConnection then
			espData.ChamsCharAddedConnection:Disconnect()
			espData.ChamsCharAddedConnection = nil
		end
	end
	if BoxESPGui then
		BoxESPGui:Destroy()
		BoxESPGui = nil
	end
	if HighlightGui then
		HighlightGui:Destroy()
		HighlightGui = nil
	end
	for _, espData in pairs(ESPObjects) do
		if espData.Billboard then espData.Billboard:Destroy() end
		if espData.NameText then pcall(function() espData.NameText:Remove() end) end
		if espData.DistanceText then pcall(function() espData.DistanceText:Remove() end) end
		if espData.HealthBarGui then espData.HealthBarGui:Destroy() end
		if espData.HealthText then pcall(function() espData.HealthText:Remove() end) end
		if espData.TracerLine then pcall(function() espData.TracerLine:Remove() end) end
		if espData.SkeletonLines then
			for _, bd in ipairs(espData.SkeletonLines) do
				if bd and bd.line then pcall(function() bd.line:Remove() end) end
			end
		end
	end
	for k in pairs(ESPObjects) do
		ESPObjects[k] = nil
	end
end
end

-- §11 COSMETICS TABS — Skins / Wraps / Charms (partitioned weapon lists) -----
do
local guns, melees, throwables, otherWeapons = GetWeaponsPartitioned()
local SkinsGunsGroup = Tabs.Skins:AddLeftGroupbox("Guns", { Icon = "palette", DefaultExpanded = true })
local SkinsMeleeGroup = Tabs.Skins:AddRightGroupbox("Melee", { Icon = "palette", DefaultExpanded = true })
local SkinsThrowGroup = Tabs.Skins:AddRightGroupbox("Throwables", { Icon = "palette", DefaultExpanded = true })
local SkinsOtherGroup = (#otherWeapons > 0) and Tabs.Skins:AddRightGroupbox("Other", { Icon = "palette", DefaultExpanded = true }) or nil

local anySkinRows = false
local nGunSkins, nMeleeSkins, nThrowSkins, nOtherSkins = 0, 0, 0, 0
for _, w in ipairs(guns) do
	if addSkinDropdownForWeapon(w, SkinsGunsGroup) then
		anySkinRows = true
		nGunSkins = nGunSkins + 1
	end
end
if #guns == 0 then
	SkinsGunsGroup:AddLabel("No guns in item list.")
elseif nGunSkins == 0 then
	SkinsGunsGroup:AddLabel("No skins defined for guns in CosmeticLibrary.")
end

for _, w in ipairs(melees) do
	if addSkinDropdownForWeapon(w, SkinsMeleeGroup) then
		anySkinRows = true
		nMeleeSkins = nMeleeSkins + 1
	end
end
if #melees == 0 then
	SkinsMeleeGroup:AddLabel("No melee in item list.")
elseif nMeleeSkins == 0 then
	SkinsMeleeGroup:AddLabel("No skins defined for melee in CosmeticLibrary.")
end

for _, w in ipairs(throwables) do
	if addSkinDropdownForWeapon(w, SkinsThrowGroup) then
		anySkinRows = true
		nThrowSkins = nThrowSkins + 1
	end
end
if #throwables == 0 then
	SkinsThrowGroup:AddLabel("No throwables in item list.")
elseif nThrowSkins == 0 then
	SkinsThrowGroup:AddLabel("No skins defined for throwables.")
end

if SkinsOtherGroup then
	for _, w in ipairs(otherWeapons) do
		if addSkinDropdownForWeapon(w, SkinsOtherGroup) then
			anySkinRows = true
			nOtherSkins = nOtherSkins + 1
		end
	end
	if nOtherSkins == 0 then
		SkinsOtherGroup:AddLabel("No skins defined for other weapons.")
	end
end

if not anySkinRows then
	Tabs.Skins:AddLeftGroupbox("Skins", { Icon = "palette" }):AddLabel("No weapon/skin pairs found in CosmeticLibrary.")
end

if #GetAllWraps() == 0 and (#guns + #melees + #throwables + #otherWeapons) > 0 then
	Tabs.Wraps:AddLeftGroupbox("Wraps", { Icon = "palette", DefaultExpanded = true }):AddLabel(
		"CosmeticLibrary has no wraps — each weapon only has None."
	)
end

local WrapSettingsGroup = Tabs.Wraps:AddLeftGroupbox("Wrap settings", { Icon = "palette", DefaultExpanded = true })
WrapSettingsGroup:AddToggle({
	Text = "Invert wrap",
	Default = false,
	Idx = "WrapInvert",
})
Toggles.WrapInvert:OnChanged(function(v)
	for _, data in pairs(WrapConfig.per_weapon) do
		if type(data) == "table" and data.name then
			data.inverted = v
		end
	end
	if WrapConfig.enabled then
		UpdateWraps()
	end
end)

local WrapGunsGroup = Tabs.Wraps:AddLeftGroupbox("Guns", { Icon = "palette", DefaultExpanded = true })
local WrapMeleeGroup = Tabs.Wraps:AddRightGroupbox("Melee", { Icon = "palette", DefaultExpanded = true })
local WrapThrowGroup = Tabs.Wraps:AddRightGroupbox("Throwables", { Icon = "palette", DefaultExpanded = true })
local WrapOtherGroup = (#otherWeapons > 0) and Tabs.Wraps:AddRightGroupbox("Other", { Icon = "palette", DefaultExpanded = true }) or nil

for _, w in ipairs(guns) do
	addWrapDropdownForWeapon(w, WrapGunsGroup)
end
if #guns == 0 then
	WrapGunsGroup:AddLabel("No guns in item list.")
end

for _, w in ipairs(melees) do
	addWrapDropdownForWeapon(w, WrapMeleeGroup)
end
if #melees == 0 then
	WrapMeleeGroup:AddLabel("No melee in item list.")
end

for _, w in ipairs(throwables) do
	addWrapDropdownForWeapon(w, WrapThrowGroup)
end
if #throwables == 0 then
	WrapThrowGroup:AddLabel("No throwables in item list.")
end

if WrapOtherGroup then
	for _, w in ipairs(otherWeapons) do
		addWrapDropdownForWeapon(w, WrapOtherGroup)
	end
end

if #GetAllCharms() == 0 and (#guns + #melees + #throwables + #otherWeapons) > 0 then
	Tabs.Charms:AddLeftGroupbox("Charms", { Icon = "palette", DefaultExpanded = true }):AddLabel(
		"CosmeticLibrary has no charms — each weapon only has None."
	)
end

local CharmGunsGroup = Tabs.Charms:AddLeftGroupbox("Guns", { Icon = "palette", DefaultExpanded = true })
local CharmMeleeGroup = Tabs.Charms:AddRightGroupbox("Melee", { Icon = "palette", DefaultExpanded = true })
local CharmThrowGroup = Tabs.Charms:AddRightGroupbox("Throwables", { Icon = "palette", DefaultExpanded = true })
local CharmOtherGroup = (#otherWeapons > 0) and Tabs.Charms:AddRightGroupbox("Other", { Icon = "palette", DefaultExpanded = true }) or nil

for _, w in ipairs(guns) do
	addCharmDropdownForWeapon(w, CharmGunsGroup)
end
if #guns == 0 then
	CharmGunsGroup:AddLabel("No guns in item list.")
end

for _, w in ipairs(melees) do
	addCharmDropdownForWeapon(w, CharmMeleeGroup)
end
if #melees == 0 then
	CharmMeleeGroup:AddLabel("No melee in item list.")
end

for _, w in ipairs(throwables) do
	addCharmDropdownForWeapon(w, CharmThrowGroup)
end
if #throwables == 0 then
	CharmThrowGroup:AddLabel("No throwables in item list.")
end

if CharmOtherGroup then
	for _, w in ipairs(otherWeapons) do
		addCharmDropdownForWeapon(w, CharmOtherGroup)
	end
end
end

-- §12 INVENTORY SYNC — re-apply Config when inventory updates -----------------
if CurrentData then
	CurrentData:GetDataChangedSignal("WeaponInventory"):Connect(function()
		for weaponName in pairs(Config) do
			WeaponData(weaponName)
		end
	end)
	for weaponName in pairs(Config) do
		WeaponData(weaponName)
	end
end

-- §13 UI SETTINGS, SAVE/THEME, UNLOAD ----------------------------------------
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", { Icon = "wrench" })
MenuGroup:AddDropdown({
	Text = "Notification side",
	Options = { "Left", "Right" },
	Default = "Right",
	Idx = "NotificationSide",
	Callback = function(Value)
		Library:SetNotifySide(Value)
	end,
})
MenuGroup:AddDropdown({
	Text = "DPI Scale",
	Options = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Idx = "DPIDropdown",
	Callback = function(Value)
		local n = tonumber((tostring(Value)):gsub("%%", ""))
		if n then
			Library:SetDPIScale(n)
		end
	end,
})
MenuGroup:AddSlider({
	Text = "Corner radius",
	Min = 0,
	Max = 20,
	Rounding = 0,
	Default = Library.CornerRadius,
	Idx = "UICornerSlider",
	Callback = function(value)
		Window:SetCornerRadius(value)
	end,
})
MenuGroup:AddDivider()
MenuGroup:AddKeybind({
	Text = "Menu keybind",
	Default = "RightShift",
	Idx = "MenuKeybind",
	NoUI = true,
})
MenuGroup:AddButton("Unload", function()
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
	Rivals_UnloadSilentAim()
	Rivals_UnloadESP()
	Rivals_UnloadMovement()
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({
	"MenuKeybind",
	"NotificationSide",
	"DPIDropdown",
	"UICornerSlider",
	"aim_Enabled_Key",
	"aimbot_Enabled_Key",
	"aimbot_Prediction_Key",
	"aimbot_WallCheck_Key",
	"teleport_target",
})
ThemeManager:SetFolder("AcidHub")
SaveManager:SetFolder("AcidHub/Rivals")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
