package main

import (
	cryptorand "crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"golang.org/x/sys/unix"
)

const reloadCoverMaxBytes int64 = 64 << 20

var reloadCoverManagedName = regexp.MustCompile(`^[0-9a-f]{64}\.(bmp|gif|jpe?g|mkv|mov|mp4|png|svg|webm|webp)$`)

var reloadCoverAfterFirstCopyWriteHook func()

type reloadCoverHookWriter struct {
	writer io.Writer
	hook   func()
}

func (writer *reloadCoverHookWriter) Write(body []byte) (int, error) {
	written, err := writer.writer.Write(body)
	if written > 0 && writer.hook != nil {
		hook := writer.hook
		writer.hook = nil
		hook()
	}
	return written, err
}

func reloadCoverCopyWriter(writer io.Writer) io.Writer {
	if reloadCoverAfterFirstCopyWriteHook == nil {
		return writer
	}
	return &reloadCoverHookWriter{writer: writer, hook: reloadCoverAfterFirstCopyWriteHook}
}

type reloadCoverAsset struct {
	Path  string `json:"path"`
	Name  string `json:"name"`
	Kind  string `json:"kind"`
	Bytes int64  `json:"bytes"`
}

func emptyReloadCoverAsset() reloadCoverAsset {
	return reloadCoverAsset{Kind: "default"}
}

func reloadCoverDir() string {
	return filepath.Join(dataHome(), "ryoku", "reload-cover")
}

func reloadCoverBrandPath() string {
	return filepath.Join(configHome(), "ryoku", "brand.json")
}

func reloadCoverKind(path string) (string, error) {
	ext := strings.ToLower(filepath.Ext(path))
	if isVideo(path) {
		return "video", nil
	}
	switch ext {
	case ".gif":
		return "animated", nil
	case ".bmp", ".jpeg", ".jpg", ".png", ".svg", ".webp":
		return "image", nil
	default:
		return "", fmt.Errorf("unsupported reload-cover file type %q", ext)
	}
}

func resolveReloadCoverSource(raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", fmt.Errorf("reload-cover import needs a local file")
	}
	if strings.HasPrefix(raw, "file://") {
		parsed, err := url.Parse(raw)
		if err != nil {
			return "", fmt.Errorf("invalid file URL: %w", err)
		}
		if parsed.Host != "" && parsed.Host != "localhost" {
			return "", fmt.Errorf("reload-cover import accepts local files only")
		}
		decoded, err := url.PathUnescape(parsed.EscapedPath())
		if err != nil {
			return "", fmt.Errorf("invalid file URL path: %w", err)
		}
		raw = filepath.FromSlash(decoded)
	} else if strings.Contains(raw, "://") {
		return "", fmt.Errorf("reload-cover import accepts local files only")
	}
	if raw == "~" || strings.HasPrefix(raw, "~/") {
		raw = filepath.Join(os.Getenv("HOME"), strings.TrimPrefix(raw, "~/"))
	}
	absolute, err := filepath.Abs(raw)
	if err != nil {
		return "", err
	}
	return filepath.Clean(absolute), nil
}

func managedReloadCoverPath(path string) bool {
	if path == "" {
		return false
	}
	clean := filepath.Clean(path)
	return filepath.Dir(clean) == filepath.Clean(reloadCoverDir()) && reloadCoverManagedName.MatchString(filepath.Base(clean))
}

func openReloadCoverDir(create bool) (*os.File, error) {
	dir := filepath.Clean(reloadCoverDir())
	if create {
		if err := os.MkdirAll(filepath.Dir(dir), 0o755); err != nil {
			return nil, err
		}
		if err := os.Mkdir(dir, 0o755); err != nil && !os.IsExist(err) {
			return nil, err
		}
	}
	fd, err := unix.Open(dir, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_NOFOLLOW|unix.O_CLOEXEC, 0)
	if err != nil {
		return nil, fmt.Errorf("reload-cover directory must be a real directory: %w", err)
	}
	return os.NewFile(uintptr(fd), dir), nil
}

func createReloadCoverTemp(dir *os.File) (*os.File, string, error) {
	for range 10 {
		var suffix [16]byte
		if _, err := cryptorand.Read(suffix[:]); err != nil {
			return nil, "", err
		}
		name := ".import-" + hex.EncodeToString(suffix[:])
		fd, err := unix.Openat(int(dir.Fd()), name, unix.O_WRONLY|unix.O_CREAT|unix.O_EXCL|unix.O_NOFOLLOW|unix.O_CLOEXEC, 0o600)
		if errors.Is(err, unix.EEXIST) {
			continue
		}
		if err != nil {
			return nil, "", err
		}
		return os.NewFile(uintptr(fd), filepath.Join(dir.Name(), name)), name, nil
	}
	return nil, "", fmt.Errorf("couldn't create reload-cover temporary file")
}

func committedReloadCoverPath() string {
	body, err := os.ReadFile(reloadCoverBrandPath())
	if err != nil {
		return ""
	}
	var doc struct {
		ReloadCover reloadCoverAsset `json:"reloadCover"`
	}
	if json.Unmarshal(body, &doc) != nil || !managedReloadCoverPath(doc.ReloadCover.Path) {
		return ""
	}
	return filepath.Clean(doc.ReloadCover.Path)
}

