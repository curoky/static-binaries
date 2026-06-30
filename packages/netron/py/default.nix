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

    if [[ "$(uname)" == "Darwin" ]]; then
      exec -a "$0" python3 "$root/bin/_netron_main.py" "$@"
    else
      export PYTHONHOME=$store/python311
      export PYTHONPATH=$PYTHONHOME/lib/python3.11
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.11/site-packages
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.11/lib-dynload
      export PYTHONPATH=$PYTHONPATH:$root/lib/python3.11/site-packages
      exec -a "$0" "$PYTHONHOME/bin/python3.11" "$root/bin/_netron_main.py" "$@"
    fi
  '';
in

stdenv.mkDerivation rec {
  pname = "netron-py";
  version = "1.0.0";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/62/d1/9609fcce7bf2b6d2d2cbc3f13736c2f696d66170c247157e39c7245934b6/netron-9.1.3-py3-none-any.whl";
    sha256 = "sha256-SoTMbCn45cDc5OXIRdxXRzDwhjIaBpa3p9WSpZ3HhkE=";
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
