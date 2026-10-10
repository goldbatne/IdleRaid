from pathlib import Path
root = Path("tests")
base = (root / "oneshot-free-play.luau").read_text(encoding="utf-8")
for scenario in ("Free", "Ticket5", "Voucher10"):
    s = base.replace("IR_FREE_", "IR_MATCH_").replace("OneShotFreePlay", "ReviewMatchedPlay")
    for tail in ("Report", "Client", "Server"):
        s = s.replace("ReviewMatchedPlay" + tail, "ReviewMatchedPlay" + scenario + tail)
    s = s.replace("local started = os.clock()", 'local scenario = "' + scenario + '"\nlocal started = os.clock()\nlocal function elapsed() return math.floor((os.clock() - started) * 1000) / 1000 end\nprint("IR_MATCH_SCENARIO", scenario)')
    s = s.replace('print("IR_MATCH_PASS normal_profile")', 'print("IR_MATCH_INITIAL", scenario, initial.BreakthroughStage, initial.Gold, initial.TrainingFacilityTier, initial.FinalAttack, #(initial.Inventory or {}), initial.BreakthroughTickets["5"], initial.TrainingVouchers.Minutes10)')
    s = s.replace("local equipped = false", """local entitlementUsed = scenario == "Free"
 local function useVoucher()
  openPage("Growth")
  click(panel.GrowthPage.Tab3)
  local growth = panel.GrowthPage.Growth3
  growth.CanvasPosition = Vector2.new(0, 0)
  task.wait(0.1)
  click(growth.Minutes10)
  waitFor(function() return growth.VoucherConfirm.Visible end, 8, "voucher preview")
  growth.CanvasPosition = Vector2.new(0, 120)
  task.wait(0.1)
  local before = snapshot()
  local beforePower = before.AvailableTrainingPower
  click(growth.VoucherConfirm)
  waitFor(function() return (snapshot().TrainingVouchers or {}).Minutes10 == 0 end, 8, "voucher consumed")
  print("IR_MATCH_ENTITLEMENT_USED", scenario, before.BreakthroughStage, elapsed(), before.BaseTrainingRate, snapshot().AvailableTrainingPower - beforePower)
  closePage()
 end
 if scenario == "Voucher10" then useVoucher(); entitlementUsed = true end
 local equipped = false""")
    s = s.replace('local before = state.BreakthroughStage\n   openPage("Growth")', 'local before = state.BreakthroughStage\n   local powerBefore = state.AvailableTrainingPower\n   local costBefore = state.BreakthroughCost\n   local steps = if scenario == "Ticket5" and not entitlementUsed and before == 1 then 5 else 1\n   openPage("Growth")')
    s = s.replace("click(growth.Growth1.Step1)", 'if steps == 5 then growth.Growth1.CanvasPosition = Vector2.new(0, 165); task.wait(0.1) end\n   click(growth.Growth1["Step" .. steps])')
    s = s.replace('waitFor(function() return snapshot().BreakthroughStage == before + 1 end, 8, "breakthrough")', """waitFor(function() return snapshot().BreakthroughStage == before + steps end, 8, "breakthrough")
   if steps == 5 then
    entitlementUsed = true
    print("IR_MATCH_ENTITLEMENT_USED", scenario, before, elapsed(), powerBefore, costBefore)
   end""")
    s = s.replace('print("IR_MATCH_STAGE", snapshot().BreakthroughStage, snapshot().Level, math.floor(os.clock() - started))', 'print("IR_MATCH_STAGE", scenario, snapshot().BreakthroughStage, snapshot().Level, elapsed())')
    s = s.replace('assert(facility, "facility not purchased during free path")', 'assert(facility, "facility not purchased")\n assert(entitlementUsed, "entitlement not used")')
    s = s.replace('print("IR_MATCH_PASS gate_reached", math.floor(os.clock() - started))', 'print("IR_MATCH_GATE_REACHED", scenario, elapsed(), snapshot().Level, snapshot().FinalAttack, snapshot().TrainingFacilityTier)')
    s = s.replace("click(panel.RaidPage.Gate10)", 'local raidClicked = elapsed()\n click(panel.RaidPage.Gate10)\n print("IR_MATCH_RAID_CLICK", scenario, raidClicked)')
    s = s.replace('print("IR_MATCH_PASS raid_active")', 'print("IR_MATCH_RAID_ACTIVE", scenario, elapsed())')
    s = s.replace('"elapsed", math.floor(os.clock() - started))', '"elapsed", elapsed())')
    s = s.replace('print("IR_MATCH_PASS gate_clear", math.floor(os.clock() - started))', 'print("IR_MATCH_GATE_CLEAR", scenario, elapsed())')
    s = s.replace('print("IR_MATCH_CLIENT_RESULT", ok, err)', 'print("IR_MATCH_CLIENT_RESULT", scenario, ok, err)')
    s = s.replace('print("IR_MATCH_SERVER_RESULT", ok, clientError, state and state.BreakthroughStage)', 'print("IR_MATCH_SERVER_RESULT", "' + scenario + '", ok, clientError, state and state.BreakthroughStage)')
    s = s.replace('print("IR_MATCH_SERVER_RESULT false timeout")', 'print("IR_MATCH_SERVER_RESULT", "' + scenario + '", false, "timeout")')
    seed = """local core = game.ServerScriptService:WaitForChild("Server")
local player = game:GetService("Players"):GetPlayers()[1] or game:GetService("Players").PlayerAdded:Wait()
local store = require(core.ProfileStore)
local profile = require(core.ProfileSchema).New(os.time())
"""
    if scenario == "Ticket5":
        seed += 'profile.BreakthroughTickets["5"] = 1\n'
    if scenario == "Voucher10":
        seed += 'profile.TrainingVouchers.Minutes10 = 1\n'
    seed += 'store.TestSetMock(player.UserId, profile)\ncore.Main.Enabled = true\n'
    s = s.replace("local done = false\n", seed + "local done = false\n")
    s = s.replace('local server = Instance.new("Script")', 'game:GetService("ServerScriptService"):WaitForChild("Server").Main.Disabled = true\nlocal server = Instance.new("Script")')
    (root / ("review-matched-" + scenario.lower() + ".luau")).write_text(s, encoding="utf-8")
