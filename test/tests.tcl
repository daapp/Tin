
# Load from build folder
puts "Loading package from build folder..."
source ../build/tin.tcl 

# Unit testing is done with the tcltest built-in package
package require tcltest
namespace import tcltest::*

# Tests expect that package prefer uses "stable"
if {[package prefer] eq "latest"} {
    error "tests require package prefer stable"
}

# Spoof ls-remote
# ------------------------------------------------------------------------------
# To spoof "ls-remote" on a local computer, this code creates an empty git 
# repository that then has its remote specified as the submodule "Tin-Test".

exec git init .
exec git remote add Tin-Test Tin-Test

# Add single package version to the Tin List
test add_versions {
    # Add spoof entries (does not check to see if they are valid until install)
} -body {
    tin add foo 1.0 https://github.com/username/foo v1.0 install_foo.tcl
    tin add foo 1.1 https://github.com/username/foo v1.1 install_foo.tcl
    tin add foo 2a0 https://github.com/username/foo v2a0 install_foo.tcl
    tin add foo 2.0 https://github.com/username/foo v2.0 install_foo.tcl
    tin add foo 2.0.1 https://github.com/username/foo v2.0.1 install_foo.tcl
    tin versions foo
} -result {1.0 1.1 2a0 2.0 2.0.1}

test add_packages {
    # Add packages to the Tin List
} -body {
    tin add tintest 1.0 Tin-Test v1.0 install.tcl   
    tin packages
} -result {foo tintest}

test remove_packages {
    # Remove "foo" from tin list
} -body {
    tin remove foo
    tin packages
} -result {tintest}

# get
test get1 {
    # Get the entire entry in Tin for one package
} -body {
    tin get tintest
} -result {1.0 {Tin-Test {v1.0 install.tcl}}}

test get2 {
    # Get the entry in Tin for a package/version
} -body {
    tin get tintest 1.0
} -result {Tin-Test {v1.0 install.tcl}}

test get3 {
    # Get the entry in Tin for a package/version/repo (tag & file)
} -body {
    tin get tintest 1.0 Tin-Test
} -result {v1.0 install.tcl}

# Auto-add packages
test autoadd1 {
    # Get all packages available
} -body {
    tin autoadd tintest Tin-Test install.tcl
} -result {0.1 0.1.1 0.2 0.3 0.3.1 0.3.2 1a0 1a1 1b0 1.0 1.1 1.2a0}

test autoadd2 {
    # Only add certain versions
} -body {
    tin autoadd tintest Tin-Test install.tcl 0.0
} -result {0.1 0.1.1 0.2 0.3 0.3.1 0.3.2}

test versions {
    # Adding uses 'dict set', so duplicates are ignored
} -body {
    tin versions tintest
} -result {0.1 0.1.1 0.2 0.3 0.3.1 0.3.2 1a0 1a1 1b0 1.0 1.1 1.2a0}

# uninstall (all)
test uninstall_installed {
    # Uninstall all versions of tintest prior to tests
} -body {
    tin uninstall tintest
    tin installed tintest
} -result {}

# remove, versions
test remove_versions {
    # Remove all versions with major number 0
} -body {
    foreach version [tin versions tintest 0-0.3] {
        tin remove tintest $version
    }
    tin versions tintest
} -result {0.3 0.3.1 0.3.2 1a0 1a1 1b0 1.0 1.1 1.2a0}

test available {
    # Get versions that would be installed with tin install (latest stable)
} -body {
    set versions ""
    lappend versions [tin available tintest 0]
    lappend versions [tin available tintest -exact 0.3]
    lappend versions [tin available tintest -exact 0.3.1]
    lappend versions [tin available tintest -exact 1a0]
    lappend versions [tin available tintest 1a0-1b10]
    lappend versions [tin available tintest 1-1]
    lappend versions [tin available tintest]
    set versions
} -result {0.3.2 0.3 0.3.1 1a0 1b0 1.0 1.1}

test install {
    # Install package
} -body {
    tin install tintest -exact 1.0
} -result {1.0}

test tin-check {
    # Check to see if package can be upgraded
} -body {
    tin check tintest
} -result {1.0 1.1}

test tin-upgrade {
    # Upgrade to latest and greatest (also uninstalls v1.0)
} -body {
    tin upgrade tintest
} -result {1.0 1.1}

