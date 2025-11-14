-- Prefer A2DP over HSP/HFP for all Bluetooth devices

return {
	bluetooth_policy = {
		profile_priorities = {
			["a2dp-sink"] = 100,
			["a2dp-source"] = 90,
			["headset-head-unit"] = 1,
			["handsfree-head-unit"] = 1,
		},
	},
}
