class Protoc < Formula
  desc "Protocol buffers (Google's data interchange format)"
  homepage 'https://github.com/protocolbuffers/protobuf/'
  version ENV['HOMEBREW_PROTOC_VERSION'] || '3.17.3'
  url "https://github.com/protocolbuffers/protobuf/archive/v#{version}.zip"
  license 'BSD-3-Clause'

  depends_on 'cmake' => :build
  depends_on 'ninja' => :build
  depends_on 'gcc@11' => :build

  keg_only :versioned_formula

  def install
    # skip rpath
    inreplace 'cmake/install.cmake', 'if (UNIX AND NOT APPLE)', 'if (OFF)', false

    mkdir 'build' do
      args = std_cmake_args + %W[
        -GNinja
        --log-level=STATUS
        -DCMAKE_C_COMPILER=#{Formula['gcc@11'].opt_bin}/gcc-11
        -DCMAKE_CXX_COMPILER=#{Formula['gcc@11'].opt_bin}/g++-11
        -DCMAKE_BUILD_TYPE=MinSizeRel
        -DBUILD_SHARED_LIBS=OFF
        -Dprotobuf_WITH_ZLIB=OFF
        -Dprotobuf_BUILD_TESTS=OFF
      ]
      args << '-DCMAKE_CXX_STANDARD=14' if Gem::Version.new(version) <= Gem::Version.new('3.2.0')

      # -DCMAKE_FIND_LIBRARY_SUFFIXES='.a'
      args << "-DCMAKE_CXX_FLAGS_MINSIZEREL='-Os -DNDEBUG -s'"
      args << "-DCMAKE_EXE_LINKER_FLAGS='-static'" if OS.linux?
      # args << "-DCMAKE_EXE_LINKER_FLAGS='-static-libgcc -static-libstdc++'" if OS.mac?

      system 'cmake', *args, '../cmake'
      system 'ninja'
      system 'ninja install'

      bin.install 'protoc'
    end
  end

  test do
    output = shell_output("ldd #{bin}/protoc 2>&1", 1).strip
    assert_equal 'not a dynamic executable', output

    test_version = {
      '3.2.1' => '3.2.0',
      '3.4.1' => '3.4.0',
      '3.5.2' => '3.5.1',
      '3.13.0.1' => '3.13.0'
    }
    test_version.default = version
    output = shell_output("#{bin}/protoc --version")
    assert_equal "libprotoc #{test_version[version]}", output.strip
  end
end
