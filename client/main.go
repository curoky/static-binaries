// Command sb is a tiny package manager for the standalone-binaries
// published at ghcr.io/curoky/standalone-binaries.
//
// Design goals (see DESIGN.md "Client Install / Upgrade Model"):
//
//   - Single static binary. sb is one statically-linked binary (built with
//     CGO_ENABLED=0), cross-compiled for linux-x86_64 and darwin-arm64. OCI
//     access is delegated to go-containerregistry (crane), so neither curl,
//     tar, oras nor jq is required on the target host.
//   - Relocatable installs. Packages live under <prefix>/store/<name> and are
//     exposed through *relative* symlinks in <prefix>/{bin,lib,share,...}.
//     Because every link is relative, the whole prefix can be moved anywhere
//     with zero repair.
//   - Independent packages. Every package is treated as fully self-contained;
//     sb performs no dependency resolution.
//
// Commands: install | remove | upgrade | info | list | outdated
//
// `install` accepts multiple packages and runs in three phases:
//  1. resolve every package's remote layer digest in parallel (a missing
//     package is an error; if any package is missing, nothing is installed);
//  2. download the needed layers in parallel into the cache;
//  3. extract + link them serially.
package main

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/google/go-containerregistry/pkg/crane"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote/transport"
	"github.com/spf13/cobra"
	"golang.org/x/sync/errgroup"
)

const (
	defaultRegistry = "ghcr.io/curoky/standalone-binaries"
	metaFile        = ".sb-meta"
	defaultPrefix   = "/opt/sb"
	maxParallel     = 8 // cap concurrent registry requests / downloads
)

// detectArch returns the publish arch tag for the current platform. Only
// linux-x86_64 and darwin-arm64 are published; anything else must be passed
// explicitly via --arch.
func detectArch() (string, error) {
	switch {
	case runtime.GOOS == "linux" && runtime.GOARCH == "amd64":
		return "linux-x86_64", nil
	case runtime.GOOS == "darwin" && runtime.GOARCH == "arm64":
		return "darwin-arm64", nil
	}
	return "", fmt.Errorf("unsupported platform %s/%s; pass --arch linux-x86_64 or darwin-arm64",
		runtime.GOOS, runtime.GOARCH)
}

// ---------------------------------------------------------------------------
// OCI registry access (delegated to go-containerregistry / crane).
// ---------------------------------------------------------------------------

// ociRegistry is the registry reference root. It is a variable so tests can
// point it at a local httptest registry; production always uses ghcr.
var ociRegistry = defaultRegistry

func ref(name, arch string) string { return fmt.Sprintf("%s:%s-%s", ociRegistry, name, arch) }

// isNotFound reports whether err is a registry 404 (i.e. the package/tag does
// not exist for the requested arch).
func isNotFound(err error) bool {
	var terr *transport.Error
	return errors.As(err, &terr) && terr.StatusCode == http.StatusNotFound
}

// remoteLayer returns the single content layer of a package's image. The layer
// digest is what we record in .sb-meta and compare for upgrades; the layer's
// Compressed() stream is the package tarball.
func remoteLayer(name, arch string) (v1.Layer, error) {
	img, err := crane.Pull(ref(name, arch))
	if err != nil {
		if isNotFound(err) {
			return nil, fmt.Errorf("%s: not found for arch %q", name, arch)
		}
		return nil, fmt.Errorf("%s: %w", name, err)
	}
	layers, err := img.Layers()
	if err != nil {
		return nil, fmt.Errorf("%s: %w", name, err)
	}
	if len(layers) == 0 {
		return nil, fmt.Errorf("%s: image has no layers", name)
	}
	return layers[len(layers)-1], nil
}

// remoteDigest resolves a package's layer digest without downloading content.
func remoteDigest(name, arch string) (string, error) {
	layer, err := remoteLayer(name, arch)
	if err != nil {
		return "", err
	}
	d, err := layer.Digest()
	if err != nil {
		return "", fmt.Errorf("%s: %w", name, err)
	}
	return d.String(), nil
}

// downloadLayer streams a package's layer tarball into the cache.
func downloadLayer(name, arch, dst string) error {
	layer, err := remoteLayer(name, arch)
	if err != nil {
		return err
	}
	rc, err := layer.Compressed()
	if err != nil {
		return err
	}
	defer rc.Close()
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, rc)
	return err
}

func cachePath(arch, name string) string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "sb", arch, name+".tar.gz")
}

