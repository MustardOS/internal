rules = {
  {
    matches = {
      {
        { "media.class", "matches", "Audio/Sink" },
      },
    },
    apply_properties = {
      ["node.pause-on-idle"] = false,
      ["session.suspend-timeout-seconds"] = 0,
      ["api.alsa.period-size"] = 192,
      ["api.alsa.periods"] = 3,
      ["api.alsa.headroom"] = 0,
    },
  },
}

for _, rule in ipairs(rules) do
  table.insert(alsa_monitor.rules, rule)
end
