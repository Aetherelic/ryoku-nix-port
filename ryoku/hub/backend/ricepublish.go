package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Rice authoring stays in Ryoku Settings. Remote catalogue and install
// ownership belongs exclusively to Ryostore.

// riceStoreEntry mirrors one entry in ryoku-extras/rices/registry.json. text
// (manifest, poster, palette, screenshots) is raw in-repo; the wallpaper and
// hero binaries are GitHub Release assets referenced by absolute URL, matching
// how livewalls ships its videos.
type riceStoreEntry struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Author      string   `json:"author,omitempty"`
	Blurb       string   `json:"blurb,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	CreatedWith string   `json:"createdWith,omitempty"`
	Color       string   `json:"color,omitempty"`
	Manifest    string   `json:"manifest,omitempty"`
	Poster      string   `json:"poster,omitempty"`
	Screenshots []string `json:"screenshots,omitempty"`
	Palette     string   `json:"palette,omitempty"`
	Wallpaper   string   `json:"wallpaper,omitempty"`
	Hero        string   `json:"hero,omitempty"`
	Accent      string   `json:"accent,omitempty"`
	Surface     string   `json:"surface,omitempty"`
	Rounding    int      `json:"rounding,omitempty"`
}

type riceRegistry struct {
	Version int              `json:"version"`
	Rices   []riceStoreEntry `json:"rices"`
}

func extrasReleaseURL(asset string) string {
	return "https://github.com/neur0map/ryoku-extras/releases/download/rices/" + asset
}

// publishRice lays a local rice into a ryoku-extras checkout's store structure
// and upserts its registry entry, leaving only the Release-asset upload and the
// git commit to the author. this is the "extract configs, commit to extras"
// path: everything mechanical is done, the human just reviews and pushes.
func publishRice(slug, storeDir string) error {
	if !validRiceSlug(slug) {
		return fmt.Errorf("bad rice slug %q", slug)
	}
	r, dir, err := loadRice(slug)
	if err != nil {
		return err
	}
	riceOut := filepath.Join(storeDir, "rices", slug)
	if err := os.MkdirAll(riceOut, 0o755); err != nil {
		return err
	}
	if err := atomicWrite(filepath.Join(riceOut, "rice.json"), mustJSON(r), 0o644); err != nil {
		return err
	}

	poster := ""
	if src := filepath.Join(dir, "preview.png"); isFile(src) {
		if copyFile(src, filepath.Join(riceOut, "poster.png")) == nil {
			poster = "rices/" + slug + "/poster.png"
		}
	}
	palette := ""
	if src := filepath.Join(dir, "palette.json"); isFile(src) {
		if copyFile(src, filepath.Join(riceOut, "palette.json")) == nil {
			palette = "rices/" + slug + "/palette.json"
		}
	}

	regPath := filepath.Join(storeDir, "rices", "registry.json")
	reg := riceRegistry{Version: 1}
	if b, err := os.ReadFile(regPath); err == nil {
		_ = json.Unmarshal(b, &reg)
	}
	entry := riceStoreEntry{
		ID: slug, Name: r.Name, Author: r.Author, Blurb: r.Blurb, Tags: r.Tags,
		CreatedWith: r.CreatedWith, Color: r.Color.Mode,
		Manifest: "rices/" + slug + "/rice.json",
		Poster:   poster, Palette: palette,
	}
	if hy, ok := r.Look["hypr"]; ok {
		if ap, ok := hy["appearance"].(map[string]any); ok {
			if v, ok := ap["activeBorder"].(string); ok {
				entry.Accent = v
			}
			if v, ok := ap["rounding"].(float64); ok {
				entry.Rounding = int(v)
			}
		}
	}
	if sh, ok := r.Look["shell"]; ok {
		if v, ok := sh["surfaceColor"].(string); ok {
			entry.Surface = v
		}
	}
	if r.Assets.Wallpaper != "" {
		entry.Wallpaper = extrasReleaseURL(slug + "-" + r.Assets.Wallpaper)
	}
	if r.Assets.Hero != "" {
		entry.Hero = extrasReleaseURL(slug + "-" + r.Assets.Hero)
	}
	replaced := false
	for i := range reg.Rices {
		if reg.Rices[i].ID == slug {
			reg.Rices[i] = entry
			replaced = true
			break
		}
	}
	if !replaced {
		reg.Rices = append(reg.Rices, entry)
	}
	if err := atomicWrite(regPath, mustJSON(reg), 0o644); err != nil {
		return err
	}

	fmt.Printf("published %q to %s\n", slug, riceOut)
	if r.Assets.Wallpaper != "" || r.Assets.Hero != "" {
		fmt.Println("upload as Release assets under the 'rices' tag:")
		if r.Assets.Wallpaper != "" {
			fmt.Printf("  %s  (from %s)\n", slug+"-"+r.Assets.Wallpaper, filepath.Join(dir, r.Assets.Wallpaper))
		}
		if r.Assets.Hero != "" {
			fmt.Printf("  %s  (from %s)\n", slug+"-"+r.Assets.Hero, filepath.Join(dir, r.Assets.Hero))
		}
	}
	fmt.Printf("then add screenshots under rices/%s/screenshots/ and git commit in the store.\n", slug)
	return nil
}