// ---------------------------------------------------------------------------
// Store / metadata / relative symlinks.
// ---------------------------------------------------------------------------

type meta struct {
	Name        string `json:"name"`
	Arch        string `json:"arch"`
	Digest      string `json:"digest"`
	Linked      bool   `json:"linked"`
	InstalledAt string `json:"installed_at"`
}

func metaPath(prefix, name string) string  { return filepath.Join(prefix, "store", name, metaFile) }
func storePath(prefix, name string) string { return filepath.Join(prefix, "store", name) }

func readMeta(prefix, name string) (meta, error) {
	var m meta
	data, err := os.ReadFile(metaPath(prefix, name))
	if err != nil {
		return m, err
	}
	return m, json.Unmarshal(data, &m)
}

func writeMeta(prefix string, m meta) error {
	m.InstalledAt = time.Now().UTC().Format(time.RFC3339)
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(metaPath(prefix, m.Name), data, 0o644)
}

// extractTarGz extracts a gzipped tar into dst, stripping the leading path
// component (CI archives packages as ./<name>/...).
func extractTarGz(src, dst string) error {
	f, err := os.Open(src)
	if err != nil {
		return err
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		return err
	}
	defer gz.Close()
	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		rel := stripFirstComponent(hdr.Name)
		if rel == "" {
			continue
		}
		target := filepath.Join(dst, rel)
		if !strings.HasPrefix(target, filepath.Clean(dst)+string(os.PathSeparator)) {
			return fmt.Errorf("unsafe path in archive: %s", hdr.Name)
		}
		switch hdr.Typeflag {
		case tar.TypeDir:
			err = os.MkdirAll(target, 0o755)
		case tar.TypeReg:
			err = writeFile(target, tr, os.FileMode(hdr.Mode)&0o777)
		case tar.TypeSymlink:
			if err = os.MkdirAll(filepath.Dir(target), 0o755); err == nil {
				_ = os.Remove(target)
				err = os.Symlink(hdr.Linkname, target)
			}
		}
		if err != nil {
			return err
		}
	}
	return nil
}

// writeFile creates target (with parent dirs) and copies r into it.
func writeFile(target string, r io.Reader, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	out, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, r)
	return err
}

// stripFirstComponent drops the leading path component (e.g. "./ripgrep/bin/rg"
// -> "bin/rg"); returning "" signals the entry should be skipped (the top dir).
func stripFirstComponent(name string) string {
	name = strings.TrimPrefix(filepath.ToSlash(name), "./")
	parts := strings.SplitN(name, "/", 2)
	if len(parts) < 2 {
		return ""
	}
	return parts[1]
}

// walkPkgFiles calls fn for every regular file / symlink under the package's
// store dir, skipping the metadata file. relPath is relative to the store dir.
func walkPkgFiles(store string, fn func(absPath, relPath string) error) error {
	return filepath.Walk(store, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(store, p)
		if err != nil {
			return err
		}
		if rel == metaFile {
			return nil
		}
		return fn(p, rel)
	})
}

// linkPkg creates relative symlinks from store/<name>/* into the prefix root.
func linkPkg(prefix, name string) error {
	return walkPkgFiles(storePath(prefix, name), func(abs, rel string) error {
		dest := filepath.Join(prefix, rel)
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return err
		}
		relTarget, err := filepath.Rel(filepath.Dir(dest), abs)
		if err != nil {
			return err
		}
		_ = os.Remove(dest)
		return os.Symlink(relTarget, dest)
	})
}

// unlinkPkg removes the relative symlinks a package created under the prefix.
func unlinkPkg(prefix, name string) error {
	return walkPkgFiles(storePath(prefix, name), func(abs, rel string) error {
		dest := filepath.Join(prefix, rel)
		if fi, err := os.Lstat(dest); err == nil && fi.Mode()&os.ModeSymlink != 0 {
			_ = os.Remove(dest)
		}
		return nil
	})
}

// ---------------------------------------------------------------------------
// install (multi-package, three-phase) and supporting commands.
// ---------------------------------------------------------------------------

type installOpts struct {
	prefix string
	arch   string
	linked bool
	force  bool
}

