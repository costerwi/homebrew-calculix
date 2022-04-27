class CalculixCcx < Formula
  desc "Three-Dimensional Finite Element Solver"
  homepage "http://www.calculix.de/"
  url "http://www.dhondt.de/ccx_2.20.src.tar.bz2"
  version "2.20"
  sha256 "63bf6ea09e7edcae93e0145b1bb0579ea7ae82e046f6075a27c8145b72761bcf"

  livecheck do
    url :url
  end

  depends_on "pkg-config" => :build
  depends_on "arpack"
  depends_on "gcc" if OS.mac? # for gfortran

  resource "test" do
    version "2.20"
    url "http://www.dhondt.de/ccx_#{version}.test.tar.bz2"
    sha256 "79848d88dd1e51839d1aed68fb547ff12ad3202c3561c02c2f3a8ceda0f2eb82"
  end

  resource "doc" do
    version "2.20"
    url "http://www.dhondt.de/ccx_#{version}.htm.tar.bz2"
    sha256 "51a0922f5cecc9fbe5880afb47c3b24ef90300fb800b4d10fb02b297e7c2b4c1"
  end

  resource "spooles" do
    # The spooles library is not currently maintained and so would not make a
    # good brew candidate. Instead it will be static linked to ccx.
    url "http://www.netlib.org/linalg/spooles/spooles.2.2.tgz"
    sha256 "a84559a0e987a1e423055ef4fdf3035d55b65bbe4bf915efaa1a35bef7f8c5dd"
  end

  # Add <pthread.h> to Calculix.h
  # u_free must return a void pointer
  patch :DATA

  def install
    (buildpath/"spooles").install resource("spooles")

    # Patch spooles library
    inreplace "spooles/Make.inc", "/usr/lang-4.0/bin/cc", ENV.cc
    inreplace "spooles/Tree/src/makeGlobalLib", "drawTree.c", "tree.c"

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
diff --git a/ccx_2.20/src/CalculiX.h b/ccx_2.20/src/CalculiX.h
index d01cfe17..7d30b7e2 100644
--- a/ccx_2.20/src/CalculiX.h
+++ b/ccx_2.20/src/CalculiX.h
@@ -761,7 +765,7 @@ void FORTRAN(checktime,(ITG *itpamp,ITG *namta,double *tinc,double *ttime,
 void FORTRAN(checktruecontact,(ITG *ntie,char *tieset,double *tietol,
              double *elcon,ITG *itruecontact,ITG *ncmat_,ITG *ntmat_));
 
-void FORTRAN(clonesensitivies,(ITG *nobject,ITG *nk,char *objectset,
+void FORTRAN(clonesensitivities,(ITG *nobject,ITG *nk,char *objectset,
 			       double *g0,double *dgdxglob));
 
 void FORTRAN(closefile,());
@@ -1181,6 +1185,11 @@ void FORTRAN(detectactivecont,(double *gapnorm,double *gapdisp,double *auw,
 			       ITG *iroww,ITG *jqw,ITG *nslavs,
 			       double *springarea,ITG *iacti,ITG *nacti));
 
+void FORTRAN(detectactivecont2,(double *gapnorm, double *gapdof,
+                double *auw, int *iroww, int *jqw,
+                int neqtot, int nslavs, double *springarea,
+                int *iacti, int nacti));
+
 void FORTRAN(determineextern,(ITG *ifac,ITG *itetfa,ITG *iedg,ITG *ipoed,
                               ITG *iexternedg,ITG *iexternfa,ITG *iexternnode,
                               ITG *nktet_,ITG *ipofa));
@@ -4959,6 +4968,12 @@ void *u_realloc(void* num,size_t size,const char *file,const int line,const char
 
 void utempread(double *t1,ITG *istep,char *jobnamec);
 
+double v_betrag(double *a);
+
+void v_prod( double *A, double *B, double *C );
+
+void v_result( const double *A, const double *B, double *C );
+
 void FORTRAN(varsmooth,(double *aub,double *adl,
 			     double *sol,double *aux,ITG *irow,
 			     ITG *jq,ITG *neqa,ITG *neqb,double *alpha));
diff --git a/ccx_2.20/src/Makefile b/ccx_2.20/src/Makefile
index d357f801..acea8218 100755
--- a/ccx_2.20/src/Makefile
+++ b/ccx_2.20/src/Makefile
@@ -25,7 +25,7 @@ LIBS = \
 	../../../ARPACK/libarpack_INTEL.a \
        -lpthread -lm -lc
 
-ccx_2.20: $(OCCXMAIN) ccx_2.20.a  $(LIBS)
+ccx_2.20: $(OCCXMAIN) ccx_2.20.a
 	./date.pl; $(CC) $(CFLAGS) -c ccx_2.20.c; $(FC)  -Wall -O2 -o $@ $(OCCXMAIN) ccx_2.20.a $(LIBS) -fopenmp
 
 ccx_2.20.a: $(OCCXF) $(OCCXC)
diff --git a/ccx_2.20/src/cubtri.f b/ccx_2.20/src/cubtri.f
index caf27384..43f3a89c 100644
--- a/ccx_2.20/src/cubtri.f
+++ b/ccx_2.20/src/cubtri.f
@@ -80,7 +80,7 @@ ccc   change on 15.07.2022 from RDATA(1) to RDATA(*) to comply with recent
 ccc   compiler versions
      *     RDATA(*), D(2,4), S(4), T(2,3), VEC(2,3), W(6,NW), X(2),zero,
 c     * RDATA(1), D(2,4), S(4), T(2,3), VEC(2,3), W(6,NW), X(2),zero,
-     & point5,one,rnderr
+     & point5,one,F,rnderr
 C       ACTUAL DIMENSION OF W IS (6,NW/6)
 C
       REAL*8 TANS, TERR, DZERO
diff --git a/ccx_2.20/src/date.pl b/ccx_2.20/src/date.pl
index 82f01116..6a7d2fe7 100755
--- a/ccx_2.20/src/date.pl
+++ b/ccx_2.20/src/date.pl
@@ -13,7 +13,7 @@ while(<>){
 
 # inserting the date into ccx_2.20step.c
 
-@ARGV="ccx_2.20step.c";
+@ARGV="CalculiXstep.c";
 $^I=".old";
 while(<>){
     s/You are using an executable made on.*/You are using an executable made on $date\\n");/g;
@@ -30,5 +30,5 @@ while(<>){
 }
 
 system "rm -f ccx_2.20.c.old";
-system "rm -f ccx_2.20step.c.old";
+system "rm -f CalculiXstep.c.old";
 system "rm -f frd.c.old";
diff --git a/ccx_2.20/src/premortar.c b/ccx_2.20/src/premortar.c
index 3ce85129..bda58978 100644
--- a/ccx_2.20/src/premortar.c
+++ b/ccx_2.20/src/premortar.c
@@ -19,6 +19,7 @@
 #include <math.h>
 #include <stdlib.h>
 #include <time.h>
+#include <string.h>
 #include "CalculiX.h"
 #include "mortar.h"
 
diff --git a/ccx_2.20/src/resultsmech_us3.f b/ccx_2.20/src/resultsmech_us3.f
index c76c509d..8d48220e 100644
--- a/ccx_2.20/src/resultsmech_us3.f
+++ b/ccx_2.20/src/resultsmech_us3.f
@@ -465,7 +465,7 @@
      &     xstiff,ncmat_)
           e     = elconloc(1)
           un    = elconloc(2)
-          rho   = rhcon(1,1,imat)        
+          rho   = rhcon(1,1,imat)
           alp(1) = eth(1)!alcon(1,1,imat)    
           alp(2) = eth(2)!alcon(1,1,imat)    
           alp(3) = 0.d0 
diff --git a/ccx_2.20/src/sensi_coor.c b/ccx_2.20/src/sensi_coor.c
index 12ad8587..80089c22 100644
--- a/ccx_2.20/src/sensi_coor.c
+++ b/ccx_2.20/src/sensi_coor.c
@@ -18,6 +18,7 @@
 #include <stdio.h>
 #include <math.h>
 #include <stdlib.h>
+#include <string.h>
 #include "CalculiX.h"
 
 void sensi_coor(double *co,ITG *nk,ITG **konp,ITG **ipkonp,char **lakonp,
diff --git a/ccx_2.20/src/sensi_orien.c b/ccx_2.20/src/sensi_orien.c
index b59af6f4..52568497 100644
--- a/ccx_2.20/src/sensi_orien.c
+++ b/ccx_2.20/src/sensi_orien.c
@@ -18,6 +18,7 @@
 #include <stdio.h>
 #include <math.h>
 #include <stdlib.h>
+#include <string.h>
 #include "CalculiX.h"
 
 void sensi_orien(double *co,ITG *nk,ITG **konp,ITG **ipkonp,char **lakonp,

