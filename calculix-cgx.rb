class CalculixCgx < Formula
  desc "Pre- and Postprocessor for CalculiX"
  homepage "http://www.calculix.de/"
  url "https://www.dhondt.de/cgx_2.22.all.tar.bz2"
  version "2.22"
  sha256 "c642431089560eec21b1a6a5d7f5a40bc23ea946115a296b8dd8cb8a596921d1"

  livecheck do
    url :url
  end

  depends_on "pkg-config" => :build
  depends_on "gcc"
  depends_on "mesa-glu"
  depends_on "libxi"
  depends_on "libxmu"

  def caveats
    <<~EOS
      XQuartz is required to run CalculiX GraphiX in non-background mode. You can install it manually with:
        brew install --cask xquartz
    EOS
  end

  # Apply patches
  patch :DATA

  # Build and install cgx
  def install
    # Build from source
    target = Pathname.new("CalculiX/cgx_#{version}/src/cgx")
    system "make", "-C", target.dirname
    bin.install target
    
    # Documentation and examples
    doc.install Dir["CalculiX/cgx_#{version}/doc"]
    pkgshare.install Dir["CalculiX/cgx_#{version}/examples/*"]
  end

  # Test cgx
  def test
    cp_r "#{HOMEBREW_PREFIX}/Cellar/#{name}/#{version}/share/#{name}/compressor", testpath
    system "#{bin}/cgx -bg -b compressor/send.fbl"
    assert_predicate testpath/"all.msh", :exist?
  end
end

__END__
diff --git a/CalculiX/cgx_2.22/src/Makefile b/CalculiX/cgx_2.22/src/Makefile
index 28b44ef..b00a692 100644
--- a/CalculiX/cgx_2.22/src/Makefile
+++ b/CalculiX/cgx_2.22/src/Makefile
@@ -1,16 +1,14 @@
 # on MacOS it might be necessary to remove -DSEMINIT
-CFLAGS = -O2 -Wall -Wno-narrowing -DSEMINIT \
+CFLAGS = -O2 -Wall -Wno-narrowing \
   -I./ \
-  -I/usr/include \
-  -I/usr/include/GL \
+  -I/opt/homebrew/include \
   -I../../libSNL/src \
-  -I../../glut-3.5/src \
-  -I/usr/X11/include 
+  -I../../glut-3.5/src
 
 LFLAGS = \
-  -L/usr/lib64 -lGL -lGLU \
-  -L/usr/X11R6/lib64 -lX11 -lXi -lXmu -lXext -lXt -lSM -lICE \
-  -lm -lpthread -lrt
+  -L/opt/homebrew/lib -lGL -lGLU \
+  -L/opt/homebrew/lib -lX11 -lXi -lXmu -lXext -lXt -lSM -lICE \
+  -lm -lpthread
