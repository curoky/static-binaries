# macOS krb5: build the fully-static `pkgsStatic.krb5` set, working around two
# upstream defects that break static linking of libkrb5.a / libk5crypto.a on
# darwin (any consumer, e.g. krb5kdc, otherwise fails to link):
#
#   1. USE_CCAPI_MACOS: on modern macOS, configure compiles cc_api_macos.c and
#      makes API: the default ccache. That object calls CCAPI's cc_initialize,
#      provided only by `-framework Kerberos`, which is not linked into consumers
#      of the static libkrb5.a -> undefined `_cc_initialize`. We disable the
#      macOS CCAPI backend (falling back to the FILE: ccache, like Linux).
#
#   2. mit_des_zeroblock: defined in f_aead.o, but in a static link macOS `ld`
#      never pulls f_aead.o (nothing references its other symbols), so
#      d3_aead.o's reference to `_krb5int_c_mit_des_zeroblock` is undefined. The
#      patch moves the definition into d3_aead.c so it is always pulled.
#
# With both fixes the static set links cleanly; the resulting binaries depend
# only on /usr/lib system libs (libSystem, libresolv), matching the darwin
# portability rule in DESIGN.md (every nix dependency statically linked; only
# macOS system libraries stay dynamic).
{ krb5 }:

krb5.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./static-darwin-des-zeroblock.patch ];

  postPatch = (old.postPatch or "") + ''
    substituteInPlace configure \
      --replace-fail 'macos_defccname=API:' 'macos_defccname=' \
      --replace-fail 'printf "%s\n" "#define USE_CCAPI_MACOS 1" >>confdefs.h' ':'
  '';
})
