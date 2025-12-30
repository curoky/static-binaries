{ lib, stdenv, fetchurl, writeText, git, nghttp2, libpsl, c-ares}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    if [[ -z $GIT_TEMPLATE_DIR ]]; then
      export GIT_TEMPLATE_DIR="$root/share/git-core/templates"
    fi

    if test -n "$NO_SET_GIT_TEMPLATE_DIR"; then
      unset GIT_TEMPLATE_DIR
    fi

    if [[ -z $GIT_EXEC_PATH ]]; then
      export GIT_EXEC_PATH="$root/libexec/git-core/"
    fi

    # --template="$root/share/git-core/templates" \
    # --exec-path="$root/libexec/git-core" \

    exec -a "$0" "$root/bin/_git" "$@"
  '';
in
(git.override {
  pythonSupport = false;
  nlsSupport = false;
  perlSupport = false;
}).overrideAttrs (oldAttrs: rec {
  buildInputs = oldAttrs.buildInputs ++ [ nghttp2 libpsl c-ares ];

  #doCheck = false;
  #doInstallCheck = false;

  env.NIX_LDFLAGS = oldAttrs.env.NIX_LDFLAGS
    + " -static -lnghttp2 -lnghttp3 -lcares -lngtcp2 -lngtcp2_crypto_ossl -lpsl -lssl -lcrypto -lssh2 -lidn2 -lzstd -lz -lunistring";

  patchPhase = ''
    find . -path './t/t[0-9][0-9][0-9][0-9]' -prune -o -type f -name '*.[ch]' -exec sed -i 's/\<error\>(/git_error(/g' {} +
    find . -path './t/t[0-9][0-9][0-9][0-9]' -prune -o -type f -name '*.[ch]' -exec sed -i 's/\<error\>\s\+(/git_error (/g' {} +
    find . -path './t/t[0-9][0-9][0-9][0-9]' -prune -o -type f -name '*.[ch]' -exec sed -i 's/int\s\+error\s*(/int git_error(/g' {} +
    find . -path './t/t[0-9][0-9][0-9][0-9]' -prune -o -type f -name '*.[ch]' -exec sed -i 's/undef error\b/undef git_error/' {} +
  '';

  postInstall = (oldAttrs.postInstall or "") + ''
    #cp config.log $out/share/git
    #sed -i "s|/nix/store/[a-z0-9]\{32\}-|/nix/store/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-|g" $out/share/git/config.log

    mv $out/bin/git $out/bin/_git
    cp ${wrapperScript} $out/bin/git
    chmod +x $out/bin/git
  '';
})
