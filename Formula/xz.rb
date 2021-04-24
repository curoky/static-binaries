class Xz < Formula
  desc 'General-purpose data compression with high compression ratio'
  homepage 'https://tukaani.org/xz/'
  version ENV['HOMEBREW_XZ_VERSION'] || '5.2.5'
  url "https://downloads.sourceforge.net/project/lzmautils/xz-#{version}.tar.gz"
  license 'GPL-2.0'

  keg_only :versioned_formula
  depends_on 'gcc@11' => :build

  def install
    ENV['CC'] = Formula['gcc@11'].opt_bin / 'gcc-11'
    ENV['CXX'] = Formula['gcc@11'].opt_bin / 'g++-11'
    ENV.append 'CFLAGS', '-Os -DNDEBUG -s'
    ENV.append 'CXXFLAGS', '-Os -DNDEBUG -s'
    ENV.append 'CPPFLAGS', '-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include'
    # https://github.com/esnet/iperf/issues/632#issuecomment-334104098
    ENV.append 'LDFLAGS', '--static' if OS.linux?
    ENV.append 'LDFLAGS', '-static-libgcc -static-libstdc++' if OS.mac?

    system './configure', '--disable-shared', "--prefix=#{prefix}"
    system 'make', 'check'
    system 'make', 'install'
  end

  test do
    if OS.linux?
      output = shell_output("ldd #{bin}/xz 2>&1", 1).strip
      assert_equal 'not a dynamic executable', output
    elsif OS.mac?
      # TODO(@curoky): use `otool -L` to check.
    end

    assert_match "liblzma #{version}", shell_output("#{bin}/xz --version").strip

    path = testpath / 'data.txt'
    original_contents = '.' * 1000
    path.write original_contents

    # compress: data.txt -> data.txt.xz
    system bin / 'xz', path
    refute_predicate path, :exist?

    # decompress: data.txt.xz -> data.txt
    system bin / 'xz', '-d', "#{path}.xz"
    assert_equal original_contents, path.read
  end
end
