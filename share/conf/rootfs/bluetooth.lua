bluez_monitor.enabled = true

bluez_monitor.properties = {
  ["with-logind"] = true,
}

bluez_monitor.rules = {
  {
    matches = {
      {
        { "device.name", "matches", "bluez_card.*" },
      },
    },
    apply_properties = {
      ["bluez5.auto-connect"] = "[ a2dp_sink ]",
      ["device.profile"]      = "a2dp-sink",
    },
  },
  {
    matches = {
      {
        { "node.name", "matches", "bluez_input.*" },
      },
      {
        { "node.name", "matches", "bluez_output.*" },
      },
    },
    apply_properties = {},
  },
}
