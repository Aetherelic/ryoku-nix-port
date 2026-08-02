// ryostore is the Go data plane for the Ryostore app: it normalizes every
// product catalogue into one JSON contract and installs items without
// activating them. The Quickshell front end shells out to these subcommands.
//
//	ryostore catalog [--refresh] [--category <id>]   normalized catalogue, JSON
//	ryostore install <category> <id>                 install-only, no activation
//
// The internal namespace holds calls the extras actuator and Settings make
// directly; later tasks register those subcommands under it.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
)

func main() {
	if err := dispatch(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "ryostore:", err)
		os.Exit(1)
	}
}

// dispatch routes one command. It returns an error for every bad invocation so
// the caller reports one useful line and exits nonzero.
func dispatch(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("no command; expected catalog, install, open, settings, or internal")
	}
	switch args[0] {
	case "catalog":
		return runCatalog(os.Stdout, providers(), args[1:])
	case "install":
		return runInstall(providers(), args[1:])
	case "open":
		return runOpen(args[1:])
	case "settings":
		return runSettings(args[1:])
	case "internal":
		return runInternal(args[1:])
	default:
		return fmt.Errorf("unknown command %q; expected catalog, install, open, settings, or internal", args[0])
	}
}

func runCatalog(w io.Writer, provs []Provider, args []string) error {
	refresh := false
	category := ""
	haveCategory := false
	rest := args
	for len(rest) > 0 {
		switch rest[0] {
		case "--refresh":
			refresh = true
			rest = rest[1:]
		case "--category":
			if len(rest) < 2 {
				return fmt.Errorf("--category needs a category id")
			}
			category = rest[1]
			haveCategory = true
			rest = rest[2:]
		default:
			return fmt.Errorf("unknown catalog flag %q", rest[0])
		}
	}
	if haveCategory {
		if category == "" {
			return fmt.Errorf("--category needs a non-empty id")
		}
		p, ok := providerFor(provs, category)
		if !ok {
			return fmt.Errorf("unknown category %q", category)
		}
		provs = []Provider{p}
	}
	cat := BuildCatalog(context.Background(), provs, refresh)
	return json.NewEncoder(w).Encode(cat)
}

func runInstall(provs []Provider, args []string) error {
	if len(args) != 2 {
		return fmt.Errorf("install needs <category> <id>")
	}
	category, id := args[0], args[1]
	p, ok := providerFor(provs, category)
	if !ok {
		return fmt.Errorf("unknown category %q", category)
	}
	return p.Install(context.Background(), id)
}

// runInternal namespaces commands the extras actuator and Settings call
// directly: the browse cache directory, an on-demand script installer path, and
// the guest install/remove primitives. These are not public UI commands.
func runInternal(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("internal needs a subcommand")
	}
	switch args[0] {
	case "cache":
		fmt.Println(extrasCacheDir())
		return nil
	case "installer":
		if len(args) < 2 {
			return fmt.Errorf("internal installer needs a name")
		}
		p, err := ensureInstaller(args[1])
		if err != nil {
			return err
		}
		fmt.Println(p)
		return nil
	case "install-guest":
		if len(args) < 3 {
			return fmt.Errorf("internal install-guest needs <kind> <id>")
		}
		return installGuest(args[1], args[2])
	case "remove-guest":
		if len(args) < 3 {
			return fmt.Errorf("internal remove-guest needs <kind> <id>")
		}
		return removeGuest(args[1], args[2])
	default:
		return fmt.Errorf("unknown internal command %q", args[0])
	}
}