// installPackages runs the three-phase multi-package install.
func installPackages(names []string, o installOpts) error {
	// Phase 1: resolve every package's layer digest in parallel. errgroup
	// collects the first error per goroutine; we gather *all* missing packages
	// so the user sees the complete list before anything is installed.
	digests := make([]string, len(names))
	errs := make([]error, len(names))
	var g errgroup.Group
	g.SetLimit(maxParallel)
	for i, name := range names {
		i, name := i, name
		g.Go(func() error {
			d, err := remoteDigest(name, o.arch)
			digests[i], errs[i] = d, err
			return nil
		})
	}
	_ = g.Wait()
	if joined := errors.Join(errs...); joined != nil {
		return fmt.Errorf("aborting, some packages could not be resolved:\n%w", joined)
	}

	// Decide which packages actually need downloading (skip up-to-date unless
	// --force).
	digestOf := make(map[string]string, len(names))
	var toFetch []string
	for i, name := range names {
		digestOf[name] = digests[i]
		if !o.force {
			if m, err := readMeta(o.prefix, name); err == nil && m.Digest == digests[i] {
				fmt.Printf("> %s (%s) is already up to date, skipping. Use --force to reinstall.\n", name, o.arch)
				continue
			}
		}
		toFetch = append(toFetch, name)
	}

	// Phase 2: download the needed layers in parallel into the cache.
	var dg errgroup.Group
	dg.SetLimit(maxParallel)
	for _, name := range toFetch {
		name := name
		dg.Go(func() error { return downloadLayer(name, o.arch, cachePath(o.arch, name)) })
	}
	if err := dg.Wait(); err != nil {
		return fmt.Errorf("download failed: %w", err)
	}

	// Phase 3: extract + link serially.
	for _, name := range toFetch {
		store := storePath(o.prefix, name)
		fmt.Printf("> Installing %s (%s) -> %s (linked=%t)\n", name, o.arch, store, o.linked)
		if err := os.RemoveAll(store); err != nil {
			return err
		}
		if err := os.MkdirAll(store, 0o755); err != nil {
			return err
		}
		if err := extractTarGz(cachePath(o.arch, name), store); err != nil {
			return fmt.Errorf("%s: extract failed: %w", name, err)
		}
		if err := writeMeta(o.prefix, meta{Name: name, Arch: o.arch, Digest: digestOf[name], Linked: o.linked}); err != nil {
			return err
		}
		if o.linked {
			if err := linkPkg(o.prefix, name); err != nil {
				return fmt.Errorf("%s: link failed: %w", name, err)
			}
		}
		fmt.Printf("> Installed %s.\n", name)
	}
	return nil
}

func cmdRemove(prefix, name string) error {
	store := storePath(prefix, name)
	if _, err := os.Stat(store); err != nil {
		return fmt.Errorf("%s is not installed", name)
	}
	if m, err := readMeta(prefix, name); err == nil && m.Linked {
		if err := unlinkPkg(prefix, name); err != nil {
			return err
		}
	}
	if err := os.RemoveAll(store); err != nil {
		return err
	}
	fmt.Printf("> Removed %s from %s.\n", name, prefix)
	return nil
}

// installedNames lists package names that have a metadata file under the store.
func installedNames(prefix string) []string {
	entries, err := os.ReadDir(filepath.Join(prefix, "store"))
	if err != nil {
		return nil
	}
	var names []string
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if _, err := os.Stat(metaPath(prefix, e.Name())); err == nil {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)
	return names
}

func cmdList(prefix string) error {
	names := installedNames(prefix)
	if len(names) == 0 {
		fmt.Printf("No packages installed under %s.\n", prefix)
		return nil
	}
	fmt.Printf("%-22s %-15s %-7s %s\n", "NAME", "ARCH", "LINKED", "DIGEST")
	for _, name := range names {
		m, err := readMeta(prefix, name)
		if err != nil {
			continue
		}
		linked := "0"
		if m.Linked {
			linked = "1"
		}
		fmt.Printf("%-22s %-15s %-7s %s\n", m.Name, m.Arch, linked, short(m.Digest))
	}
	return nil
}

func cmdInfo(prefix, arch, name string) error {
	fmt.Printf("Package: %s\n", name)
	fmt.Printf("Registry: %s\n", ref(name, arch))
	remote, derr := remoteDigest(name, arch)
	if m, err := readMeta(prefix, name); err == nil {
		fmt.Printf("Status:  installed (%s)\n", storePath(prefix, name))
		fmt.Printf("  arch:    %s\n", m.Arch)
		fmt.Printf("  digest:  %s\n", m.Digest)
		fmt.Printf("  linked:  %t\n", m.Linked)
		fmt.Printf("  installed_at: %s\n", m.InstalledAt)
		switch {
		case derr != nil:
			fmt.Printf("  remote:  <error: %v>\n", derr)
		case m.Digest == remote:
			fmt.Printf("  remote:  %s (up to date)\n", remote)
		default:
			fmt.Printf("  remote:  %s (outdated)\n", remote)
		}
		return nil
	}
	fmt.Println("Status:  not installed")
	if derr != nil {
		return derr
	}
	fmt.Printf("  remote:  %s\n", remote)
	return nil
}

