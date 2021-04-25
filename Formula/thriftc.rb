class Thriftc < Formula
  desc 'Framework for scalable cross-language services development'
  homepage 'https://thrift.apache.org'
  version ENV['HOMEBREW_THRIFTC_VERSION'] || '0.14.2'
  if version == '0.2.0'
    url "https://github.com/apache/thrift/archive/#{version}.tar.gz"
  else
    url "https://archive.apache.org/dist/thrift/#{version}/thrift-#{version}.tar.gz"
  end

  def openssl_version
    return 'openssl@1.0.2u' if version == '0.9.3' || version == '0.9.3.1'

    'openssl@1.1'
  end

  keg_only :versioned_formula
  depends_on 'autoconf' => :build
  depends_on 'automake' => :build
  depends_on 'cmake' => :build
  depends_on 'libtool' => :build
  depends_on 'ninja' => :build
  depends_on 'gcc@11' => :build

  depends_on 'flex' => :build
  depends_on 'bison' => :build
  # depends_on "node" => :build
  depends_on 'boost' => :build
  depends_on 'libevent' => :build

  if version == '0.9.3' || version == '0.9.3.1'
    depends_on 'openssl@1.0.2u' => :build
  else
    depends_on 'openssl@1.1' => :build
  end

  def autotools_install
    if Gem::Version.new(version) <= Gem::Version.new('0.9.1')
      inreplace 'compiler/cpp/src/generate/t_rb_generator.cc',
                'first ? first = false : f_types_ << ", ";',
                'if (first) {first = false;} else {f_types_ << ", ";}'
    end

    if version == '0.9.1'
      inreplace 'compiler/cpp/src/generate/t_java_generator.cc',
                'first ? first = false : indent(f_service_) << "else ";',
                'if (first) {first = false;} else {indent(f_service_) << "else ";}'
    end

    # only need by 0.2.0
    inreplace 'compiler/cpp/src/thriftl.ll', 'thrifty.h', 'thrifty.hh' if version == '0.2.0'

    ENV['CC'] = Formula['gcc@11'].opt_bin / 'gcc-11'
    ENV['CXX'] = Formula['gcc@11'].opt_bin / 'g++-11'
    ENV.append 'CFLAGS', '-Os -DNDEBUG -s'
    ENV.append 'CXXFLAGS', '-Os -DNDEBUG -s'
    ENV.append 'CPPFLAGS', '-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include'
    # https://github.com/esnet/iperf/issues/632#issuecomment-334104098
    ENV.append 'LDFLAGS', '--static' if OS.linux?
    ENV.append 'LDFLAGS', '-static-libgcc -static-libstdc++' if OS.mac?

    args = %W[
      --without-boost
      --without-cpp
      --without-qt4
      --without-c_glib
      --without-csharp
      --without-java
      --without-erlang
      --without-py
      --without-python
      --without-perl
      --without-php
      --without-php_extension
      --without-ruby
      --without-haskell
      --without-go
      --without-d
      --disable-shared
      --disable-static
      --disable-libs
      --disable-tests
      --disable-tutorial
      --prefix=#{prefix}
      --libdir=#{lib}
    ]

    system './bootstrap.sh' if version == '0.2.0'
    system './configure', *args
    system 'make'
    system 'make', 'install'
  end

  def cmake_install
    args = std_cmake_args + %W[
      -GNinja
      --log-level=STATUS
      -DCMAKE_C_COMPILER=#{Formula['gcc@11'].opt_bin}/gcc-11
      -DCMAKE_CXX_COMPILER=#{Formula['gcc@11'].opt_bin}/g++-11
      -DCMAKE_BUILD_TYPE=MinSizeRel
      -DBUILD_TESTING=OFF
      -DBUILD_EXAMPLES=OFF
      -DBUILD_TUTORIALS=OFF
      -DWITH_PLUGIN=ON
      -DWITH_JAVA=OFF
      -DWITH_NODEJS=OFF
      -DWITH_JAVASCRIPT=OFF
      -DBUILD_LIBRARIES=ON
      -DWITH_SHARED_LIB=OFF
      -DWITH_STATIC_LIB=ON
      -DOPENSSL_USE_STATIC_LIBS=ON
    ]

    args << "-DCMAKE_PREFIX_PATH='#{Formula['libevent'].prefix};#{Formula[openssl_version].prefix}'"
    args << "-DCMAKE_CXX_FLAGS_MINSIZEREL='-Os -DNDEBUG -s'"
    args << "-DCMAKE_EXE_LINKER_FLAGS='-static'" if OS.linux?
    args << "-DCMAKE_EXE_LINKER_FLAGS='-static-libgcc -static-libstdc++'" if OS.mac?

    mkdir 'build' do
      system 'cmake', *args, '..'
      system 'ninja'
      system 'ninja', 'install'
    end
  end

  def install
    if Gem::Version.new(version) <= Gem::Version.new('0.9.2')
      autotools_install
    else
      cmake_install
    end
  end

  test do
    if OS.linux?
      output = shell_output("ldd #{bin}/thrift 2>&1", 1).strip
      assert_equal 'not a dynamic executable', output
    elsif OS.mac?
      # TODO(@curoky): use `otool -L` to check.
    end

    test_version = version
    test_version = '0.9.3' if version == '0.9.3.1'

    retcode = 0
    retcode = 1 if Gem::Version.new(version) <= Gem::Version.new('0.9.1')
    assert_equal "Thrift version #{test_version}", shell_output("#{bin}/thrift -version", retcode).strip
  end
end
