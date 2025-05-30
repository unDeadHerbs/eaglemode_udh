#!/usr/bin/perl
#-------------------------------------------------------------------------------
# make.pl
#
# Copyright (C) 2006-2011,2014,2017,2019-2020 Oliver Hamann.
#
# Homepage: http://eaglemode.sourceforge.net/
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 3 as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License version 3 for
# more details.
#
# You should have received a copy of the GNU General Public License version 3
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#-------------------------------------------------------------------------------

use strict;
use warnings;
use Config;
use Cwd;
use Cwd 'abs_path';
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec::Functions;
use IO::Handle;


#================================== Constants ==================================

my $ProjectName = 'eaglemode';
my $ProjectTitle = 'Eagle Mode';
my $ProjectComment = 'Zoomable user interface with plugin applications';
my $ProjectIcon = 'res/icons/eaglemode96.png';
my $ProjectCategories = 'System;FileManager;';
my $UniccDir = catfile("makers","unicc");
my $UtilsDir = catfile("makers","utils");
my $PackersDir = catfile("makers","packers");
my $MakersDir = "makers";
my $MakersEnding = ".maker.pm";
my $DefaultsMaker = "defaults";

my $BuildingDoneFile = catfile("obj","building_done");

my $DefaultInstallDirectory = catfile(
	($Config{'osname'} eq 'MSWin32') ?
		eval(
			"use Win32::TieRegistry;".
			"\$Registry->{'HKEY_LOCAL_MACHINE\\\\Software\\\\Microsoft\\\\'.".
			"             'Windows\\\\CurrentVersion\\\\\\\\ProgramFilesDir'}"
		)
	:
		'/usr/local'
	,
	$ProjectName
);

my $DirectorySeparator=substr(catfile("x","y"),1,1);

my $CLEAN_FLAG    = 1<<0;
my $INSTALL_FLAG  = 1<<1;
my $EXEC_FLAG     = 1<<2;
my $PRIVATE_FLAG  = 1<<3;
my $NOBACKUP_FLAG = 1<<4;


#================================== Functions ==================================

sub Help
	# Print help text.
	# Arguments: none
	# Returns: none
{
	print(
		"Usage:\n".
		"  perl $0 build [<option>=<value>]...\n".
		"    Compile and link.\n".
		"    Options:\n".
		"      compiler=<name>  (default: gnu)\n".
		"        Which compiler and linker to be used. For more information, please\n".
		"        read the Compilers section at the end of doc/html/MakeSystem.html.\n".
		"      projects=all|[not:]<name>[,<name>]... (default: all)\n".
		"        Which projects to be built. The keyword \"not:\" means to build all\n".
		"        but the given projects (except through dependencies).\n".
		"      continue=ask|yes|no  (default: ask)\n".
		"        What to do when there is an error in building a project which is\n".
		"        not essential.\n".
		"      debug=yes|no  (default: no)\n".
		"        Whether to have debug information in the binaries.\n".
		"      cpus=<n>  (default: auto)\n".
		"        Number of CPUs to be used. More precisely, it is the maximum\n".
		"        number of source files to be compiled in parallel. \"auto\" means\n".
		"        to detect the number of available cpus cores.\n".
		"      Further options may be defined by the maker scripts (see below).\n".
		"  perl $0 show-extra-options\n".
		"    Print a list of extra options for the build command, defined by the\n".
		"    maker scripts.\n".
		"  perl $0 install [<option>=<value>]...\n".
		"    Install the binaries and their required files.\n".
		"    Options:\n".
		"      dir=<target directory>  (default: $DefaultInstallDirectory)\n".
		"        Set the target directory. \n".
		"      menu=yes|no (default: no)\n".
		"        Whether to create a desktop start menu entry. This creates\n".
		"        the file /usr/\[local/\]share/applications/$ProjectName.desktop.\n".
		"      bin=yes|no (default: no)\n".
		"        Whether to create a binary in path. This creates\n".
		"        the file /usr/\[local/\]bin/$ProjectName.\n".
		"      root=<root directory> (default: <empty>)\n".
		"        A directory prefix which shall be prepended to the paths of all\n".
		"        installed files and directories without adapting the contents of\n".
		"        files generated by the menu and bin options. This is an advanced\n".
		"        option for packagers.\n".
		"      simulate=yes|no  (default: no)\n".
		"        If this is set to yes, installation is not really performed, but\n".
		"        it is shown what would be installed.\n".
		"  perl $0 pack <type>\n".
		"    Create a binary or source package for distribution and/or installation.\n".
		"    This does NOT require to call build before. Possible types are:\n".
		"      deb    - Debian package.\n".
		"      ebuild - Gentoo build file.\n".
		"      exe    - Windows setup executable.\n".
		"      rpm    - Red Hat package.\n".
		"      sb     - Slax bundle.\n".
		"      txz    - Slackware package.\n".
		"      tar.bz2, tar.gz or zip - Source package.\n".
		"    The packages are created in a subdirectory named \"packages\".\n".
		"  perl $0 clean [<option>=<value>]...\n".
		"    Delete generated files.\n".
		"    Options:\n".
		"      level=0|1  (default: 1)\n".
		"        0 - Delete generated files which are not needed for installation\n".
		"            and execution.\n".
		"        1 - Delete all generated files.\n".
		"      simulate=yes|no  (default: no)\n".
		"        If this is set to yes, deletion is not really performed, but it is\n".
		"        shown what would be deleted.\n".
		"  perl $0 list [<option>=<value>]...\n".
		"    Print a list of files and directories.\n".
		"    Options:\n".
		"      filter=[+|-<flag>[+|-<flag>...]] (default: <no filter>)\n".
		"        Only list files that have certain flags set (+) or unset (-).\n".
		"        Possible flags are: clean, install, exec, private, nobackup.\n".
		"      listdirs=yes|no (default: no)\n".
		"        Whether to include directories in the listing.\n".
		"      includeparent=yes|no (default: no)\n".
		"        Whether to include the name of the parent directory in the paths.\n".
		"  perl $0 help\n".
		"    Print this help.\n"
	);
}


