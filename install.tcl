# Install tin in library
source tin.tcl
set dir [tin mkdir -force tin 0.4.3]
file copy tin.tcl $dir
file copy tinlist.tcl $dir
file copy pkgIndex.tcl $dir
file copy README.md $dir
file copy LICENSE $dir
