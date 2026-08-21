.pragma library

// GpuPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "RYOKU RENDERS ON",
        "key": "AQ_DRM_DEVICES",
        "label": "Graphics mode",
        "desc": "Which GPU the desktop renders on, takes effect at your next login",
        "ctl": "seg",
        "src": "gpu.lua (override path via $RYOKU_GPU_CONF; base honours $XDG_CONFIG_HOME)",
        "opts": [
            "hybrid",
            "performance",
            "passthrough"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Editing profile",
        "desc": "Which power profile you are editing (power-saver, balanced, performance); edits the definition, not the live profile",
        "ctl": "seg",
        "src": "ryoku-hub cpu active (ryoku-power)",
        "opts": [
            "power-saver",
            "balanced",
            "performance"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Governor",
        "desc": "CPU scaling governor for the edited profile; ryoku-power re-applies it after the profile switches",
        "ctl": "seg",
        "src": "ryoku-power profiles (scaling_governor, power.json)",
        "opts": [
            "performance",
            "powersave"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Energy preference",
        "desc": "amd-pstate EPP hint for the edited profile, from power-saving to performance; re-applied on profile switch",
        "ctl": "seg",
        "src": "ryoku-power profiles (energy_performance_preference, power.json)",
        "opts": [
            "default",
            "performance",
            "balance_performance",
            "balance_power",
            "power"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Max frequency",
        "desc": "Ceiling on CPU clock as a percent of the hardware maximum for the edited profile",
        "ctl": "slid",
        "src": "ryoku-power profiles (scaling_max_freq, power.json)"
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Thermal profile",
        "desc": "ACPI platform profile (fan and power envelope) for the edited profile; re-applied after power-profiles-daemon so it holds",
        "ctl": "seg",
        "src": "ryoku-power profiles (platform_profile, power.json)",
        "opts": [
            "quiet",
            "balanced",
            "performance"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "CPU boost and PPT/TDP limits",
        "desc": "Deliberately not exposed: firmware governs boost and PPT on this hardware, so a control would report success and change nothing (see docs/power.md)",
        "ctl": "readout",
        "src": "static copy"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Power limit / TDP",
        "desc": "GPU power budget in watts, applied live for this session (NVIDIA nvidia-smi, AMD sysfs cap)",
        "ctl": "slid",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Performance level",
        "desc": "AMD power_dpm_force_performance_level: auto, low, or high",
        "ctl": "seg",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Persistence mode",
        "desc": "Keep the NVIDIA driver initialised so the GPU stays responsive",
        "ctl": "sw",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Overclock / undervolt / clock lock / fan (Advanced)",
        "desc": "GPU clock and fan control, gated behind a per-session warning; can misbehave, resets on reboot",
        "ctl": "slid",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Presets (Quiet / Balanced / Performance / custom)",
        "desc": "Save and apply named tuning bundles; built-ins adapt to whatever knobs your hardware exposes",
        "ctl": "action",
        "src": "~/.config/ryoku/gpu-presets.json"
    },
    {
        "tab": "",
        "group": "BATTERY",
        "key": "",
        "label": "Charge limit",
        "desc": "Stop charging at this percent to preserve battery health (50-100)",
        "ctl": "slid",
        "src": "ryoku-power charge-limit (charge_control_end_threshold, power.json)"
    },
    {
        "tab": "",
        "group": "BATTERY",
        "key": "",
        "label": "PCIe ASPM",
        "desc": "PCIe Active State Power Management policy: trade idle power for latency",
        "ctl": "seg",
        "src": "ryoku-power aspm (pcie_aspm/parameters/policy, power.json)",
        "opts": [
            "default",
            "performance",
            "powersave",
            "powersupersave"
        ]
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Readiness checks / Hide readiness checks (disclosure)",
        "desc": "",
        "ctl": "sw",
        "src": "none (transient page state: page.showChecks)"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Disable passthrough",
        "desc": "",
        "ctl": "action",
        "src": "qemu"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Review changes",
        "desc": "",
        "ctl": "action",
        "src": "reads nothing; prints a plan"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Enable passthrough",
        "desc": "",
        "ctl": "action",
        "src": "kvm; enables libvirtd; kvmfr static_size_mb=128"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Close",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Recheck",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "(no SettingSection - floating error column under the hero card)",
        "key": "",
        "label": "Retry",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Passthrough status line (verdict readout)",
        "desc": "",
        "ctl": "readout",
        "src": "`ryoku-hub gpu caps` -> caps.verdict"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Readiness checks dossier rows (Repeater over caps.checks)",
        "desc": "",
        "ctl": "readout",
        "src": "hwcaps.go buildChecks)"
    },
    {
        "tab": "",
        "group": "RYOKU RENDERS ON",
        "key": "",
        "label": "Graphics mode explainer (per-mode helper text)",
        "desc": "",
        "ctl": "readout",
        "src": "derived from page.mode + page.dgpuName"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Passthrough section intro",
        "desc": "",
        "ctl": "readout",
        "src": "static copy + page.dgpuName"
    }
];