sub LoadAllMakers
	# Load all the maker files ("do" them).
	# Arguments: none
	# Returns: @ - array of the names of all the makers.
{
	my $elen=length($MakersEnding);
	my @names=();
	my $dh;

	# Get all names of makers, without MakersEnding.
	opendir($dh,$MakersDir);
	while (defined(my $s=readdir($dh))) {
		if (substr($s,-$elen,$elen) eq $MakersEnding) {
			push(@names,substr($s,0,length($s)-$elen));
		}
	}
	closedir($dh);

	# Sort the makers by name (but see more below). This is just to avoid
	# random order.
	@names=sort(@names);

	# Do the maker files.
	for (my $i=0; $i<@names; $i++) {
		my $path=catfile($MakersDir,"$names[$i]$MakersEnding");
		$path=abs_path($path); # do(..) may fail on relative path.
		do($path);
		if ($@) {
			die("$@");
		}
		elsif ($!) {
			die("Could not execute $path: $!, stopped");
		}
	}

	# Bring the essential makers to the beginning so that they are called
	# first. This avoids wasting time with unessential things before failing
	# by something essential.
	for (my $i=0, my $j=0; $i<@names; $i++) {
		if ($names[$i]->IsEssential()) {
			if ($i>$j) { splice(@names,$j,0,splice(@names,$i,1)); }
			$j++;
		}
	}

	return @names;
}


sub AD_Recurse
	# Helper function for ApplyDependencies.
	# Arguments:
	#   \@ - Reference to the resulting array of makers.
	#   \@ - Reference to a hash table with states for all makers
	#        (0=it exists, 1=on stack, 2=in result).
	#   @  - The maker to add.
	# Returns: none
{
	my $resultRef=shift;
	my $stateRef=shift;
	my $maker=shift;

	if (!exists($$stateRef{$maker})) {
		die("Unknown project '$maker', stopped");
	}
	elsif ($$stateRef{$maker} eq 0) {
		$$stateRef{$maker}=1;
		my @dependencies=$maker->GetDependencies();
		for (my $i=0; $i<@dependencies; $i++) {
			AD_Recurse($resultRef,$stateRef,$dependencies[$i]);
		}
		push(@$resultRef,$maker);
		$$stateRef{$maker}=2;
	}
	elsif ($$stateRef{$maker} eq 1) {
		die("Circular dependencies with project '$maker', stopped");
	}
}


