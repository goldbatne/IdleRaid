local roots = {
 game:GetService("ReplicatedStorage"):WaitForChild("Shared"),
 game:GetService("ServerScriptService"):WaitForChild("Server"),
 game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("Client"),
}
local total, failed = 0, 0
for _, root in ipairs(roots) do
 for _, child in ipairs(root:GetDescendants()) do
  if child:IsA("ModuleScript") then
   total += 1
   local ok, result = pcall(require, child)
   if not ok then
    failed += 1
    print("IR_REVIEW_MODULE_FAIL", child:GetFullName(), result)
   end
  end
 end
end
print("IR_REVIEW_MODULE_RESULT", total, failed)
assert(failed == 0)
