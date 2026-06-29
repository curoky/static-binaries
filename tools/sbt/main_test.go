package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/google/go-containerregistry/pkg/crane"
	"github.com/google/go-containerregistry/pkg/registry"
	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

// pkgTarGz builds a gzipped tar laid out as ./<pkg>/bin/<pkg>, matching the CI
// archive format (top-level dir = package name, stripped on extract).
func pkgTarGz(t *testing.T, pkg string) []byte {
	t.Helper()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	body := "#!/bin/sh\necho " + pkg + "\n"
	if err := tw.WriteHeader(&tar.Header{Name: "./" + pkg + "/bin/" + pkg, Mode: 0o755, Size: int64(len(body)), Typeflag: tar.TypeReg}); err != nil {
		t.Fatal(err)
	}
	if _, err := tw.Write([]byte(body)); err != nil {
		t.Fatal(err)
	}
	tw.Close()
	gz.Close()
	return buf.Bytes()
}

// startRegistry stands up an in-process OCI registry (go-containerregistry),
// pushes one single-layer image per package as <name>-<arch>, points
// ociRegistry at it, and returns nothing (cleanup is registered on t).
func startRegistry(t *testing.T, arch string, packages ...string) {
	t.Helper()
	srv := httptest.NewServer(registry.New())
	t.Cleanup(srv.Close)
	u, err := url.Parse(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	repo := u.Host + "/sb"

	for _, name := range packages {
		layer, err := tarball.LayerFromReader(bytes.NewReader(pkgTarGz(t, name)))
		if err != nil {
			t.Fatal(err)
		}
		img, err := mutate.AppendLayers(empty.Image, layer)
		if err != nil {
			t.Fatal(err)
		}
		if err := crane.Push(img, repo+":"+name+"-"+arch); err != nil {
			t.Fatal(err)
		}
	}

	old := ociRegistry
	ociRegistry = repo
	t.Cleanup(func() { ociRegistry = old })
}

func TestStripFirstComponent(t *testing.T) {
	cases := map[string]string{
		"./ripgrep/bin/rg":      "bin/rg",
		"ripgrep/share/man/x.1": "share/man/x.1",
		"./ripgrep":             "",
		"ripgrep":               "",
	}
	for in, want := range cases {
		if got := stripFirstComponent(in); got != want {
			t.Errorf("stripFirstComponent(%q)=%q want %q", in, got, want)
		}
	}
}

func TestExtractLinkRelocate(t *testing.T) {
	root := t.TempDir()
	prefix := filepath.Join(root, "opt", "sbt")
	pkg := "ripgrep"

	tgz := filepath.Join(root, "cache", pkg+".tar.gz")
	if err := os.MkdirAll(filepath.Dir(tgz), 0o755); err != nil {
		t.Fatal(err)
	}
	// Reuse the CI-shaped archive, but add a second file to exercise nesting.
	writeArchive(t, tgz, pkg, map[string]string{
		"bin/rg":         "#!/bin/sh\necho rg\n",
		"share/man/rg.1": "manpage\n",
	})

	store := storePath(prefix, pkg)
	if err := os.MkdirAll(store, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := extractTarGz(tgz, store); err != nil {
		t.Fatal(err)
	}
	if err := writeMeta(prefix, meta{Name: pkg, Arch: "linux-x86_64", Digest: "sha256:abc", Linked: true}); err != nil {
		t.Fatal(err)
	}
	if err := linkPkg(prefix, pkg); err != nil {
		t.Fatal(err)
	}

	binLink := filepath.Join(prefix, "bin", "rg")
	target, err := os.Readlink(binLink)
	if err != nil {
		t.Fatal(err)
	}
	if filepath.IsAbs(target) {
		t.Fatalf("symlink target is absolute: %q", target)
	}
	if _, err := os.Stat(binLink); err != nil {
		t.Fatalf("bin link does not resolve: %v", err)
	}
	if _, err := os.Lstat(filepath.Join(prefix, metaFile)); !os.IsNotExist(err) {
		t.Fatalf(".sbt-meta leaked into prefix")
	}

	// Relocate the whole prefix; relative links must still resolve.
	moved := filepath.Join(root, "moved", "sbt")
	if err := os.MkdirAll(filepath.Dir(moved), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(prefix, moved); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(moved, "bin", "rg")); err != nil {
		t.Fatalf("link broken after moving prefix: %v", err)
	}

	if err := unlinkPkg(moved, pkg); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(filepath.Join(moved, "bin", "rg")); !os.IsNotExist(err) {
		t.Fatalf("link not removed by unlink")
	}
}

// writeArchive builds a gzipped tar of ./<pkg>/<files...> for extraction tests.
func writeArchive(t *testing.T, dst, pkg string, files map[string]string) {
	t.Helper()
	f, err := os.Create(dst)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	gz := gzip.NewWriter(f)
	defer gz.Close()
	tw := tar.NewWriter(gz)
	defer tw.Close()
	for name, body := range files {
		if err := tw.WriteHeader(&tar.Header{Name: "./" + pkg + "/" + name, Mode: 0o755, Size: int64(len(body)), Typeflag: tar.TypeReg}); err != nil {
			t.Fatal(err)
		}
		if _, err := tw.Write([]byte(body)); err != nil {
			t.Fatal(err)
		}
	}
}

func TestReadWriteMeta(t *testing.T) {
	prefix := t.TempDir()
	if err := os.MkdirAll(storePath(prefix, "fd"), 0o755); err != nil {
		t.Fatal(err)
	}
	in := meta{Name: "fd", Arch: "linux-x86_64", Digest: "sha256:deadbeef", Linked: false}
	if err := writeMeta(prefix, in); err != nil {
		t.Fatal(err)
	}
	out, err := readMeta(prefix, "fd")
	if err != nil {
		t.Fatal(err)
	}
	if out.Name != in.Name || out.Arch != in.Arch || out.Digest != in.Digest || out.Linked != in.Linked {
		t.Errorf("roundtrip mismatch: %+v vs %+v", out, in)
	}
}

func TestInstallMultiAllPresent(t *testing.T) {
	arch := "linux-x86_64"
	startRegistry(t, arch, "ripgrep", "fd")
	prefix := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", t.TempDir())

	if err := installPackages([]string{"ripgrep", "fd"}, installOpts{prefix: prefix, arch: arch, linked: true}); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"ripgrep", "fd"} {
		if _, err := os.Stat(filepath.Join(prefix, "bin", name)); err != nil {
			t.Errorf("%s not installed/linked: %v", name, err)
		}
		m, err := readMeta(prefix, name)
		if err != nil || m.Name != name {
			t.Errorf("%s metadata missing: %v", name, err)
		}
		if !strings.HasPrefix(m.Digest, "sha256:") {
			t.Errorf("%s digest not recorded: %q", name, m.Digest)
		}
	}
}

// A missing package in the batch must abort the whole install before anything
// is written to the prefix.
func TestInstallMultiOneMissingAbortsAll(t *testing.T) {
	arch := "linux-x86_64"
	startRegistry(t, arch, "ripgrep") // "nope" intentionally absent
	prefix := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", t.TempDir())

	err := installPackages([]string{"ripgrep", "nope"}, installOpts{prefix: prefix, arch: arch, linked: true})
	if err == nil {
		t.Fatal("expected error for missing package")
	}
	if !strings.Contains(err.Error(), "nope") {
		t.Errorf("error should name the missing package, got: %v", err)
	}
	if _, statErr := os.Stat(storePath(prefix, "ripgrep")); !os.IsNotExist(statErr) {
		t.Errorf("ripgrep should NOT be installed when a sibling is missing")
	}
}
