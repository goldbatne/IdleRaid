local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local spawn = Instance.new("SpawnLocation")
spawn.Name = "GrowthSmokeSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0, 0)
spawn.Parent = workspace
local scriptTest = Instance.new("Script")
scriptTest.Name = "GrowthV2SmokeServer"
scriptTest.Source = [==[
local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local player = Players.PlayerAdded:Wait()
local server = game.ServerScriptService:WaitForChild("Server")
local debugState = server:WaitForChild("DebugGetPlayerState", 20)
local deadline = os.clock() + 15
local state
repeat
 state = debugState:Invoke(player)
 task.wait(0.1)
until (state and state.Ready) or os.clock() > deadline
local ok, err = pcall(function()
 assert(state and state.Ready, "profile not ready")
 assert(state.Level == 1 and state.BreakthroughStage == 1, "initial level/stage")
 assert(state.AvailableTrainingPower == 0 and state.LifetimeTrainingPower == 0, "initial power")
 assert(state.FinalAttack == 10 and state.BaseTrainingRate == 10, "initial stats/rate")
 print("IR_GROWTH_PLAY_INITIAL_PASS")
 local training = require(server.TrainingService)
 local trainingDeadline = os.clock() + 10
 repeat
  task.wait(0.5)
  training.Settle(player)
  state = debugState:Invoke(player)
 until state.LifetimeTrainingPower >= 10 or os.clock() > trainingDeadline
 assert(state.LifetimeTrainingPower >= 10 and state.AvailableTrainingPower == state.LifetimeTrainingPower, "online training")
 print("IR_GROWTH_PLAY_TRAINING_PASS", state.LifetimeTrainingPower)
 local growth = require(server.GrowthService)
 local data = require(server.PlayerDataService)
 assert(data.AddPowerFinal(player, 10000, "Test"), "grant")
 state = debugState:Invoke(player)
 local beforeLifetime = state.LifetimeTrainingPower
 local free = growth.TryBreakthrough(player, 1, 1)
 assert(free.Ok and free.Stage == 2 and free.Cost == 450, "free breakthrough")
 state = debugState:Invoke(player)
 assert(state.LifetimeTrainingPower >= beforeLifetime and state.AvailableTrainingPower < state.LifetimeTrainingPower,
  "spend only available")
 assert(growth.GrantOwnership(player, "Ticket", 5, 2), "ticket grant")
 local ticket = growth.TryBreakthrough(player, 5, 2)
 assert(ticket.Ok and ticket.Stage == 7, "ticket +5 total")
 state = debugState:Invoke(player)
 assert(state.BreakthroughTickets["5"] == 1, "ticket consumed once")
 assert(not growth.TryBreakthrough(player, 5, 7).Ok, "gate skip blocked")
 print("IR_GROWTH_PLAY_BREAKTHROUGH_PASS", state.BreakthroughStage)
end)
print("IR_GROWTH_PLAY_RESULT", ok, err)
StudioTestService:EndTest(if ok then "PASS" else "FAIL")
]==]
scriptTest.Parent = ServerScriptService
local ok, result = pcall(function() return StudioTestService:ExecutePlayModeAsync("GrowthV2Smoke") end)
print("IR_GROWTH_PLAY_LAUNCH", ok, result)