sub ApplyDependencies
	# Apply the dependencies on a set of makers. The defaults maker is
	# automatically included.
	# Arguments:
	#   \@ - Reference to array of all loaded makers (read only).
	#   @  - Array of target makers.
	# Returns:
	#   @ - Sorted array of makers to be executed.
{
	my $allRef=shift;
	my @makers=@_;
	my @result=();
	my %state=();

	for (my $i=0; $i<@$allRef; $i++) {
		$state{$$allRef[$i]}=0;
	}
	AD_Recurse(\@result,\%state,$DefaultsMaker);
	for (my $i=0; $i<@makers; $i++) {
		AD_Recurse(\@result,\%state,$makers[$i]);
	}
	return @result;
}


sub GetFileHandlingRules
	# Get the file handling rules from the makers in a translated form.
	# Arguments:
	#   \@ - Reference to array of all loaded makers with the dependencies
	#        already applied (read only).
	# Returns:
	#   @ - An array of references to rules: Each rule is an array of three
	#       things: a flag mask for the and-operation, a flag mask for the
	#       or-operation and the regex-pattern.
{
	my $allMakersRef=shift;
	my @rules=();

	for (my $i=0; $i<@$allMakersRef; $i++) {
		my $maker=$$allMakersRef[$i];
		my @origRules=$maker->GetFileHandlingRules();
		for (my $j=0; $j<@origRules; $j++) {
			my $origRule=$origRules[$j];
			my $k=index($origRule,':');
			if ($k <= 0) {
				die("No colon in file handling rule '$origRule' from project '$maker', stopped");
			}
			my $pattern=substr($origRule,$k+1);
			my $ops=substr($origRule,0,$k);
			my $andMask=0xff;
			my $orMask=0;
			do {
				my $eat;
				if ($ops =~ /^\+clean/) {
					$orMask|=$CLEAN_FLAG;
					$eat=6;
				}
				elsif ($ops =~ /^-clean/) {
					$andMask&=(~$CLEAN_FLAG);
					$eat=6;
				}
				elsif ($ops =~ /^\+install/) {
					$orMask|=$INSTALL_FLAG;
					$eat=8;
				}
				elsif ($ops =~ /^-install/) {
					$andMask&=(~$INSTALL_FLAG);
					$eat=8;
				}
				elsif ($ops =~ /^\+exec/) {
					$orMask|=$EXEC_FLAG;
					$eat=5;
				}
				elsif ($ops =~ /^-exec/) {
					$andMask&=(~$EXEC_FLAG);
					$eat=5;
				}
				elsif ($ops =~ /^\+private/) {
					$orMask|=$PRIVATE_FLAG;
					$eat=8;
				}
				elsif ($ops =~ /^-private/) {
					$andMask&=(~$PRIVATE_FLAG);
					$eat=8;
				}
				elsif ($ops =~ /^\+nobackup/) {
					$orMask|=$NOBACKUP_FLAG;
					$eat=9;
				}
				elsif ($ops =~ /^-nobackup/) {
					$andMask&=(~$NOBACKUP_FLAG);
					$eat=9;
				}
				else {
					die("Error in file handling rule '$origRule' from project '$maker', stopped");
				}
				$ops=substr($ops,$eat);
			} while (length($ops) != 0);
			push(@rules,[$andMask,$orMask,$pattern]);
		}
	}
	return @rules;
}


sub GetFileHandling
	# Get the handling flags for a file.
	# Arguments:
	#   \@ - Reference to the file handling rules returned by
	#        GetFileHandlingRules (read only).
	#   @  - The relative path of the file.
	# Returns:
	#   $ - Combination of the flags $CLEAN_FLAG, $INSTALL_FLAG, $EXEC_FLAG,
	#       $PRIVATE_FLAG and $NOBACKUP_FLAG.
{
	my $rulesRef=shift;
	my $path=shift;

	# Translate the directory separators to '/' in the path (only for the
	# pattern matching).
	if ($DirectorySeparator ne '/') {
		for (my $i=0; $i>=0;) {
			$i=index($path,$DirectorySeparator,$i);
			if ($i>=0) {
				$path=
					substr($path,0,$i).
					'/'.
					substr($path,$i+length($DirectorySeparator))
				;
			}
		}
	}

	# Apply the rules.
	my $flags=0;
	for (my $i=0; $i<@$rulesRef; $i++) {
		my $rule=$$rulesRef[$i];
		if ($path =~ $$rule[2]) {
			$flags &= $$rule[0];
			$flags |= $$rule[1];
		}
	}

	return $flags;
}


