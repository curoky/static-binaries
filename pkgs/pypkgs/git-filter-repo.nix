{
  lib,
  stdenv,
  fetchurl,
  writeText,
  unzip,
}:

let
  mainPyScript = writeText "main.py" ''
    import re
    import sys

    from git_filter_repo import main

    if __name__ == "__main__":
        sys.argv[0] = re.sub(r"(-script\.pyw|\.exe)?$", "", sys.argv[0])
        sys.exit(main())
  '';

  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    export PYTHONHOME=$store/python311
    export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.11
    export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.11/site-packages
    export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.11/lib-dynload
    export PYTHONPATH=$PYTHONPATH:$root/lib/python3.11/site-packages

    exec -a "$0" "$PYTHONHOME/bin/python3.11" "$root/bin/_git_filter_repo_main.py" "$@"
  '';
in

stdenv.mkDerivation rec {
  pname = "git-filter-repo";
  version = "1.0.0";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/60/60/d3943f0880ebcb7e0bdf79254d10dddd39c7b656eeecae32b8806ff66dec/git_filter_repo-2.47.0-py3-none-any.whl";
    sha256 = "sha256-LNBJKbkCToPmXbVxy+Nq7GXq0MtfnsWr5CFYZUr1rYM=";
  };

  unpackPhase = ":";

  nativeBuildInputs = [ unzip ];

  buildPhase = ''
    echo "Unzipping wheel file..."
    mkdir -p wheel-unpacked
    unzip $src -d wheel-unpacked
  '';

  installPhase = ''
    mkdir -p $out/lib/python3.11/site-packages
    cp -r wheel-unpacked/* $out/lib/python3.11/site-packages/

    mkdir -p $out/bin
    cp ${mainPyScript} $out/bin/_git_filter_repo_main.py
    cp ${wrapperScript} $out/bin/git-filter-repo
    chmod +x $out/bin/git-filter-repo
  '';
}
