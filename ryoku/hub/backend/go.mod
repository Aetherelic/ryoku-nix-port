module ryoku-hub

go 1.26.4

toolchain go1.26.5

require (
	github.com/BurntSushi/toml v1.6.0
	github.com/godbus/dbus/v5 v5.2.2
	ryostore v0.0.0
)

require golang.org/x/sys v0.27.0 // indirect

replace ryostore => ../../apps/ryostore/backend
