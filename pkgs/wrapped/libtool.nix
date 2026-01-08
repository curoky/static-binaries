{
  lib,
  stdenv,
  fetchurl,
  libtool,
  writeText,
}:

libtool.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    sed -i 's| prefix=| script_path="$(readlink -f "$0")" #|g' $out/bin/libtoolize
    sed -i 's| datadir=| root=$(cd "$(dirname "$script_path")" \&\& pwd)/.. #|g' $out/bin/libtoolize
    sed -i 's| pkgauxdir=| pkgauxdir=$root/share/libtool/build-aux #|g' $out/bin/libtoolize
    sed -i 's| pkgltdldir=| pkgltdldir=$root/share/libtool #|g' $out/bin/libtoolize
    sed -i 's| aclocaldir=| aclocaldir=$root/share/aclocal #|g' $out/bin/libtoolize
  '';
})
