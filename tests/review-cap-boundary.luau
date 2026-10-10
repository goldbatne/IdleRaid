local server = game:GetService("ServerScriptService"):WaitForChild("Server")
local config = require(game:GetService("ReplicatedStorage").Shared.GrowthConfig)
local schema = require(server.ProfileSchema)
local store = require(server.ProfileStore)
local now = os.time()
local profile = schema.New(now - 3600)
profile.AvailableTrainingPower = config.MaxSafePower - 1
profile.LifetimeTrainingPower = config.MaxSafePower - 1
profile.OfflineRateSnapshot = 10
local summary, reason = store.TestOfflineSettle(profile, now)
print("IR_REVIEW_R05_OFFLINE", summary and summary.GrantedPower, reason, profile.AvailableTrainingPower, profile.LifetimeTrainingPower)
