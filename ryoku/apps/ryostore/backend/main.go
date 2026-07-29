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
		return fmt.Errorf("no command; expected catalog, install, or internal")
	}
	switch args[0] {
	case "catalog":
		return runCatalog(args[1:])
	case "install":
		return runInstall(args[1:])
	case "internal":
		return runInternal(args[1:])
	default:
		return fmt.Errorf("unknown command %q; expected catalog, install, or internal", args[0])
	}
}

func runCatalog(args []string) error {
	refresh := false
	category := ""
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
			rest = rest[2:]
		default:
			return fmt.Errorf("unknown catalog flag %q", rest[0])
		}
	}
	cat := BuildCatalog(context.Background(), providers(), refresh)
	if category != "" {
		var ok bool
		if cat, ok = filterCategory(cat, category); !ok {
			return fmt.Errorf("unknown category %q", category)
		}
	}
	b, err := json.Marshal(cat)
	if err != nil {
		return err
	}
	os.Stdout.Write(b)
	fmt.Println()
	return nil
}

func runInstall(args []string) error {
	if len(args) != 2 {
		return fmt.Errorf("install needs <category> <id>")
	}
	category, id := args[0], args[1]
	for _, p := range providers() {
		if p.Category().ID == category {
			return p.Install(context.Background(), id)
		}
	}
	return fmt.Errorf("unknown category %q", category)
}

// runInternal namespaces commands the extras actuator and Settings call
// directly. Later tasks add cache, installer, and guest subcommands before the
// final unknown-command error.
func runInternal(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("internal needs a subcommand")
	}
	return fmt.Errorf("unknown internal command %q", args[0])
}
