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
}

for _, rule in ipairs(rules) do
  table.insert(alsa_monitor.rules, rule)
end
