class LlvmTools < Formula
  desc 'Formatting tools for C, C++, Obj-C, Java, JavaScript, TypeScript'
  homepage 'https://clang.llvm.org/docs/ClangFormat.html'
  # The LLVM Project is under the Apache License v2.0 with LLVM Exceptions
  license 'Apache-2.0'
  version = ENV['HOMEBREW_LLVMTOOLS_VERSION'] || '12.0.1'
  version version

  if Gem::Version.new(version) <= Gem::Version.new('8.0.1')
    if Gem::Version.new(version) <= Gem::Version.new('6.0.1')
      url "https://releases.llvm.org/#{version}/llvm-#{version}.src.tar.xz"
      resource 'clang' do
        url "https://releases.llvm.org/#{version}/cfe-#{version}.src.tar.xz"
      end
      resource 'clang-tools-extra' do
        url "https://releases.llvm.org/#{version}/clang-tools-extra-#{version}.src.tar.xz"
      end
    else
      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-#{version}/llvm-#{version}.src.tar.xz"
      resource 'clang' do
        url "https://github.com/llvm/llvm-project/releases/download/llvmorg-#{version}/cfe-#{version}.src.tar.xz"
      end
      resource 'clang-tools-extra' do
        url "https://github.com/llvm/llvm-project/releases/download/llvmorg-#{version}/clang-tools-extra-#{version}.src.tar.xz"
      end
    end
  elsif Gem::Version.new(version) <= Gem::Version.new('11.0.0')
    url "https://github.com/llvm/llvm-project/releases/download/llvmorg-#{version}/llvm-project-#{version}.tar.xz"
  elsif Gem::Version.new(version) == Gem::Version.new('12.0.1')
    url 'https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.1-rc3/llvm-project-12.0.1rc3.src.tar.xz'
  else
    url "https://github.com/llvm/llvm-project/releases/download/llvmorg-#{version}/llvm-project-#{version}.src.tar.xz"
  end

  depends_on 'cmake' => :build
  depends_on 'ninja' => :build
  depends_on 'python@3.9' => :build
  # depends_on 'gcc@11' => :build

  keg_only :versioned_formula

  def install
    if version == '8.0.1' # llvm8.0 https://bugs.gentoo.org/708730
      inreplace 'include/llvm/Demangle/MicrosoftDemangleNodes.h',
                '#include <array>', "#include <array>\n#include <cstdint>\n#include <string>"
    end

    build_path = 'build'
    if Gem::Version.new(version) <= Gem::Version.new('8.0.1')
      (buildpath / 'llvm_project/llvm').install buildpath.children
      (buildpath / 'llvm_project/clang').install resource('clang')
      (buildpath / 'llvm_project/clang-tools-extra').install resource('clang-tools-extra')
      build_path = 'llvm_project/build'
    end
    mkdir build_path do
      args = std_cmake_args
      args << '-DBUILD_SHARED_LIBS=OFF'
      args << "-DCMAKE_EXE_LINKER_FLAGS='-static'" if OS.linux?
      args << "-DCMAKE_EXE_LINKER_FLAGS='-static-libgcc -static-libstdc++'" if OS.mac?
      args << "-DCMAKE_FIND_LIBRARY_SUFFIXES='.a'"
      args << '-DCMAKE_BUILD_TYPE=MinSizeRel'
      args << "-DCMAKE_CXX_FLAGS_MINSIZEREL='-Os -DNDEBUG -s'"
      # args << "-DCMAKE_C_COMPILER=#{Formula['gcc@11'].opt_bin}/gcc-11"
      # args << "-DCMAKE_CXX_COMPILER=#{Formula['gcc@11'].opt_bin}/g++-11"

      if version == '3.9.1'
        args << '-DLLVM_EXTERNAL_CLANG_SOURCE_DIR=../clang'
        args << '-DLLVM_EXTERNAL_CLANG_TOOLS_EXTRA_SOURCE_DIR=../clang-tools-extra'
      else
        args << "-DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra'"
      end

      args << '../llvm'
      system 'cmake', '-G', 'Ninja', *args
      system 'ninja', 'clang-format', 'clang-query', 'clang-tidy'
      bin.install 'bin/clang-format', 'bin/clang-query', 'bin/clang-tidy'
    end
  end

  test do
    if OS.linux?
      output = shell_output("ldd #{bin}/clang-format 2>&1", 1).strip
      assert_equal 'not a dynamic executable', output
      output = shell_output("ldd #{bin}/clang-query 2>&1", 1).strip
      assert_equal 'not a dynamic executable', output
      output = shell_output("ldd #{bin}/clang-tidy 2>&1", 1).strip
      assert_equal 'not a dynamic executable', output
    elsif OS.mac?
      # TODO(@curoky): use `otool -L` to check.
    end

    # NB: below C code is messily formatted on purpose.
    (testpath / 'test.c').write <<~EOS
      int         main(char *args) { \n   \t printf("hello"); }
    EOS

    assert_equal "int main(char *args) { printf(\"hello\"); }\n",
                 shell_output("#{bin}/clang-format -style=Google test.c")
  end
end
