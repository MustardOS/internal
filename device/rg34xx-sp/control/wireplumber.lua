rules = {
  {
    matches = {
      {
        { "media.class", "matches", "Audio/Sink" },
      },
    },
    apply_properties = {
      ["node.pause-on-idle"] = false,
      ["node.always-process"] = true,
      ["session.suspend-timeout-seconds"] = 0,
      ["priority.driver"] = 2000,
      ["priority.session"] = 2000,
      ["api.alsa.period-size"] = 256,
      ["api.alsa.periods"] = 3,
      ["api.alsa.headroom"] = 128,
      ["api.alsa.disable-batch"] = true,
    },
  },
  {
    matches = {
      {
        { "device.name", "matches", "alsa_card._sys_devices_platform_soc_soc_03000000_*" },
      },
    },
    apply_properties = {
      ["device.profile-set"] = "/opt/muos/share/conf/acp/h700.conf",
    },
  },
}

for _, rule in ipairs(rules) do
  table.insert(alsa_monitor.rules, rule)
end