sub GetExtraBuildOptions
	# Get the extra build options from the makers.
	# Arguments:
	#   \@ - Reference to array of all loaded makers (read only).
	# Returns:
	#   @ - An array of references: each element is an array of four
	#       things: option name, default value, description and maker name.
{
	my $allMakersRef=shift;
	my @allOpts=();

	for (my $i=0; $i<@$allMakersRef; $i++) {
		my $maker=$$allMakersRef[$i];
		my @opts=$maker->GetExtraBuildOptions();
		for (my $j=0; $j<@opts; $j++) {
			my $opt=$opts[$j];
			push(@allOpts,[$$opt[0],$$opt[1],$$opt[2],$maker]);
		}
	}
	return @allOpts;
}


sub IsDirectoryEmpty
	# Check whether a directory is empty.
	# Arguments:
	#   $ - The directory.
	# Returns:
	#   $ - 1 if empty, 0 if not.
{
	my $dir=shift;
	my $dh;

	opendir($dh,$dir);
	while (defined(my $name=readdir($dh))) {
		if ($name ne "." and $name ne "..") {
			closedir($dh);
			return 0;
		}
	}
	closedir($dh);
	return 1;
}


sub ReadDirectoryTree
	# Read a directory tree and return a sorted array of all paths.
	# Arguments:
	#  Optional: $ - The directory to be read.
	#  Optional: $ - A prefix to be prepended to the resulting paths.
	#  Optional: $ - Whether to have children before parents in the list.
	# Returns:
	#  @ - Sorted array of all paths.
{
	my $dir=shift;
	if (!defined($dir)) { $dir="."; }
	my $prefix=shift;
	if (!defined($prefix)) { $prefix=""; }
	my $childrenBeforeParents=shift;
	if (!defined($childrenBeforeParents)) { $childrenBeforeParents=0; }

	my $dh;
	opendir($dh,$dir);
	my @names=sort(readdir($dh));
	closedir($dh);

	my @result=();
	for (my $i=0; $i<@names; $i++) {
		my $name=$names[$i];
		if ($name ne "." and $name ne "..") {
			if ($childrenBeforeParents == 0) {
				push(@result,$prefix.$name);
			}
			my $subDir=catfile($dir,$name);
			if (-d($subDir)) {
				my $subPrefix=$prefix.$name.$DirectorySeparator;
				push(
					@result,
					ReadDirectoryTree($subDir,$subPrefix,$childrenBeforeParents)
				);
			}
			if ($childrenBeforeParents != 0) {
				push(@result,$prefix.$name);
			}
		}
	}
	return @result;
}


