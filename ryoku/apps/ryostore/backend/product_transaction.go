package main

import (
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

func installProduct(ctx context.Context, cache *Cache, category string, entry ProductEntry) error {
	manifest, err := loadProductManifest(ctx, cache, category, entry)
	if err != nil {
		return err
	}
	dst, expectedDestination, err := productDestination(category, entry.ID)
	if err != nil {
		return err
	}
	if manifest.Destination != expectedDestination {
		return fmt.Errorf("%s/%s: destination %q is outside the category allowlist", category, entry.ID, manifest.Destination)
	}

	unlock, err := lockTree(dst)
	if err != nil {
		return err
	}
	defer unlock()
	if err := recoverTree(dst); err != nil {
		return fmt.Errorf("recover %s/%s: %w", category, entry.ID, err)
	}
	if err := cleanupProductStages(filepath.Dir(dst), entry.ID); err != nil {
		return err
	}
	if err := rejectSymlinkPath(productDestinationRoot(category), expectedDestination); err != nil {
		return err
	}

	prior, receiptErr := readReceipt(category, entry.ID)
	hadReceipt := receiptErr == nil
	if receiptErr != nil && !os.IsNotExist(receiptErr) {
		return receiptErr
	}
	info, destinationErr := os.Lstat(dst)
	hadDestination := destinationErr == nil
	if destinationErr != nil && !os.IsNotExist(destinationErr) {
		return destinationErr
	}
	if hadDestination {
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("%s is a symlink", dst)
		}
		if !info.IsDir() {
			return fmt.Errorf("tracked destination %s is not a directory", dst)
		}
		if !hadReceipt {
			return fmt.Errorf("refusing untracked destination %s", dst)
		}
	}
	if hadReceipt && prior.Destination != expectedDestination {
		return fmt.Errorf("receipt destination %q is outside the category allowlist", prior.Destination)
	}

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	stage, err := os.MkdirTemp(filepath.Dir(dst), ".ryostore-stage-"+entry.ID+"-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(stage)

	receiptFiles := make([]ReceiptFile, 0, len(manifest.Files))
	for index, file := range manifest.Files {
		if !file.Install {
			continue
		}
		rel := path.Join(entry.Path, file.Source)
		data, err := fetchProductFile(ctx, cache, rel, file.Size)
		if err != nil {
			return fmt.Errorf("%s/%s: files[%d] %s: %w", category, entry.ID, index, file.Source, err)
		}
		if int64(len(data)) != file.Size {
			return fmt.Errorf("%s/%s: size mismatch for %s", category, entry.ID, file.Source)
		}
		if fmt.Sprintf("%x", sha256.Sum256(data)) != file.SHA256 {
			return fmt.Errorf("%s/%s: hash mismatch for %s", category, entry.ID, file.Source)
		}
		target := filepath.Join(stage, filepath.FromSlash(file.Destination))
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		mode := os.FileMode(0o644)
		if file.Mode == "0755" {
			mode = 0o755
		}
		if err := os.WriteFile(target, data, mode); err != nil {
			return err
		}
		if err := os.Chmod(target, mode); err != nil {
			return err
		}
		receiptFiles = append(receiptFiles, ReceiptFile{
			Source:      file.Source,
			Destination: file.Destination,
			SHA256:      file.SHA256,
			Mode:        file.Mode,
			Size:        file.Size,
		})
	}

	receipt := Receipt{
		Category:    category,
		ID:          entry.ID,
		Version:     entry.Version,
		Destination: expectedDestination,
		Files:       receiptFiles,
	}
	operation := "install"
	if hadReceipt {
		operation = "update"
	}
	restoreReceipt := func() error {
		if hadReceipt {
			return writeReceipt(prior)
		}
		err := os.Remove(receiptPath(category, entry.ID))
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	finalize := func() error {
		if err := writeReceipt(receipt); err != nil {
			return err
		}
		if err := verifyInstalledReceipt(dst, receipt); err != nil {
			if restoreErr := restoreReceipt(); restoreErr != nil {
				return fmt.Errorf("%w; restore receipt: %v", err, restoreErr)
			}
			return err
		}
		change := StoreRevision{Category: category, ID: entry.ID, Version: entry.Version, Operation: operation}
		if err := writeStoreRevision(change); err != nil {
			if restoreErr := restoreReceipt(); restoreErr != nil {
				return fmt.Errorf("%w; restore receipt: %v", err, restoreErr)
			}
			return err
		}
		return nil
	}
	return replaceTree(stage, dst, finalize)
}

func removeProduct(_ context.Context, category, id string) error {
	dst, expectedDestination, err := productDestination(category, id)
	if err != nil {
		return err
	}
	unlock, err := lockTree(dst)
	if err != nil {
		return err
	}
	defer unlock()
	if err := recoverTree(dst); err != nil {
		return err
	}
	receipt, err := readReceipt(category, id)
	if err != nil {
		return err
	}
	if receipt.Destination != expectedDestination {
		return fmt.Errorf("receipt destination %q is outside the category allowlist", receipt.Destination)
	}
	if err := rejectSymlinkPath(productDestinationRoot(category), expectedDestination); err != nil {
		return err
	}

	type ownedFile struct {
		source string
		hold   string
	}
	existing := make([]ownedFile, 0, len(receipt.Files))
	for _, file := range receipt.Files {
		source := filepath.Join(dst, filepath.FromSlash(file.Destination))
		if err := rejectSymlinkPath(dst, filepath.FromSlash(file.Destination)); err != nil {
			return err
		}
		info, err := os.Lstat(source)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("%s is a symlink", source)
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("owned path %s is not a regular file", source)
		}
		existing = append(existing, ownedFile{source: source})
	}

	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	hold, err := os.MkdirTemp(filepath.Dir(dst), ".ryostore-remove-"+id+"-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(hold)
	moved := make([]ownedFile, 0, len(existing))
	rollbackFiles := func() error {
		for index := len(moved) - 1; index >= 0; index-- {
			file := moved[index]
			if err := os.MkdirAll(filepath.Dir(file.source), 0o755); err != nil {
				return err
			}
			if err := os.Rename(file.hold, file.source); err != nil {
				return err
			}
		}
		return nil
	}
	for _, file := range existing {
		rel, err := filepath.Rel(dst, file.source)
		if err != nil {
			_ = rollbackFiles()
			return err
		}
		file.hold = filepath.Join(hold, rel)
		if err := os.MkdirAll(filepath.Dir(file.hold), 0o755); err != nil {
			_ = rollbackFiles()
			return err
		}
		if err := os.Rename(file.source, file.hold); err != nil {
			_ = rollbackFiles()
			return err
		}
		moved = append(moved, file)
	}
	pruneEmptyProductDirs(dst, receipt.Files)

	receiptFile := receiptPath(category, id)
	receiptBackup, err := reserveRenamePath(filepath.Dir(receiptFile), ".receipt-remove-*")
	if err != nil {
		_ = rollbackFiles()
		return err
	}
	defer os.Remove(receiptBackup)
	if err := os.Rename(receiptFile, receiptBackup); err != nil {
		_ = rollbackFiles()
		return err
	}
	restore := func(cause error) error {
		receiptErr := os.Rename(receiptBackup, receiptFile)
		filesErr := rollbackFiles()
		if receiptErr != nil || filesErr != nil {
			return fmt.Errorf("%w; restore receipt: %v; restore files: %v", cause, receiptErr, filesErr)
		}
		return cause
	}
	change := StoreRevision{Category: category, ID: id, Version: receipt.Version, Operation: "remove"}
	if err := writeStoreRevision(change); err != nil {
		return restore(err)
	}
	if err := os.Remove(receiptBackup); err != nil {
		return err
	}
	return os.RemoveAll(hold)
}

func productDestination(category, id string) (string, string, error) {
	if !validProductCategory(category) || !productIDPattern.MatchString(id) {
		return "", "", fmt.Errorf("invalid product identity %s/%s", category, id)
	}
	var relative string
	switch category {
	case "rices":
		relative = path.Join("ryoku", "rices", id)
	case "lockscreens":
		relative = path.Join("qylock", "themes", id)
	default:
		relative = path.Join("ryoku", category, id)
	}
	root := productDestinationRoot(category)
	return filepath.Join(root, filepath.FromSlash(relative)), relative, nil
}

func productDestinationRoot(category string) string {
	if category == "rices" || category == "lockscreens" {
		return configHome()
	}
	return dataHome()
}

func fetchProductFile(ctx context.Context, cache *Cache, rel string, limit int64) ([]byte, error) {
	if cache == nil || cache.client == nil || !validProductPath(rel) || limit < 0 || limit > maxProductFileSize {
		return nil, fmt.Errorf("invalid product fetch %q", rel)
	}
	data, fetchErr := fetchProductFileLive(ctx, cache, rel, limit)
	if fetchErr == nil {
		cache.writeDisk(rel, data)
		return data, nil
	}
	cached := filepath.Join(cache.dir, filepath.FromSlash(rel))
	info, err := os.Lstat(cached)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 || info.Size() > limit {
		return nil, fetchErr
	}
	data, err = os.ReadFile(cached)
	if err != nil {
		return nil, fetchErr
	}
	return data, nil
}

func fetchProductFileLive(ctx context.Context, cache *Cache, rel string, limit int64) ([]byte, error) {
	url := cache.base + "/" + rel
	separator := "?"
	if strings.Contains(url, "?") {
		separator = "&"
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, fmt.Sprintf("%s%s_=%d", url, separator, time.Now().UnixNano()), nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Cache-Control", "no-cache")
	response, err := cache.client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, &HTTPStatusError{URL: url, Status: response.StatusCode}
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > limit {
		return nil, fmt.Errorf("%s: response exceeds %d bytes", url, limit)
	}
	return data, nil
}

func verifyInstalledReceipt(dst string, receipt Receipt) error {
	stored, err := readReceipt(receipt.Category, receipt.ID)
	if err != nil {
		return err
	}
	if stored.Version != receipt.Version || stored.Destination != receipt.Destination || len(stored.Files) != len(receipt.Files) {
		return fmt.Errorf("installed receipt did not persist")
	}
	for _, file := range receipt.Files {
		path := filepath.Join(dst, filepath.FromSlash(file.Destination))
		info, err := os.Lstat(path)
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 || info.Size() != file.Size {
			return fmt.Errorf("installed file %s does not match receipt", path)
		}
	}
	return nil
}

func cleanupProductStages(parent, id string) error {
	entries, err := os.ReadDir(parent)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	prefixes := []string{".ryostore-stage-" + id + "-", ".ryostore-remove-" + id + "-"}
	for _, entry := range entries {
		for _, prefix := range prefixes {
			if strings.HasPrefix(entry.Name(), prefix) {
				candidate := filepath.Join(parent, entry.Name())
				if entry.Type()&os.ModeSymlink != 0 {
					if err := os.Remove(candidate); err != nil {
						return err
					}
				} else if err := os.RemoveAll(candidate); err != nil {
					return err
				}
				break
			}
		}
	}
	return nil
}

func pruneEmptyProductDirs(dst string, files []ReceiptFile) {
	directories := make(map[string]struct{})
	for _, file := range files {
		directory := filepath.Dir(filepath.Join(dst, filepath.FromSlash(file.Destination)))
		for directory != dst && strings.HasPrefix(directory, dst+string(filepath.Separator)) {
			directories[directory] = struct{}{}
			directory = filepath.Dir(directory)
		}
	}
	ordered := make([]string, 0, len(directories))
	for directory := range directories {
		ordered = append(ordered, directory)
	}
	sort.Slice(ordered, func(i, j int) bool { return len(ordered[i]) > len(ordered[j]) })
	for _, directory := range ordered {
		_ = os.Remove(directory)
	}
	_ = os.Remove(dst)
}

func reserveRenamePath(directory, pattern string) (string, error) {
	file, err := os.CreateTemp(directory, pattern)
	if err != nil {
		return "", err
	}
	name := file.Name()
	if err := file.Close(); err != nil {
		os.Remove(name)
		return "", err
	}
	if err := os.Remove(name); err != nil {
		return "", err
	}
	return name, nil
}

func (lockProvider) Remove(ctx context.Context, id string) error {
	return removeProduct(ctx, "lockscreens", id)
}

func (riceProvider) Remove(ctx context.Context, id string) error {
	return removeProduct(ctx, "rices", id)
}

func (barProvider) Remove(ctx context.Context, id string) error {
	return removeProduct(ctx, "barstyles", id)
}

func (fastfetchProvider) Remove(ctx context.Context, id string) error {
	return removeProduct(ctx, "fastfetch", id)
}

func (pluginProvider) Remove(ctx context.Context, id string) error {
	return removeProduct(ctx, "plugins", id)
}

func (bundleProvider) Remove(ctx context.Context, id string) error {
	return removeProduct(ctx, "bundles", id)
}
