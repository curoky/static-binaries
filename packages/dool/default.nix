{
  stdenv,
  writeText,
  dool,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    # python_bin_path=/home/x/.nix-profile/bin/python3.11
    # pathon_lib_root=/nix/var/nix/profiles/py311-static/lib/python3.11/
    if [[ "$(uname)" == "Darwin" ]]; then
      exec -a "$0" python3 "$root/bin/_dool_main.py" --bytes "$@"
    else
      export PYTHONHOME=$store/python311
      export PYTHONPATH=$PYTHONHOME/lib/python3.11
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.11/site-packages
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.11/lib-dynload
      export PYTHONPATH=$PYTHONPATH:$root/lib/python3.11/site-packages
      exec -a "$0" "$PYTHONHOME/bin/python3.11" "$root/bin/_dool_main.py" --bytes "$@"
    fi
  '';
in

stdenv.mkDerivation {
  pname = "dool";
  inherit (dool) version;

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    # dool ships as a single self-contained, stdlib-only python script; reuse it
    # directly as the entry point. The wrapper invokes a relative python
    # interpreter explicitly, so the upstream nix-store shebang is inert.
    cp ${dool}/bin/dool $out/bin/_dool_main.py
    cp ${wrapperScript} $out/bin/dool
    chmod +x $out/bin/dool
  '';
}
