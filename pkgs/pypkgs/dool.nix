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

    from dool import __main__

    if __name__ == "__main__":
        sys.argv[0] = re.sub(r"(-script\.pyw|\.exe)?$", "", sys.argv[0])
        sys.exit(__main__.__main())
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

    # python_bin_path=/home/x/.nix-profile/bin/python3.11
    # pathon_lib_root=/nix/var/nix/profiles/py311-static/lib/python3.11/

    exec -a "$0" "$PYTHONHOME/bin/python3.11" "$root/bin/_dool_main.py" --bytes "$@"
  '';
in

stdenv.mkDerivation rec {
  pname = "dool";
  version = "1.0.0";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/24/66/3c81d509ce2658d9abf6950eca40b6bd765d677b48abdddee19ef83daac6/dool-1.3.4-py3-none-any.whl";
    sha256 = "sha256-OKHABl+2z93f79NUPqtVrS/WM6YZyZ26mCQXntpqoa4=";
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
    cp ${mainPyScript} $out/bin/_dool_main.py
    cp ${wrapperScript} $out/bin/dool
    chmod +x $out/bin/dool
  '';
}