# depend
test depend {
   # Ensure that tin depend does not install when package is installed
} -body {
    set i 0
    trace add execution ::tin::install enter {apply {args {global i; incr i}}}
    tin depend tintest -exact 0.3
    tin depend tintest -exact 0.3
    tin depend tintest -exact 0.3
    tin depend tintest -exact 0.3
    tin depend tintest -exact 0.3
    tin depend tintest -exact 0.3
    trace remove execution ::tin::install enter {apply {args {global i; incr i}}}
    set i
} -result {1}

test tin-upgrade_minor {
    # Upgrade a minor version
} -body {
    tin upgrade tintest 0.3
} -result {0.3 0.3.2}

test installed {
    # Make sure package is installed
} -body {
    tin installed tintest
} -result {1.1}

test uninstall {
    # Uninstall a package with a pkgUninstall file
} -body {
    tin uninstall tintest
    tin installed tintest
} -result {}

test import {
    # Install and import commands from a package
} -body {
    tin import foo from tintest
    foo
} -result {Hello World!}

test import2 {
    # Import other commands from a package already loaded
} -body {
    tin import bar from tintest
    bar
} -result {HELLO WORLD!}

test forget {
    # Forget a package
} -body {
    tin forget tintest
    list [package versions tintest] [namespace exists tintest]
} -result {{} 0}

# clear
test tin-clear {
    # Clear all entries (and uninstall tintest)
} -body {
    tin uninstall tintest
    tin clear
    tin packages
} -result {}

# mkdir 
test tin::mkdir {
    Test the name and version normalization features
} -body {
    set dirs ""
    lappend dirs [tin mkdir foo 1.5]
    lappend dirs [tin mkdir foo::bar 1.4]
    lappend dirs [tin mkdir foo 2.0.0]
    lmap dir $dirs {file tail $dir}
} -result {foo-1.5 foo_bar-1.4 foo-2.0}
file delete -force {*}$dirs

test tin::mkdir-versionerror {
    Throws error because version number is invalid
} -body {
    catch {tin mkdir -force $basedir foo 1.04}
} -result {1}

test tin::mkdir-nameerror {
    Throws error because package name is invalid
} -body {
    catch {tin mkdir -force $basedir foo_bar 1.5}
} -result {1}

# bake 
test tin::bake {
    Verify the text replacement of tin::bake
} -body {
    set doughFile [makeFile {Hello @WHO@!} dough.txt]
    set breadFile [makeFile {} bread.txt]
    tin bake $doughFile $breadFile {WHO World}
    viewFile $breadFile
} -result {Hello World!}

# Clean up
file delete $doughFile $breadFile

# Assert command
test assert_is {
    # Ensure that assert type works
} -body {
    tin assert 5.0 is double; # Asserts that 5.0 is indeed a number
    tin assert {hello world} is integer; # This is false
} -result "expected integer value but got \"hello world\""

test assert_== {
    # Ensure that math assert works
} -body {
    tin assert {2 + 2 == 4}; # Asserts that math works
    tin assert [expr {2 + 1}] == 4; # false
} -result "assert 3 == 4 failed"

test assert_noArgs {
    # Ensure that assert does not work without args
} -body {
    catch {tin assert} result
    set result
} -result "wrong # args: should be \"tin assert expr ?message?\""

test assert_1arg {
    # Ensure that assert works with only one argument
} -body {
    tin assert false
} -result {assert "false" failed}

test assert_2args {
    # Ensure that assert works with two args
} -body {
    tin assert false "input must be true"
} -result {input must be true
assert "false" failed}

test assert_too_many_args {
    # Ensure that assert does not work with too many args
} -body {
    catch {tin assert hello there hi there hey} result
    set result
} -result "wrong # args: should be \"tin assert value op expected ?message?\""

test assert_proc1 {
    # Validate input type in a proc
} -body {
    proc foo {a} {
        tin assert $a is double "\"a\" must be a number"
    }
    catch {foo bar} result
    set result
} -result {"a" must be a number
expected double value but got "bar"}

test assert_proc2 {
    # Validate input values in a proc
} -body {
    proc subtract {x y} {
        tin assert $x > $y {x must be greater than y}
        expr {$x - $y}
    }
    catch {subtract 2.0 3.0} result
    set result
} -result {x must be greater than y
assert 2.0 > 3.0 failed}

# Check number of failed tests
set nFailed $tcltest::numTests(Failed)

# Clean up
cleanupTests

# Delete spoofed repo
file delete -force .git

# If tests failed, return error
if {$nFailed > 0} {
    error "$nFailed tests failed"
}