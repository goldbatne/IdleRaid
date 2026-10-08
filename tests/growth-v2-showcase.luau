local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")

local spawn = Instance.new("SpawnLocation")
spawn.Name = "GrowthShowcaseSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0, 0)
spawn.Parent = workspace

local session = Instance.new("Script")
session.Name = "GrowthShowcaseSession"
session.Source = [==[
local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local player = Players.PlayerAdded:Wait()
print("IR_SHOWCASE_PLAY_READY", player.Name)
task.wait(1800)
StudioTestService:EndTest("DONE")
]==]
session.Parent = ServerScriptService

local ok, result = pcall(function()
 return StudioTestService:ExecutePlayModeAsync("GrowthV2Showcase")
end)
print("IR_SHOWCASE_LAUNCH", ok, result)
