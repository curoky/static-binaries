{
  lib,
  stdenv,
  fetchurl,
  opencc,
  unzip,
}:

stdenv.mkDerivation rec {
  pname = "rime-plugs";
  version = "0.15.2";

  src = fetchurl {
    url = "https://github.com/rime/squirrel/archive/refs/tags/${version}.tar.gz";
    sha256 = "sha256-H/o6oI3shXYhvufOkvTKJZPQKowm/mmMwnTl1jP3/bA=";
  };

  nativeBuildInputs = [
    opencc
    unzip
  ];

  rime_emoji = fetchurl {
    url = "https://github.com/rime/rime-emoji/archive/be7d308e42c4c4485229de37ec0afb7bafbfafc0.tar.gz";
    sha256 = "sha256-Bednn4sYYbqdyFEQGiCg/e2pOy1o2a3vdYyFSxgwDBI=";
  };

  meow_emoji_rime = fetchurl {
    url = "https://github.com/hitigon/meow-emoji-rime/archive/c2701e54b12649e690f35ac940ff6044ea1f0235.tar.gz";
    sha256 = "sha256-DXIC6TvUgbQ5CvzI7fGx8Swb9gDzCugPyAptAo6cE9I=";
  };

  rime_prelude = fetchurl {
    url = "https://github.com/rime/rime-prelude/archive/3803f09458072e03b9ed396692ce7e1d35c88c95.tar.gz";
    sha256 = "sha256-r6B82YxUCgrC0dbpj/p3ZUnFNeYX0+Qetu+AgG34BvI=";
  };

  rime_symbols = fetchurl {
    url = "https://github.com/fkxxyz/rime-symbols/archive/ce8fad81bc24c6c9fcb45b41ec062b94af9fcb46.tar.gz";
    sha256 = "sha256-pjBXurzil0yJ490JaYUOTO8eKgzSUm1tkOdIDR/DI0U=";
  };

  rime_dict = fetchurl {
    url = "https://github.com/Iorest/rime-dict/archive/325ecbda51cd93e07e2fe02e37e5f14d94a4a541.tar.gz";
    sha256 = "sha256-2JmhFk1oAR/L4aHX6GUMOoIVo3baufRYoax7ogC59lQ=";
  };

  rime_cloverpinyin = fetchurl {
    url = "https://github.com/fkxxyz/rime-cloverpinyin/releases/download/1.1.4/clover.schema-1.1.4.zip";
    sha256 = "sha256-Mn1qb5pndyRAGZzklh3a4KukAHgoUSLTJ1hP8Rb9R4s=";
  };

  rime_ice = fetchurl {
    url = "https://github.com/iDvel/rime-ice/archive/87a7de47e92c124b7eda18fcd8e7fa3b9c42fa4e.tar.gz";
    sha256 = "sha256-FBbXPxWT7ky+OmO6Lv+nEGx40GmcUQyvilbBnd6Rdwg=";
  };

  phases = [
    "buildPhase"
    "installPhase"
  ];

  buildPhase = '''';

  installPhase = ''
    mkdir -p \
      $out/share/rime-bundle/rime-emoji \
      $out/share/rime-bundle/rime-symbols \
      $out/share/rime-bundle/rime-dict \
      $out/share/rime-bundle/rime-ice \
      $out/share/rime-bundle/rime-cloverpinyin

    # rime-symbols
    tar -xzf ${rime_symbols} --strip-components=1 -C $out/share/rime-bundle/rime-symbols
    #python3 $out/share/rime-bundle/opencc/rime-symbols/rime-symbols-gen
    #for file in $out/share/rime-bundle/opencc/rime-symbols/*.txt; do
    #  opencc -i $file -o "$out/share/rime-bundle/opencc/rime-symbols/simple.$(basename $file)" -c t2s.json
    #done

    # rime-emoji
    tar -xzf ${rime_emoji} --strip-components=1 -C $out/share/rime-bundle/rime-emoji/
    for file in $out/share/rime-bundle/rime-emoji/opencc/*.txt; do
      opencc -i $file -o "$out/share/rime-bundle/rime-emoji/opencc/simple.$(basename $file)" -c t2s.json
    done

    # rime-dict
    tar -xzf ${rime_dict} --strip-components=1 -C $out/share/rime-bundle/rime-dict/
    for file in $out/share/rime-bundle/rime-dict/**/*.dict.yaml; do
      opencc -i $file -o "$out/share/rime-bundle/rime-dict/simple.$(basename $file)" -c t2s.json
    done

    # rime-cloverpinyin
    unzip ${rime_cloverpinyin} -d $out/share/rime-bundle/rime-cloverpinyin

    # rime-ice
    tar -xzf ${rime_ice} --strip-components=1 -C $out/share/rime-bundle/rime-ice
  '';

  meta = with lib; {
    description = "Bundle for Rime";
  };
}
