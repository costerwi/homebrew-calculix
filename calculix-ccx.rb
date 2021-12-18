class CalculixCcx < Formula
  desc "Three-Dimensional Finite Element Solver"
  homepage "http://www.calculix.de/"
  url "http://www.dhondt.de/ccx_2.18.src.tar.bz2"
  version "2.18"
  sha256 "fad533bd66693daa398856262bf7c6feb12599c3051955238b0a70420852ff65"

  livecheck do
    url :url
  end

  depends_on "pkg-config" => :build
  depends_on "arpack"
  depends_on "gcc" if OS.mac? # for gfortran

  resource "test" do
    version "2.18"
    url "http://www.dhondt.de/ccx_#{version}.test.tar.bz2"
    sha256 "c5f771fc152d876366570b0d88032d908d912efb566ccddf070184acceeed7f4"
  end

  resource "doc" do
    version "2.18"
    url "http://www.dhondt.de/ccx_#{version}.htm.tar.bz2"
    sha256 "5b9cc5e6a1ef70bd93737b507cb754d485b229ec3cef31ea33501a74deff23e6"
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
diff --git a/ccx_2.18/src/CalculiX.h b/ccx_2.18/src/CalculiX.h
index c0f5e88..1ba6f5d 100644
--- a/ccx_2.18/src/CalculiX.h
+++ b/ccx_2.18/src/CalculiX.h
@@ -320,6 +320,10 @@ void FORTRAN(autocovmatrix,(double *co,double *ad,double *au,ITG *jqs,
 			    ITG *irows,ITG *ndesi,ITG *nodedesi,double *corrlen,
 			    double *randomval,ITG *irobustdesign));