sub Build
	# Perform the build command.
	# Arguments:
	#   @ - The options.
	# Results: none
{
	# Load the makers.
	my @allMakers=LoadAllMakers();

	# Prepare default options.
	my %options=(
		'compiler', 'gnu',
		'projects', 'all',
		'continue', 'ask',
		'debug', 'no',
		'cpus', 'auto'
	);
	my @extraOpts=GetExtraBuildOptions(\@allMakers);
	for (my $i=0; $i<@extraOpts; $i++) {
		$options{$extraOpts[$i]->[0]}=$extraOpts[$i]->[1];
	}

	# Parse option arguments.
	for (my $i=0; $i<@_; $i++) {
		my $e=index($_[$i],"=");
		if ($e<0) {
			die("Not a valid option: '$_[$i]', stopped");
		}
		my $name=substr($_[$i],0,$e);
		my $value=substr($_[$i],$e+1);
		if (!defined($options{$name})) {
			die("Unknown option name '$name', stopped");
		}
		$options{$name}=$value;
	}

	# Perform some checks on the options.
	if ($options{'continue'} !~ /^(ask|yes|no)$/) {
		die("Illegal value for option 'continue', stopped");
	}
	if ($options{'debug'} !~ /^(yes|no)$/) {
		die("Illegal value for option 'debug', stopped");
	}

	# Add an option for the path of the unicc directory.
	$options{'unicc'}=$UniccDir;

	# Add an option for the unicc call.
	$options{'unicc_call'}=[
		'perl', catfile($UniccDir,'unicc.pl'),
		'--compiler', $options{'compiler'},
		'--cpus', $options{'cpus'},
		$options{'debug'} eq 'yes' ? ("--debug") : ()
	];

	# Add an option for the path of the utils directory.
	$options{'utils'}=$UtilsDir;

	# Parse the 'projects' option and fill the array @makers.
	my @makers=();
	my $projects=$options{'projects'};
	if ($projects eq 'all') {
		@makers=@allMakers;
	}
	else {
		my $not=0;
		if (index($projects,'not:')==0) {
			$not=1;
			@makers=@allMakers;
			$projects=substr($projects,4);
		}
		while (length($projects)>0) {
			my $i=index($projects,',');
			my $n;
			if ($i<0) {
				$n=$projects;
				$projects='';
			}
			else {
				$n=substr($projects,0,$i);
				$projects=substr($projects,$i+1);
			}
			for ($i=@allMakers-1; ; $i--) {
				if ($i<0) { die("Unknown project \"$n\", stopped"); }
				if ($allMakers[$i] eq $n) { last; }
			}
			if ($not) {
				for ($i=@makers-1; $i>=0; $i--) {
					if ($makers[$i] eq $n) { splice(@makers,$i,1); }
				}
			}
			else {
				push(@makers,$n);
			}
		}
	}

	# Apply dependencies on the array of makers.
	@makers=ApplyDependencies(\@allMakers,@makers);

	# Remove the "building done" file (created again on success more below).
	if (-e($BuildingDoneFile)) {
		unlink($BuildingDoneFile);
	}

	my @failedNonEssentialMakers=();

	# Loop for the makers.
	for (my $i=0; $i<@makers; $i++) {
		my $maker=$makers[$i];

		# Print a header.
		print("### $maker ###\n");

		# Call the maker and check the result.
		# Remember that ...->Build(%options) automatically prepends an
		# argument which should be ignored by the implementation.
		my $result;
		eval { $result=$maker->Build(%options); };
		if ($@) {
			print(STDERR $@);
			$result=0;
		}
		if ($result==0) {
			if ($maker->IsEssential()) {
				print(
					"---\n".
					"Building $maker failed!\n"
				);
				exit(1);
			}
			elsif ($options{"continue"} eq "no") {
				print(
					"---\n".
					"Building $maker failed, but that project is not so essential.\n".
					"So if you did not mean to stop at this point, restart with option\n".
					"\"continue=ask\" or \"continue=yes\".\n"
				);
				exit(1);
			}
			elsif ($options{"continue"} eq "yes") {
				push(@failedNonEssentialMakers,$maker);
			}
			else {
				push(@failedNonEssentialMakers,$maker);
				print(
					"---\n".
					"Building $maker failed, but that project is not so essential.\n".
					"So if you don't know how to solve the problem, then you could\n".
					"continue the overall building now, and live without the features\n".
					"the project provides. Continue? [y(es)/n(o)/a(lways)]: "
				);
				for (my $again=1; $again eq 1;) {
					STDOUT->flush();
					my $ln=readline(*STDIN);
					$.=0; # for that a call to die will not print an input line number.
					if ($ln =~ /^\s*[nN]/) {
						exit(1);
					}
					elsif ($ln =~ /^\s*[yY]/) {
						$again=0;
					}
					elsif ($ln =~ /^\s*[aA]/) {
						$options{"continue"}="yes";
						$again=0;
					}
					elsif ($ln =~ /^\s*[rR]/) {
						# *** secret option: "retry" ***
						# I'm not satisfied with this, because:
						#  - The maker scripts are not reloaded (no effect if edited).
						#  - It's only for non-essential projects...
						pop(@failedNonEssentialMakers);
						$i--;
						$again=0;
					}
					else {
						print("Say yes, no or always: ");
					}
				}
			}
		}
	}

	# Create a file as an internal hint that installation is allowed now.
	my $fh;
	open($fh,">",$BuildingDoneFile);
	close($fh);

	# Print final messages.
	if (@failedNonEssentialMakers != 0) {
		print(
			"---\n".
			"Building succeeded! (But you will have to live without:"
		);
		for (my $i=0; $i<@failedNonEssentialMakers; $i++) {
			if ($i>0) { print(","); }
			print(" $failedNonEssentialMakers[$i]");
		}
		print(")\n");
	}
	else {
		print(
			"---\n".
			"Building succeeded!\n"
		);
	}
	if ($Config{'osname'} eq "cygwin") {
		print(
			"\n".
			"*************************************************************************\n".
			"*** VERY IMPORTANT: By all means, before starting the program, please ***\n".
			"*** rebase all the Cygwin DLLs together with the DLLs built by this   ***\n".
			"*** project (subdirectory 'lib'). If you do not know how to do that,  ***\n".
			"*** get familiar with the Cygwin program 'rebaseall'.                 ***\n".
			"*************************************************************************\n".
			"\n"
		);
	}
}


