rule = {
    matches = {
        {
            { "node.name", "matches", "alsa_output.*" },
        },
    },
    apply_properties = {
        ["session.suspend-timeout-seconds"] = 86400
    },
}

table.insert(alsa_monitor.rules, rule)
