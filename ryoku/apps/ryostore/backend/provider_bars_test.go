package main

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func writeBarFixture(t *testing.T, root, id, manifest, scene string) {
	t.Helper()
	dir := filepath.Join(root, id)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "manifest.json"), []byte(manifest), 0o644); err != nil {
		t.Fatal(err)
	}
	if scene != "" {
		path := filepath.Join(root, filepath.FromSlash(scene))
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("import QtQuick\nItem {}\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func TestBarProviderScansManifestsAndMarksActiveStyle(t *testing.T) {
	root := t.TempDir()
	writeBarFixture(t, root, "sumi", `{"id":"sumi","name":"Sumi","summary":"Ink spine","scene":""}`, "")
	writeBarFixture(t, root, "obi", `{"id":"obi","name":"Obi","summary":"Floating sash","scene":"obi/Scene.qml"}`, "obi/Scene.qml")
	writeBarFixture(t, root, "nacre", `{"id":"nacre","name":"Nacre","summary":"Instrument archipelago","scene":"nacre/Scene.qml"}`, "nacre/Scene.qml")
	config := filepath.Join(t.TempDir(), "shell.json")
	if err := os.WriteFile(config, []byte(`{"barStyle":"nacre"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	items, _, err := (barProvider{root: root, shellConfig: config}).Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 3 {
		t.Fatalf("items = %+v", items)
	}
	for _, item := range items {
		if !item.Installed {
			t.Fatalf("%s is not installed", item.ID)
		}
		if item.Active != (item.ID == "nacre") {
			t.Fatalf("%s active = %v", item.ID, item.Active)
		}
	}
}

func TestBarProviderRejectsManifestWithMissingScene(t *testing.T) {
	root := t.TempDir()
	writeBarFixture(t, root, "broken", `{"id":"broken","name":"Broken","scene":"broken/Scene.qml"}`, "")
	if _, _, err := (barProvider{root: root, shellConfig: filepath.Join(root, "shell.json")}).Load(context.Background(), false); err == nil {
		t.Fatal("provider accepted a missing runtime scene")
	}
}
