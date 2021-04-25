class Tmux < Formula
  desc 'Terminal multiplexer'
  homepage 'https://tmux.github.io/'
  version ENV['HOMEBREW_TMUX_VERSION'] || '3.2a'
  url "https://github.com/tmux/tmux/releases/download/#{version}/tmux-#{version}.tar.gz"
  license 'ISC'

  keg_only :versioned_formula
  depends_on 'pkg-config' => :build
  depends_on 'libevent' => :build
  depends_on 'ncurses' => :build
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
    ENV.append 'LDFLAGS', '-lresolv'

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --sysconfdir=#{etc}
    ]

    system './configure', *args
    system 'make', 'install'
  end

  test do
    if OS.linux?
      output = shell_output("ldd #{bin}/tmux 2>&1", 1).strip
      assert_equal 'not a dynamic executable', output
    elsif OS.mac?
      # TODO(@curoky): use `otool -L` to check.
    end

    assert_equal "tmux #{version}", shell_output("#{bin}/tmux -V", 0).strip
  end
end
