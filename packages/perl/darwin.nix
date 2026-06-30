{
  stdenv,
  perl,
  libxcryptStatic,
  writeText,
}:

let
  # macOS: there is no static libc, and building perl in the darwin pkgsStatic
  # set pulls in a separate static toolchain. Instead use the *native* perl
  # (prebuilt in the upstream cache, no local toolchain build) and only swap its
  # single non-system dynamic dependency (libxcrypt) for the static archive, so
  # the resulting `perl` links libcrypt statically and is left depending only on
  # /usr/lib system libs. The native perl is also made relocatable by rewriting
  # libperl.dylib install names (see below).
  basePerl = (perl.override { libxcrypt = libxcryptStatic; }).overrideAttrs (oldAttrs: {
    postInstall =
      (oldAttrs.postInstall or "")
      +
      # On macOS perl is built natively (not fully static), so libperl.dylib
      # stays a dynamic library and the interpreter loads it by its absolute
      # /nix/store install path. normalize.sh does not rewrite Mach-O install
      # names, so repoint every consumer (and the dylib's own id) to a
      # @loader_path-relative location inside this package, keeping the payload
      # self-contained and relocatable after deployment.
      ''
        libperl=$(find "$out/lib" -name libperl.dylib -print -quit)
        coreDir=$(dirname "$libperl")
        oldId=$(${stdenv.cc.targetPrefix}otool -D "$libperl" | tail -n1)

        # The dylib lives next to the CORE/*.dylib extension libs and is
        # loaded both from $out/bin (../lib/...) and from CORE/ (same dir).
        install_name_tool -id "@loader_path/libperl.dylib" "$libperl"

        relFromBin="@loader_path/../''${coreDir#$out/}/libperl.dylib"
        for bin in "$out"/bin/perl "$out"/bin/perl5*; do
          [ -f "$bin" ] || continue
          install_name_tool -change "$oldId" "$relFromBin" "$bin" 2>/dev/null || true
        done
        for f in "$coreDir"/*; do
          [ -f "$f" ] || continue
          case "$(${stdenv.cc.targetPrefix}file --brief "$f")" in
            *Mach-O*) install_name_tool -change "$oldId" "@loader_path/libperl.dylib" "$f" 2>/dev/null || true ;;
          esac
        done
      '';
  });

  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    export PERL5LIB=$root/lib/perl5:$PERL5LIB
    for d in "$root"/lib/perl5/site_perl/*/; do
      [ -d "$d" ] && PERL5LIB=$d:$PERL5LIB
    done
    exec -a "$0" "$root/bin/_perl" "$@"
  '';
in

basePerl.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/perl $out/bin/_perl
    cp ${wrapperScript} $out/bin/perl
    chmod +x $out/bin/perl
  '';
})