func pruneReloadCoverExcept(kept map[string]bool) error {
	dir := filepath.Clean(reloadCoverDir())
	for path := range kept {
		if !managedReloadCoverPath(path) {
			return fmt.Errorf("refusing reload-cover prune outside %s", dir)
		}
	}
	managed, err := openReloadCoverDir(false)
	if errors.Is(err, unix.ENOENT) {
		return nil
	}
	if err != nil {
		return err
	}
	defer managed.Close()
	entries, err := managed.ReadDir(-1)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		name := entry.Name()
		owned := reloadCoverManagedName.MatchString(name) || strings.HasPrefix(name, ".import-")
		if entry.IsDir() || !owned || kept[filepath.Join(dir, name)] {
			continue
		}
		if err := unix.Unlinkat(int(managed.Fd()), name, 0); err != nil && !errors.Is(err, unix.ENOENT) {
			return err
		}
	}
	return nil
}

func pruneReloadCover(keep string) error {
	kept := map[string]bool{}
	if keep != "" {
		kept[filepath.Clean(keep)] = true
	}
	return pruneReloadCoverExcept(kept)
}

func reusableReloadCoverDestination(dir *os.File, name string, size int64, digest string) (bool, error) {
	fd, err := unix.Openat(int(dir.Fd()), name, unix.O_RDONLY|unix.O_NOFOLLOW|unix.O_CLOEXEC, 0)
	if err != nil {
		return false, err
	}
	file := os.NewFile(uintptr(fd), filepath.Join(dir.Name(), name))
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return false, err
	}
	if !info.Mode().IsRegular() || info.Size() != size {
		return false, nil
	}
	hash := sha256.New()
	copied, err := io.Copy(hash, io.LimitReader(file, size+1))
	if err != nil {
		return false, err
	}
	return copied == size && hex.EncodeToString(hash.Sum(nil)) == digest, nil
}

func importReloadCover(raw string) (reloadCoverAsset, error) {
	source, err := resolveReloadCoverSource(raw)
	if err != nil {
		return reloadCoverAsset{}, err
	}
	info, err := os.Stat(source)
	if err != nil {
		return reloadCoverAsset{}, err
	}
	if !info.Mode().IsRegular() {
		return reloadCoverAsset{}, fmt.Errorf("reload-cover import needs a regular file")
	}
	input, err := os.Open(source)
	if err != nil {
		return reloadCoverAsset{}, err
	}
	defer input.Close()
	if info.Size() > reloadCoverMaxBytes {
		return reloadCoverAsset{}, fmt.Errorf("reload-cover file exceeds 64 MiB (20 MB)")
	}
	kind, err := reloadCoverKind(source)
	if err != nil {
		return reloadCoverAsset{}, err
	}
	managed, err := openReloadCoverDir(true)
	if err != nil {
		return reloadCoverAsset{}, err
	}
	defer managed.Close()
	temp, tempName, err := createReloadCoverTemp(managed)
	if err != nil {
		return reloadCoverAsset{}, err
	}
	defer func() {
		if tempName != "" {
			unix.Unlinkat(int(managed.Fd()), tempName, 0)
		}
	}()
	hash := sha256.New()
	bytes, err := io.Copy(reloadCoverCopyWriter(io.MultiWriter(temp, hash)), io.LimitReader(input, reloadCoverMaxBytes+1))
	if err != nil {
		temp.Close()
		return reloadCoverAsset{}, err
	}
	if bytes > reloadCoverMaxBytes {
		temp.Close()
		return reloadCoverAsset{}, fmt.Errorf("reload-cover file exceeds 64 MiB (20 MB)")
	}
	if err := temp.Sync(); err != nil {
		temp.Close()
		return reloadCoverAsset{}, err
	}
	if err := temp.Chmod(0o644); err != nil {
		temp.Close()
		return reloadCoverAsset{}, err
	}
	if err := temp.Close(); err != nil {
		return reloadCoverAsset{}, err
	}
	digest := hex.EncodeToString(hash.Sum(nil))
	destinationName := digest + strings.ToLower(filepath.Ext(source))
	reusable, err := reusableReloadCoverDestination(managed, destinationName, bytes, digest)
	if os.IsNotExist(err) {
		if err := unix.Renameat(int(managed.Fd()), tempName, int(managed.Fd()), destinationName); err != nil {
			return reloadCoverAsset{}, err
		}
	} else if err != nil {
		return reloadCoverAsset{}, err
	} else if !reusable {
		return reloadCoverAsset{}, fmt.Errorf("existing reload-cover destination is not reusable")
	}
	tempName = ""
	destination := filepath.Join(reloadCoverDir(), destinationName)
	kept := map[string]bool{destination: true}
	if committed := committedReloadCoverPath(); committed != "" {
		kept[committed] = true
	}
	if err := pruneReloadCoverExcept(kept); err != nil {
		return reloadCoverAsset{}, err
	}
	return reloadCoverAsset{
		Path:  destination,
		Name:  filepath.Base(source),
		Kind:  kind,
		Bytes: bytes,
	}, nil
}

func runReloadCover(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("reload-cover needs import|prune")
	}
	switch args[0] {
	case "import":
		if len(args) != 2 {
			return fmt.Errorf("reload-cover import needs one local path")
		}
		asset, err := importReloadCover(args[1])
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(asset)
	case "prune":
		if len(args) > 2 {
			return fmt.Errorf("reload-cover prune accepts at most one managed path")
		}
		keep := ""
		if len(args) == 2 {
			keep = args[1]
		}
		return pruneReloadCover(keep)
	default:
		return fmt.Errorf("reload-cover needs import|prune")
	}
}
