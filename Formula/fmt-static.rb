class FmtStatic < Formula
  desc 'Open-source formatting library for C++'
  homepage 'https://fmt.dev/'
  url 'https://github.com/fmtlib/fmt/archive/8.1.1.tar.gz'
  sha256 '3d794d3cf67633b34b2771eb9f073bde87e846e0d395d254df7b211ef1ec7346'
  license 'MIT'
  revision 1
  head 'https://github.com/fmtlib/fmt.git', branch: 'master'

  depends_on 'cmake' => :build

  def install
    system 'cmake', '.', '-DBUILD_SHARED_LIBS=FALSE', *std_cmake_args
    system 'make', 'install'
    system 'make', 'clean'
  end
end