sub ShowExtraOptions
	# Perform the show-extra-options command.
	# Arguments: none
	# Results: none
{
	my @allMakers=LoadAllMakers();
	my @lst=GetExtraBuildOptions(\@allMakers);
	my $maker="";
	for (my $i=0; $i<@lst; $i++) {
		if ($maker ne $lst[$i]->[3]) {
			$maker=$lst[$i]->[3];
			print("### $maker ###\n");
		}
		print("$lst[$i]->[2]\n");
	}
}


sub Install
	# Perform the install command.
	# Arguments:
	#   @ - The options.
	# Results: none
{
	my $dir=$DefaultInstallDirectory;
	my $haveMenu=0;
	my $haveBin=0;
	my $rootPrefix="";
	my $simulate=0;
	for (my $i=0; $i<@_; $i++) {
		my $e=index($_[$i],"=");
		if ($e<0) {
			die("Not a valid option: '$_[$i]', stopped");
		}
		my $name=substr($_[$i],0,$e);
		my $value=substr($_[$i],$e+1);
		if ($name eq 'dir') {
			$dir=$value;
		}
		elsif ($name eq 'menu') {
			if ($value eq 'no') { $haveMenu=0; }
			elsif ($value eq 'yes') {
				if ($Config{'osname'} eq 'MSWin32') {
					die "The menu option is not yet supported for this operating system, stopped";
				}
				$haveMenu=1;
			}
			else { die("Illegal value for option 'menu', stopped"); }
		}
		elsif ($name eq 'bin') {
			if ($value eq 'no') { $haveBin=0; }
			elsif ($value eq 'yes') {
				if ($Config{'osname'} eq 'MSWin32') {
					die "The bin option is not yet supported for this operating system, stopped";
				}
				$haveBin=1;
			}
			else { die("Illegal value for option 'bin', stopped"); }
		}
		elsif ($name eq 'root') {
			$rootPrefix=$value;
		}
		elsif ($name eq 'simulate') {
			if ($value eq 'no') { $simulate=0; }
			elsif ($value eq 'yes') { $simulate=1; }
			else { die("Illegal value for option 'simulate', stopped"); }
		}
		else {
			die("Unknown option name '$name', stopped");
		}
	}

	my @rawMakers=LoadAllMakers();
	my @makers=ApplyDependencies(\@rawMakers,@rawMakers);
	my @rules=GetFileHandlingRules(\@makers);
	my @allPaths=ReadDirectoryTree();

	if (!-e($BuildingDoneFile)) {
		die("Please run 'perl $0 build' first.\n");
	}

	my $outDir=$rootPrefix.$dir;

	if (!-e($outDir)) {
		print("Making directory $outDir\n");
		if ($simulate == 0) {
			if (!mkpath($outDir,0,0755)) {
				die "Failed to create directory \"$outDir\": $!";
			}
		}
	}
	for (my $i=0; $i<@allPaths; $i++) {
		my $path=$allPaths[$i];
		my $flags=GetFileHandling(\@rules,$path);
		if (($flags&$INSTALL_FLAG)!=0) {
			my $tgtPath=catfile($outDir,$path);
			if (-d($path)) {
				if (!-e($tgtPath)) {
					print("Making directory $tgtPath\n");
					if ($simulate == 0) {
						if (!mkpath($tgtPath,0,0755)) {
							die "Failed to create directory \"$tgtPath\": $!";
						}
					}
				}
			}
			else {
				print("Installing file  $tgtPath\n");
				if ($simulate == 0) {
					if (!copy($path,$tgtPath)) {
						die "Failed to copy \"$path\" to \"$tgtPath\": $!";
					}
					my $mode;
					if (($flags&$EXEC_FLAG)!=0) {
						$mode=0755;
					}
					else {
						$mode=0644;
					}
					if (!chmod($mode,$tgtPath)) {
						die "Failed to chmod \"$tgtPath\": $!";
					}
				}
			}
		}
	}

	if ($haveMenu) {
		my $menuDir;
		if (index($dir,"/usr/local/")==0) { $menuDir="/usr/local/share/applications"; }
		else { $menuDir="/usr/share/applications"; }
		$menuDir=$rootPrefix.$menuDir;
		my $menuFile=catfile($menuDir,$ProjectName.'.desktop');
		if (!-e($menuDir)) {
			print("Making directory $menuDir\n");
			if ($simulate == 0) {
				if (!mkpath($menuDir,0,0755)) {
					die "Failed to create directory \"$menuDir\": $!";
				}
			}
		}
		print("Installing file  $menuFile\n");
		if ($simulate == 0) {
			my $fh;
			open($fh,">",$menuFile);
			print($fh
				"[Desktop Entry]\n".
				"Name=$ProjectTitle\n".
				"Comment=$ProjectComment\n".
				"Exec=$dir/$ProjectName.sh\n".
				"Icon=$dir/$ProjectIcon\n".
				"Terminal=false\n".
				"Type=Application\n".
				"Categories=$ProjectCategories\n".
				"StartupNotify=true\n"
			);
			close($fh);
			if (!chmod(0644,$menuFile)) {
				die "Failed to chmod \"$menuFile\": $!";
			}
		}
	}

	if ($haveBin) {
		my $binDir;
		if (index($dir,"/usr/local/")==0) { $binDir="/usr/local/bin"; }
		else { $binDir="/usr/bin"; }
		$binDir=$rootPrefix.$binDir;
		my $binFile=catfile($binDir,$ProjectName);
		if (!-e($binDir)) {
			print("Making directory $binDir\n");
			if ($simulate == 0) {
				if (!mkpath($binDir,0,0755)) {
					die "Failed to create directory \"$binDir\": $!";
				}
			}
		}
		print("Installing file  $binFile\n");
		if ($simulate == 0) {
			my $fh;
			open($fh,">",$binFile);
			print($fh
				"#!/bin/sh\n".
				"exec \"$dir/$ProjectName.sh\" \"\$@\"\n"
			);
			close($fh);
			if (!chmod(0755,$binFile)) {
				die "Failed to chmod \"$binFile\": $!";
			}
		}
	}
}