+void FORTRAN(auglag_inclusion ,(int conttype, double *gcontfull, int nacti,
+            int ncdim, double mufric, double atol, double rtol, double *pkvec,
+            int kitermax, double timek ));
+
 void FORTRAN(basis,(double *x,double *y,double *z,double *xo,double *yo,
                     double *zo,ITG *nx,ITG *ny,ITG *nz,double *planfa,
                     ITG *ifatet,ITG *nktet,ITG *netet,double *field,
@@ -901,7 +905,7 @@ void FORTRAN(checktime,(ITG *itpamp,ITG *namta,double *tinc,double *ttime,
 void FORTRAN(checktruecontact,(ITG *ntie,char *tieset,double *tietol,
              double *elcon,ITG *itruecontact,ITG *ncmat_,ITG *ntmat_));

-void FORTRAN(clonesensitivies,(ITG *nobject,ITG *nk,char *objectset,
+void FORTRAN(clonesensitivities,(ITG *nobject,ITG *nk,char *objectset,
 			       double *g0,double *dgdxglob));

 void FORTRAN(closefile,());
@@ -1391,6 +1395,11 @@ void FORTRAN(detectactivecont1,(double *vold,ITG *nk,ITG *mi,double *aubi,
 				ITG *jqib,double *g,ITG *icolbb,ITG *nactdof,
 				double *qtmp));

+void FORTRAN(detectactivecont2,(double *gapnorm, double *gapdof,
+                double *auw, int *iroww, int *jqw,
+                int neqtot, int nslavs, double *springarea,
+                int *iacti, int nacti));
+
 void FORTRAN(determineextern,(ITG *ifac,ITG *itetfa,ITG *iedg,ITG *ipoed,
                               ITG *iexternedg,ITG *iexternfa,ITG *iexternnode,
                               ITG *nktet_,ITG *ipofa));
@@ -4674,6 +4683,8 @@ void FORTRAN(reinit_refine,(ITG *kontet,ITG *ifac,ITG *ieln,ITG *netet_,
                       ITG *newsize,ITG *ifatet,ITG *itetfa,ITG *iedg,
                       ITG *ieled));

+void FORTRAN(relaxval_al, (double *gcontfull, int nacti, int ncdim));
+
 void remastruct(ITG *ipompc,double **coefmpcp,ITG **nodempcp,ITG *nmpc,
 		ITG *mpcfree,ITG *nodeboun,ITG *ndirboun,ITG *nboun,
 		ITG *ikmpc,ITG *ilmpc,ITG *ikboun,ITG *ilboun,
@@ -6020,6 +6031,12 @@ void *u_realloc(void* num,size_t size,const char *file,const int line,const char

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
diff --git a/ccx_2.18/src/Makefile b/ccx_2.18/src/Makefile
index b32a52e..a95e611 100755
--- a/ccx_2.18/src/Makefile
+++ b/ccx_2.18/src/Makefile
@@ -25,7 +25,7 @@ LIBS = \
 	../../../ARPACK/libarpack_INTEL.a \
        -lpthread -lm -lc

-ccx_2.18: $(OCCXMAIN) ccx_2.18.a  $(LIBS)
+ccx_2.18: $(OCCXMAIN) ccx_2.18.a
 	./date.pl; $(CC) $(CFLAGS) -c ccx_2.18.c; $(FC)  -Wall -O2 -o $@ $(OCCXMAIN) ccx_2.18.a $(LIBS) -fopenmp

 ccx_2.18.a: $(OCCXF) $(OCCXC)
diff --git a/ccx_2.18/src/cubtri.f b/ccx_2.18/src/cubtri.f
index c13aa5b..831699f 100644
--- a/ccx_2.18/src/cubtri.f
+++ b/ccx_2.18/src/cubtri.f
@@ -77,7 +77,7 @@ C
      &  mw,nfe
       REAL*8 ALFA, ANS, ANSKP, AREA, EPS, ERR, ERRMAX, H, Q1, Q2, R1,R2,
      * RDATA(1), D(2,4), S(4), T(2,3), VEC(2,3), W(6,NW), X(2),zero,
-     & point5,one,rnderr
+     & point5,one,F,rnderr
 C       ACTUAL DIMENSION OF W IS (6,NW/6)
 C
       REAL*8 TANS, TERR, DZERO
diff --git a/ccx_2.18/src/date.pl b/ccx_2.18/src/date.pl
index 2b98376..f9184d2 100755
--- a/ccx_2.18/src/date.pl
+++ b/ccx_2.18/src/date.pl
@@ -13,7 +13,7 @@ while(<>){

 # inserting the date into ccx_2.18step.c

-@ARGV="ccx_2.18step.c";
+@ARGV="CalculiXstep.c";
 $^I=".old";
 while(<>){
     s/You are using an executable made on.*/You are using an executable made on $date\\n");/g;
@@ -30,5 +30,5 @@ while(<>){
 }

 system "rm -f ccx_2.18.c.old";
-system "rm -f ccx_2.18step.c.old";
+system "rm -f CalculiXstep.c.old";
 system "rm -f frd.c.old";
diff --git a/ccx_2.18/src/premortar.c b/ccx_2.18/src/premortar.c
index 62cd532..35905e9 100644
--- a/ccx_2.18/src/premortar.c
+++ b/ccx_2.18/src/premortar.c
@@ -19,6 +19,7 @@
 #include <math.h>
 #include <stdlib.h>
 #include <time.h>
+#include <string.h>
 #include "CalculiX.h"
 #include "mortar.h"

diff --git a/ccx_2.18/src/resultsmech_us3.f b/ccx_2.18/src/resultsmech_us3.f
index 1316f64..8e7d1a8 100644
--- a/ccx_2.18/src/resultsmech_us3.f
+++ b/ccx_2.18/src/resultsmech_us3.f
@@ -461,7 +461,7 @@
      &     ihyper,istiff,elconloc,eth,kode,plicon,
      &     nplicon,plkcon,nplkcon,npmat_,
      &     plconloc,mi(1),dtime,k,
-     &     xstiff,alcon)
+     &     xstiff,ncmat_)
           e     = elas(1)
           un    = elas(2)
           rho   = rhcon(1,1,imat)
diff --git a/ccx_2.18/src/sensi_coor.c b/ccx_2.18/src/sensi_coor.c
index 8c61ea9..66a4927 100644
--- a/ccx_2.18/src/sensi_coor.c
+++ b/ccx_2.18/src/sensi_coor.c
@@ -18,6 +18,7 @@
 #include <stdio.h>
 #include <math.h>
 #include <stdlib.h>
+#include <string.h>
 #include "CalculiX.h"

 void sensi_coor(double *co,ITG *nk,ITG **konp,ITG **ipkonp,char **lakonp,
diff --git a/ccx_2.18/src/sensi_orien.c b/ccx_2.18/src/sensi_orien.c
index f328ce1..36a5b4c 100644
--- a/ccx_2.18/src/sensi_orien.c
+++ b/ccx_2.18/src/sensi_orien.c
@@ -18,6 +18,7 @@
 #include <stdio.h>
 #include <math.h>
 #include <stdlib.h>
+#include <string.h>
 #include "CalculiX.h"

 void sensi_orien(double *co,ITG *nk,ITG **konp,ITG **ipkonp,char **lakonp,
diff --git a/ccx_2.18/src/us4_sub.f b/ccx_2.18/src/us4_sub.f
index 7305d6b..36d77f7 100644
--- a/ccx_2.18/src/us4_sub.f
+++ b/ccx_2.18/src/us4_sub.f
@@ -454,7 +454,7 @@
       REAL*8, INTENT(IN)  :: X(4,3),rho,h
       REAL*8, INTENT(OUT) :: M(24,24)
       REAL*8 :: ri,si,Nrs(4),dNr(4),dNs(4),Jm(2,2)
-      REAL*8 :: invJm,detJm,detinvJm,dNx(4),dNy(4),q1
+      REAL*8 :: invJm(2,2),detJm,detinvJm,dNx(4),dNy(4),q1
       REAL*8 :: m_3t(6,6), N_u(6,24),g_p(4,3)
       INTEGER :: k,j
       !
