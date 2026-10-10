"""Generate a test-only mid-click state-update race probe from the v1 click test."""
from pathlib import Path
root = Path(__file__).resolve().parent
s = (root / "review-ui-click-diagnostic-v1.luau").read_text(encoding="utf-8-sig")
s = s.replace('remote.Name = "ReviewUIClickResult"', 'remote.Name = "ReviewUIClickRaceResult"')
s = s.replace('remote.Parent = game.ReplicatedStorage', '''remote.Parent = game.ReplicatedStorage
local bump = Instance.new("RemoteEvent")
bump.Name = "ReviewUIClickRaceBump"
bump.Parent = game.ReplicatedStorage''')
s = s.replace("ReviewUIClickClient", "ReviewUIClickRaceClient")
s = s.replace("ReviewUIClickServer", "ReviewUIClickRaceServer")
s = s.replace('"ReviewUIClickResult"', '"ReviewUIClickRaceResult"')
s = s.replace('local report = game.ReplicatedStorage:WaitForChild("ReviewUIClickRaceResult")',
              'local report = game.ReplicatedStorage:WaitForChild("ReviewUIClickRaceResult")\nlocal bump = game.ReplicatedStorage:WaitForChild("ReviewUIClickRaceBump")')
s = s.replace(' click(row)\n task.wait(0.5)', '''virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
 local downDeadline = os.clock() + 2
 while down == 0 and os.clock() < downDeadline do task.wait(0.01) end
 assert(down == 1, "virtual press did not reach row")
 bump:FireServer()
 local destroyDeadline = os.clock() + 5
 while destroyed == 0 and os.clock() < destroyDeadline do task.wait(0.01) end
 print("IR_UI_RACE_BEFORE_RELEASE", down, destroyed, activated,
  stateController.GetSnapshot().FinalAttack)
 virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
 task.wait(0.5)''')
s = s.replace('assert(bag.Inventory.Equip.Visible, "equip button did not become visible")',
              'assert(destroyed >= 1 and activated == 0 and not bag.Inventory.Equip.Visible, "mid-click rerender did not cancel selection")')
s = s.replace('print("IR_UI_CLICK_CLIENT_RESULT", ok, err)', 'print("IR_UI_RACE_CLIENT_RESULT", ok, err)')
s = s.replace('local remote = game.ReplicatedStorage:WaitForChild("ReviewUIClickRaceResult")',
              '''local remote = game.ReplicatedStorage:WaitForChild("ReviewUIClickRaceResult")
local bump = game.ReplicatedStorage:WaitForChild("ReviewUIClickRaceBump")
bump.OnServerEvent:Connect(function(from)
 if from == player then
  local changed = require(server.PlayerDataService).AddPowerFinal(from, 1000, "ReviewClickRace")
  print("IR_UI_RACE_SERVER_BUMP", changed)
 end
end)''')
s = s.replace('local bump = game.ReplicatedStorage:WaitForChild("ReviewUIClickRaceBump")\nbump.OnServerEvent',
              'local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()\nlocal bump = game.ReplicatedStorage:WaitForChild("ReviewUIClickRaceBump")\nbump.OnServerEvent')
s = s.replace('end)\nlocal player = players:GetPlayers()[1] or players.PlayerAdded:Wait()\nlocal profile',
              'end)\nlocal profile')
s = s.replace('print("IR_UI_CLICK_RESULT", ok, err)', 'print("IR_UI_RACE_RESULT", ok, err)')
s = s.replace('print("IR_UI_CLICK_RESULT false timeout")', 'print("IR_UI_RACE_RESULT false timeout")')
s = s.replace('ExecutePlayModeAsync("ReviewUIClick")', 'ExecutePlayModeAsync("ReviewUIClickRace")')
s = s.replace('print("IR_UI_CLICK_LAUNCH", ok, result)', 'print("IR_UI_RACE_LAUNCH", ok, result)')
(root / "review-ui-click-race.luau").write_text(s, encoding="utf-8")
