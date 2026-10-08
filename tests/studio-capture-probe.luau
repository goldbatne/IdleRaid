local ok, result = pcall(function()
	return game:GetService("StudioCaptureService"):CanCaptureScreenshot()
end)
print("IR_CAPTURE_PROBE", ok, result)
