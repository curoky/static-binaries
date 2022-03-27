class Mold < Formula
  desc 'mold: A Modern Linker'
  homepage 'https://github.com/rui314/mold'
  url 'https://github.com/rui314/mold/archive/refs/heads/main.zip'
  version ENV['HOMEBREW_MOLD_VERSION'] || '1.1.1'
  license 'AGPL-3.0-only'

  depends_on 'pkg-config' => :build
  depends_on 'cmake' => :build
  depends_on 'mimalloc' => :build
  # depends_on 'tbb' => :build
  depends_on 'xxhash' => :build
  depends_on 'openssl@1.1' => :build
  depends_on 'zlib' => :build

  def install
    deps = Array['openssl@1.1', 'xxhash', 'zlib', 'mimalloc', 'tbb']
    ENV.prepend 'LDFLAGS', deps.map { |d| "-L#{Formula[d.to_s].opt_lib}" }.join(' ')
    ENV.prepend 'CPPFLAGS', deps.map { |d| "-I#{Formula[d.to_s].opt_include}" }.join(' ')

    # for static
    ENV.append 'CFLAGS', '-Os -DNDEBUG -s'
    ENV.append 'CXXFLAGS', '-Os -DNDEBUG -s'
    ENV.append 'EXTRA_LDFLAGS', '--static'

    # NOTE: brew's tbb doesn't have libtbb.a which is required by static link.
    # ENV['SYSTEM_TBB'] = '1'
    ENV['SYSTEM_MIMALLOC'] = '1'
    ENV['SYSTEM_XXHASH'] = '1'
    system 'make', "PREFIX=#{prefix}"
    system 'make', 'install', "PREFIX=#{prefix}"
  end

  test do
    output = shell_output("ldd #{bin}/mold 2>&1", 1).strip
    assert_equal 'not a dynamic executable', output

    # output = shell_output("#{bin}/mold --version")
    # assert_match 'mold', output.strip
  end
end