sub Pack
	# Perform the pack command.
{
	my $type=shift;
	if (!defined($type)) {
		print(STDERR "You must specify a package type.\n");
		exit(1);
	}
	$type=~tr/./-/;
	my $path=catfile($PackersDir,'pack_'.$type.'_private.pl');
	if (!-e $path) { $path=catfile($PackersDir,'pack_'.$type.'.pl'); }
	system("perl",$path,@_)==0 || exit(1);
}


sub Clean
	# Perform the clean command.
	# Arguments:
	#   @ - The options.
	# Results: none
{
	my $level=1;
	my $simulate=0;
	for (my $i=0; $i<@_; $i++) {
		my $e=index($_[$i],"=");
		if ($e<0) {
			die("Not a valid option: '$_[$i]', stopped");
		}
		my $name=substr($_[$i],0,$e);
		my $value=substr($_[$i],$e+1);
		if ($name eq 'level') {
			if ($value eq '0') { $level=0; }
			elsif ($value eq '1') { $level=1; }
			else { die("Illegal value for option 'level', stopped"); }
		}
		elsif ($name eq 'simulate') {
			if ($value eq 'no') { $simulate=0; }
			elsif ($value eq 'yes') { $simulate=1; }
			else { die("Illegal value for option 'simulate', stopped"); }
		}
		else {
			die("Unknown option name '$name', stopped");
		}
	}

	my @rawMakers=LoadAllMakers();
	my @makers=ApplyDependencies(\@rawMakers,@rawMakers);
	my @rules=GetFileHandlingRules(\@makers);
	my @allPaths=ReadDirectoryTree(".","",1);

	if ($level>=1 and -e($BuildingDoneFile)) {
		print("Removing $BuildingDoneFile\n");
		if ($simulate == 0) {
			unlink($BuildingDoneFile) || die($!);
		}
	}

	for (my $i=0; $i<@allPaths; $i++) {
		my $path=$allPaths[$i];
		my $flags=GetFileHandling(\@rules,$path);
		if (
			($flags&$CLEAN_FLAG)!=0 and
			(($flags&$INSTALL_FLAG)==0 or $level>=1) and
			$path ne $BuildingDoneFile
		) {
			if (-d($path)) {
				if (IsDirectoryEmpty($path)==1) {
					print("Removing $path\n");
					if ($simulate == 0) {
						rmdir($path) || die($!);
					}
				}
			}
			else {
				print("Removing $path\n");
				if ($simulate == 0) {
					unlink($path) || die($!);
				}
			}
		}
	}
}


