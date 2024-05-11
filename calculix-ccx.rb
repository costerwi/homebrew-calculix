class CalculixCcx < Formula
  desc "Three-Dimensional Finite Element Solver"
  homepage "http://www.calculix.de/"
  url "http://www.dhondt.de/ccx_2.21.src.tar.bz2"
  version "2.21.1"
  sha256 "52a20ef7216c6e2de75eae460539915640e3140ec4a2f631a9301e01eda605ad"

  livecheck do
    url :url
  end

  depends_on "pkg-config" => :build
  depends_on "arpack"
  depends_on "gcc" if OS.mac? # for gfortran

  resource "test" do
    version "2.21"
    url "http://www.dhondt.de/ccx_#{version}.test.tar.bz2"
    sha256 "094a0a2ec324fc6f937a96e932b488f48f31ad8d5d1186cd14437e6dc3e599ea"
  end

  resource "doc" do
    version "2.21"
    url "http://www.dhondt.de/ccx_#{version}.htm.tar.bz2"
    sha256 "1ed21976ba2188d334fe0b5917cf75b8065b9c0b939e6bd35bd98ed57a725ba2"
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
diff --git a/ccx_2.21/src/CalculiX.h b/ccx_2.21/src/CalculiX.h
index 8036211..77a312b 100644
--- a/ccx_2.21/src/CalculiX.h
+++ b/ccx_2.21/src/CalculiX.h
@@ -1624,6 +1624,18 @@ void FORTRAN(filter,(double *dgdxglob,ITG *nobject,ITG *nk,ITG *nodedesi,
                      ITG *ny,ITG *nz,ITG *neighbor,double *r,ITG *ndesia,
                      ITG *ndesib,double *xdesi,double *distmin));
 
+void FORTRAN(filter_backward,(double *au, ITG *jq, ITG *irow, ITG *icol, ITG *ndesi,
+          ITG *nodedesi, double *dgdxglob, ITG *nobject, ITG *nk,
+          ITG *nobjectstart, char *objectset));
+
+void FORTRAN(filter_forward,(double *gradproj1, ITG *nk1, ITG *nodedesi1,
+          ITG *ndesi1, char *objectset1,
+          double *xo1, double *yo1, double *zo1, double *x1, double *yy1, double *z1,
+          ITG *nx1, ITG *ny1, ITG *nz1, ITG *neighbor1,
+          double *r1, ITG *ndesia, ITG *ndesib, double *xdesi1,
+          double *distmin1, double *feasdir1,
+          double *filterval1));
+
 void filtermain(double *co,double *dgdxglob,ITG *nobject,ITG *nk,
                 ITG *nodedesi,ITG *ndesi,char *objectset,double *xdesi,
                 double *distmin);
@@ -1637,6 +1649,11 @@ void filtermain_forward(double *co,double *gradproj,ITG *nk,
                 ITG *nodedesi,ITG *ndesi,char *objectset,double *xdesi,
 		double *distmin,double *feasdir);
 
+void FORTRAN(filtermatrix,(double *au,ITG *jq, ITG *irow, ITG *icol, ITG *ndesi,
+            ITG *nodedesi, double *filterrad, double *co, ITG *nk,
+            double *denominator, char *objectset, double *filterval,
+            double *xdesi, double *distmin));
+
 void *filtermt(ITG *i);
 
 void *filter_forwardmt(ITG *i);
@@ -3380,6 +3397,13 @@ void FORTRAN(openfile,(char *jobname));
 
 void FORTRAN(openfilefluidfem,(char *jobname));
 
+void FORTRAN(packaging,(ITG *nodedesiboun1, ITG *ndesiboun1, char *objectset1,
+            double *xo1, double *yo1, double *zo1, double *x1, double *yy1, double *z1,
+            ITG *nx1, ITG *ny1, ITG *nz1, double *co1, ITG *ifree1,
+            ITG *ndesia, ITG *ndesib, ITG *iobject1, ITG *ndesi1,
+            double *dgdxglob1, ITG *nk1, double *extnor1,
+            double *g01, ITG *nodenum1));
+
 void packagingmain(double *co,ITG *nobject,ITG *nk,ITG *nodedesi,ITG *ndesi,
 		   char *objectset,char *set,ITG *nset,ITG *istartset,
 		   ITG *iendset,ITG *ialset,ITG *iobject,ITG *nodedesiinv,
@@ -3508,6 +3532,12 @@ void FORTRAN(prefilter,(double *co,ITG *nodedesi,ITG *ndesi,double *xo,
 void preiter(double *ad,double **aup,double *b,ITG **icolp,ITG **irowp,
              ITG *neq,ITG *nzs,ITG *isolver,ITG *iperturb);
 
+void FORTRAN(prepackaging,(double *co, double *xo, double *yo, double *zo,
+            double *x, double *y, double *z,
+            ITG *nx, ITG *ny, ITG *nz, ITG *ifree, ITG *nodedesiinv,
+            ITG *ndesiboun, ITG *nodedesiboun, char *set, ITG *nset, char *objectset,
+            ITG *iobject, ITG *istartset, ITG *iendset, ITG *ialset, ITG *nodenum));
+
 void preparll(ITG *mt,double *dtime,double *veold,double *scal1,
                    double *accold,double *uam,ITG *nactdof,double *v,
                    double *vold,double *scal2,ITG *nk,ITG *num_cpus);
diff --git a/ccx_2.21/src/Makefile b/ccx_2.21/src/Makefile
index d46da7d..3679990 100755
--- a/ccx_2.21/src/Makefile
+++ b/ccx_2.21/src/Makefile
@@ -25,7 +25,7 @@ LIBS = \
 	../../../ARPACK/libarpack_INTEL.a \
        -lpthread -lm -lc
 
-ccx_2.21: $(OCCXMAIN) ccx_2.21.a  $(LIBS)
+ccx_2.21: $(OCCXMAIN) ccx_2.21.a
 	./date.pl; $(CC) $(CFLAGS) -c ccx_2.21.c; $(FC)  -Wall -O2 -o $@ $(OCCXMAIN) ccx_2.21.a $(LIBS) -fopenmp
 
 ccx_2.21.a: $(OCCXF) $(OCCXC)
