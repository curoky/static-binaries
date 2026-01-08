{ lib,
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
  clang,
  zlib,
  stdenv,
  darwin,
}:

buildDotnetModule rec {
  pname = "music-decrypto";
  version = "2.4.2";

  src = fetchFromGitHub {
    owner = "davidxuang";
    repo = "MusicDecrypto";
    rev = "v${version}";
    hash = "sha256-dSstNJdHIuZydg83iwL03KVf1rNBOwdoq4+OEsl9RTo=";
  };

  projectFile = "MusicDecrypto.Commandline/MusicDecrypto.Commandline.csproj";

  executables = [ "musicdecrypto" ];

  dotnetFlags = [
    "-p:PublishAot=true"
    "-p:PublishTrimmed=true"
    "-p:TrimMode=partial"
    #"-p:PublishSingleFile=true"
    "-p:InvariantGlobalization=true"
    "-p:Configuration=Release"
    #"-p:RuntimeIdentifier=osx-arm64"

    #"-p:StaticExecutable=true"
    #"-p:RuntimeIdentifier=linux-musl-x64"
  ];

  makeWrapperArgs = [
    #"--set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1"
  ];

  nugetDeps = ./music-decrypto/nuget-deps-glibc.json;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;
  usePackageSource = true;
  selfContainedBuild = true;

  nativeBuildInputs = [
    clang
  ];

  buildInputs = [
    #zlib
    zlib.static
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin ( [
    darwin.ICU
  ]);

  # postInstall = '''';

  postFixup = ''
    rm $out/bin/musicdecrypto
    mv $out/lib/music-decrypto/musicdecrypto $out/bin/musicdecrypto
  '' + lib.optionalString stdenv.isLinux ''
    patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 $out/bin/musicdecrypto
    patchelf --set-rpath "/lib64:/usr/lib64" $out/bin/musicdecrypto
  '' + lib.optionalString stdenv.isDarwin ''
    OLD_ICU_PATH=$(otool -L "$out/bin/musicdecrypto" | grep libicucore | awk '{print $1}')

    if [ -n "$OLD_ICU_PATH" ]; then
      echo "Replacing $OLD_ICU_PATH with system libicucore..."
      install_name_tool -change "$OLD_ICU_PATH" "/usr/lib/libicucore.A.dylib" "$out/bin/musicdecrypto"
    fi
  '';

  #dontDotnetFixup = true;

  # passthru.updateScript = ./update.sh;

  meta = {
    description = "MusicDecrypto";
  };
}