func cmdOutdated(prefix string) error {
	names := installedNames(prefix)
	if len(names) == 0 {
		fmt.Printf("No packages installed under %s.\n", prefix)
		return nil
	}
	any := false
	for _, name := range names {
		m, err := readMeta(prefix, name)
		if err != nil {
			continue
		}
		remote, err := remoteDigest(name, m.Arch)
		if err != nil {
			continue
		}
		if m.Digest != remote {
			any = true
			fmt.Printf("%-22s %s -> %s\n", name, short(m.Digest), short(remote))
		}
	}
	if !any {
		fmt.Println("All packages are up to date.")
	}
	return nil
}

func cmdUpgrade(prefix, arch string, names []string) error {
	if len(names) == 0 {
		names = installedNames(prefix)
		if len(names) == 0 {
			fmt.Printf("No packages installed under %s.\n", prefix)
			return nil
		}
	}
	for _, name := range names {
		m, err := readMeta(prefix, name)
		if err != nil {
			return fmt.Errorf("%s is not installed", name)
		}
		if err := installPackages([]string{name}, installOpts{
			prefix: prefix, arch: m.Arch, linked: m.Linked, force: false,
		}); err != nil {
			return err
		}
	}
	return nil
}

func short(digest string) string {
	if len(digest) > 19 {
		return digest[:19]
	}
	return digest
}

// ---------------------------------------------------------------------------
// CLI (cobra).
// ---------------------------------------------------------------------------

func main() {
	var (
		prefix string
		arch   string
		link   bool
		force  bool
	)

	// resolveArch returns the explicit --arch or the auto-detected platform.
	resolveArch := func() (string, error) {
		if arch != "" {
			return arch, nil
		}
		return detectArch()
	}

	root := &cobra.Command{
		Use:           "sb",
		Short:         "package manager for ghcr.io/curoky/standalone-binaries",
		SilenceUsage:  true,
		SilenceErrors: true,
	}
	pf := root.PersistentFlags()
	pf.StringVar(&prefix, "prefix", defaultPrefix, "install prefix")
	pf.StringVar(&arch, "arch", "", "arch tag: linux-x86_64 | darwin-arm64 (auto-detected)")

	install := &cobra.Command{
		Use:   "install <package>...",
		Short: "Install/refresh one or more packages",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			a, err := resolveArch()
			if err != nil {
				return err
			}
			return installPackages(args, installOpts{prefix: prefix, arch: a, linked: link, force: force})
		},
	}
	install.Flags().BoolVar(&link, "link", true, "expose binaries via relative symlinks")
	install.Flags().BoolVar(&force, "force", false, "reinstall even if the digest already matches")

	remove := &cobra.Command{
		Use:   "remove <package>",
		Short: "Uninstall a package and clean up its links",
		Args:  cobra.ExactArgs(1),
		RunE:  func(cmd *cobra.Command, args []string) error { return cmdRemove(prefix, args[0]) },
	}

	upgrade := &cobra.Command{
		Use:   "upgrade [package...]",
		Short: "Upgrade the given packages, or all installed packages if none is given",
		RunE: func(cmd *cobra.Command, args []string) error {
			a, err := resolveArch()
			if err != nil {
				return err
			}
			return cmdUpgrade(prefix, a, args)
		},
	}

	info := &cobra.Command{
		Use:   "info <package>",
		Short: "Show a package's metadata and whether it is up to date",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			a, err := resolveArch()
			if err != nil {
				return err
			}
			return cmdInfo(prefix, a, args[0])
		},
	}

	list := &cobra.Command{
		Use:   "list",
		Short: "List installed packages and their recorded digests",
		Args:  cobra.NoArgs,
		RunE:  func(cmd *cobra.Command, args []string) error { return cmdList(prefix) },
	}

	outdated := &cobra.Command{
		Use:   "outdated",
		Short: "Show installed packages whose remote digest has changed",
		Args:  cobra.NoArgs,
		RunE:  func(cmd *cobra.Command, args []string) error { return cmdOutdated(prefix) },
	}

	root.AddCommand(install, remove, upgrade, info, list, outdated)
	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
}
