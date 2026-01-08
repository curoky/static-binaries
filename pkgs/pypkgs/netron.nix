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

    from netron import main

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

    exec -a "$0" "$PYTHONHOME/bin/python3.11" "$root/bin/_netron_main.py" "$@"
  '';
in

stdenv.mkDerivation rec {
  pname = "netron";
  version = "1.0.0";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/cb/a3/051d987c3357c752d1f7cf9438092d4ed1e4f0e270a5b2ab49191e5e46c2/netron-8.2.7-py3-none-any.whl";
    sha256 = "sha256-rnADQLpVrn5lmmr8hg9xoU9QIdgUADuDUn9AVcH9AUQ=";
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
    cp ${mainPyScript} $out/bin/_netron_main.py
    cp ${wrapperScript} $out/bin/netron
    chmod +x $out/bin/netron
  '';
}
