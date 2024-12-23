class CalculixCcx < Formula
  desc "Three-Dimensional Finite Element Solver"
  homepage "http://www.calculix.de/"
  url "https://www.dhondt.de/ccx_2.22.src.tar.bz2"
  version "2.22"
  sha256 "3a94dcc775a31f570229734b341d6b06301ebdc759863df901c8b9bf1854c0bc"

  livecheck do
    url :url
  end

  depends_on "pkg-config" => :build
  depends_on "arpack"
  depends_on "gcc" if OS.mac? # for gfortran

  resource "test" do
    version "2.22"
    url "http://www.dhondt.de/ccx_#{version}.test.tar.bz2"
    sha256 "804c1ab099f5694b67955ddd72ad4708061019298c5d1d1788bf404d900b86fc"
  end

  resource "doc" do
    version "2.22"
    url "http://www.dhondt.de/ccx_#{version}.htm.tar.bz2"
    sha256 "de56c566fab9f0031cecd502acd0267d5aad8f76a238a594715306c42ab15afe"
  end

  resource "spooles" do
    # The spooles library is not currently maintained and so would not make a
    # good brew candidate. Instead it will be static linked to ccx.
    url "http://www.netlib.org/linalg/spooles/spooles.2.2.tgz"
    sha256 "a84559a0e987a1e423055ef4fdf3035d55b65bbe4bf915efaa1a35bef7f8c5dd"
  end

  # Apply patches
  patch :DATA

  def install
    (buildpath/"spooles").install resource("spooles")

    # Patch spooles library
    inreplace "spooles/Make.inc", "/usr/lang-4.0/bin/cc", ENV.cc
    inreplace "spooles/Tree/src/makeGlobalLib", "drawTree.c", "tree.c"
    inreplace "spooles/ETree/src/transform.c", "IVinit(nfront, NULL)", "IVinit(nfront, 0)"

    # Build serial spooles library
    system "make", "-C", "spooles", "lib"

    # Extend library with multi-threading (MT) subroutines
    system "make", "-C", "spooles/MT/src", "makeLib"

    # Buid Calculix ccx
    fflags= %w[-O2 -fopenmp]
    cflags = %w[-O2 -I../../spooles -DARCH=Linux -DSPOOLES -DARPACK -DMATRIXSTORAGE -DUSE_MT=1]
    libs = ["../../spooles/spooles.a"].concat(`pkg-config --libs arpack`.split)

    # ARPACK uses Accelerate on macOS and OpenBLAS on Linux
    libs << "-framework accelerate" if OS.mac?
    libs << "-lopenblas -pthread" if OS.linux? # OpenBLAS uses pthreads

    ENV.fortran
    args = ["CC=#{ENV.cc}",
            "FC=#{ENV.fc}",
            "CFLAGS=#{cflags.join(" ")}",
            "FFLAGS=#{fflags.join(" ")}",
            "LIBS=#{libs.join(" ")}"]
    target = Pathname.new("ccx_#{version}/src/ccx_#{version}")
    system "make", "-C", target.dirname, target.basename, *args
    bin.install target

    (buildpath/"test").install resource("test")
    pkgshare.install Dir["test/ccx_#{version}/test/*"]

    (buildpath/"doc").install resource("doc")
    doc.install Dir["doc/ccx_#{version}/doc/ccx/*"]
  end

  test do
    cp "#{pkgshare}/spring1.inp", testpath
    system "#{bin}/ccx_#{version}", "spring1"
  end
end

__END__
diff --git a/ccx_2.22/src/Makefile b/ccx_2.22/src/Makefile
index d46da7d..3679990 100755
--- a/ccx_2.22/src/Makefile
+++ b/ccx_2.22/src/Makefile
@@ -25,7 +25,7 @@ LIBS = \
 	../../../ARPACK/libarpack_INTEL.a \
        -lpthread -lm -lc
 
-ccx_2.22: $(OCCXMAIN) ccx_2.22.a  $(LIBS)
+ccx_2.22: $(OCCXMAIN) ccx_2.22.a
 	./date.pl; $(CC) $(CFLAGS) -c ccx_2.22.c; $(FC)  -Wall -O2 -o $@ $(OCCXMAIN) ccx_2.22.a $(LIBS) -fopenmp
 
 ccx_2.22.a: $(OCCXF) $(OCCXC)