sub List
	# Perform the list command.
	# Arguments:
	#   @ - The options.
	# Results: none
{
	my $filterSet=0;
	my $filterUnset=0;
	my $listdirs=0;
	my $includeparent=0;

	for (my $i=0; $i<@_; $i++) {
		my $e=index($_[$i],"=");
		if ($e<0) {
			die("Not a valid option: '$_[$i]', stopped");
		}
		my $name=substr($_[$i],0,$e);
		my $value=substr($_[$i],$e+1);
		if ($name eq 'filter') {
			$filterSet=0;
			$filterUnset=0;
			while (length($value) != 0) {
				my $op;
				if ($value =~ /^\+/) {
					$op=1;
				}
				elsif ($value =~ /^-/) {
					$op=0;
				}
				else {
					die("Illegal value for option 'filter', stopped");
				}
				$value=substr($value,1);
				my $eat;
				my $flag;
				if ($value =~ /^clean/) {
					$flag=$CLEAN_FLAG;
					$eat=5;
				}
				elsif ($value =~ /^install/) {
					$flag=$INSTALL_FLAG;
					$eat=7;
				}
				elsif ($value =~ /^exec/) {
					$flag=$EXEC_FLAG;
					$eat=4;
				}
				elsif ($value =~ /^private/) {
					$flag=$PRIVATE_FLAG;
					$eat=7;
				}
				elsif ($value =~ /^nobackup/) {
					$flag=$NOBACKUP_FLAG;
					$eat=8;
				}
				else {
					die("Illegal value for option 'filter', stopped");
				}
				$value=substr($value,$eat);
				if ($op) { $filterSet|=$flag; }
				else  { $filterUnset|=$flag; }
			}
		}
		elsif ($name eq 'listdirs') {
			if ($value eq 'no') { $listdirs=0; }
			elsif ($value eq 'yes') { $listdirs=1; }
			else { die("Illegal value for option 'listdirs', stopped"); }
		}
		elsif ($name eq 'includeparent') {
			if ($value eq 'no') { $includeparent=0; }
			elsif ($value eq 'yes') { $includeparent=1; }
			else { die("Illegal value for option 'includeparent', stopped"); }
		}
		else {
			die("Unknown option name '$name', stopped");
		}
	}

	my $parent=basename(getcwd());
	my @rawMakers=LoadAllMakers();
	my @makers=ApplyDependencies(\@rawMakers,@rawMakers);
	my @rules=GetFileHandlingRules(\@makers);
	my @allPaths=ReadDirectoryTree();

	for (my $i=0; $i<@allPaths; $i++) {
		my $path=$allPaths[$i];
		my $flags=GetFileHandling(\@rules,$path);
		if (
			($flags&$filterSet)==$filterSet &&
			($flags&$filterUnset)==0 &&
			($listdirs || !-d($path))
		) {
			if ($includeparent) {
				$path=catfile($parent,$path);
			}
			print("$path\n");
		}
	}
}


#==================================== Main =====================================

# Current directory must be the directory this script file is in.
chdir(dirname($0));

# Perform the desired command.
my $Command=shift(@ARGV);
if (
	!defined($Command) or
	$Command eq "help" or
	$Command eq "-help" or
	$Command eq "--help" or
	$Command eq "-h"
) {
	Help();
}
elsif ($Command eq "build") {
	Build(@ARGV);
}
elsif ($Command eq "show-extra-options") {
	ShowExtraOptions();
}
elsif ($Command eq "install") {
	Install(@ARGV);
}
elsif ($Command eq "pack") {
	Pack(@ARGV);
}
elsif ($Command eq "clean") {
	Clean(@ARGV);
}
elsif ($Command eq "list") {
	List(@ARGV);
}
else {
	die(
		"Illegal command: $Command\n".
		"Type 'perl $0 help' to get help.\n"
	);
}
