#!/usr/bin/perl
# vim:ts=4:sw=4:foldmethod=marker:smartindent:ruler

# Note to vim newbies: This file uses folds. To open all folds, type zR in
# command mode.

# datedist.pl v0.1.4 docs {{{
#
# datedist.pl is a file distribution script written by Roy Sigurd Karlsbakk
# <roy@karlsbakk.net>. I wrote it to distribute a few thousand files in a
# directory so that they were all placed under a directory hiearchy like
# YYYYY/MM/DD to allow for me to find them later. I typically use this after a
# manual import of the pics, before importing those into Lightroom. 
#
# 2013-01-30: Added --exif for using exiftool to extract shoot date instead of
# file dates, which may be different than shoot date.
#
# 2013-01-31:
#  - Changed license to AGPL 3.0.
#  - Added more documentation.
#  - Added check to see if destination file exists to avoid overwriting existing
#    stuff.
#  - Added new option --force to forcibly overwrite existing files.
#  - Added new option --dest-dir to allow other destination dir than current dir
#  - Updated to version 0.1.2
#
# 2013-05-21:
#  - Better help thanks to <malinkh@gmail.com>
#  - Updated to version 0.1.3
#
# 2014-02-17:
#  - Code cleanup
#  - Added --version
#  - Updated to version 0.1.4
#
# License: AGPL v3.0. See http://www.gnu.org/licenses/agpl-3.0.html for details.
#
# Roy Sigurd Karlsbakk <roy@karlsbakk.net>
#
# }}}

# Uses {{{

use strict;
use warnings;
use File::Copy;
use File::Path qw(make_path);
use Getopt::Long;
use Image::ExifTool qw(:Public);
use Time::Format qw(%strftime);
use Data::Dumper;

# }}}
# Globals and settings {{{

# Flags
my $no_day_dir = 0;
my $no_month_dir = 0;
my $hour_dir = 0;
my $minute_dir = 0;
my $norun = 0;
my $help = 0;
my $verbose = 0;
my $exif = 0;
my $move_corresponding_xmp = 0;
my $force = 0;
my $print_version = 0;

# Strings
my $dest_dir = undef;
my $version = '0.1.4';

# }}}

# sub help {{{

sub help
{
	print <<EOT;
Syntax: $0 [ opts ] filename [ filename [ ... ] ]
   --dest-dir               Distribute files under given dir, not current
                            directory.
   --hour                   Create hourly dirs
   --minute                 Create minutely dirs (implies --hour)
   --nomonth                Do not create monthly dirs (implies --noday)
   --noday                  Do not create daily dirs
   --exif                   Distribute files by shoot time in exif data instead
                            of file date. Will post a warning and ignore files
							without exif data.
   --move-coresponding-xmp 	Moves coresponding xmp too
   --force                  Forcely overwrite existing files

   --help                   Display this help
   --version                Show version number and exit

--nomonth/--noday are incompatible with --hour/--minute
EOT
	exit (1);
}
# }}}
# sub syntax {{{

sub syntax
{
	print "wtf?\n"
}
# }}}
# sub version {{{

sub version
{
	print "datedist.pl version $version\n";
	exit 0;
}

# }}}

# Parse options {{{

Getopt::Long::Configure('bundling');
GetOptions(
	"dest-dir=s" => \$dest_dir,
	"noday" => \$no_day_dir,
	"nomonth" => \$no_month_dir,
	"hour" => \$hour_dir,
	"minute" => \$minute_dir,
	"norun" => \$norun,
	"exif" => \$exif,
	"move-corresponding-xmp" => \$move_corresponding_xmp,
	"force" => \$force,
	"verbose+" => \$verbose,
	"version" => \$print_version,
	"help" => \$help,
) or syntax("Illegal option!");

$no_day_dir = 1 if ($no_month_dir);
$hour_dir = 1 if ($minute_dir);
&help("Incompatible options!") if ($no_day_dir and $hour_dir);
&help if ($help);
&version if ($version);

# }}}
# Main loop {{{

while (my $filename = shift)
{
	my ($mtime,$year,$month,$day,$hour,$minute,$second);
	unless (-f $filename && -r $filename)
	{
		warn "$filename is not a file or is not readable. Skipping\n";
		next;
	}
	if ($exif) {
		my $exifinfo = ImageInfo($filename);
		print "Photo taken $exifinfo->{'DateTimeOriginal'}\n" if ($verbose);
		#if (/2007:02:23 22:53:45
		if ($exifinfo->{'DateTimeOriginal'} =~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
			($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6);
		} else {
			print STDERR "Can't read exif data from file $filename\n";
			next;
		}
	} else {
		$mtime = (stat($filename))[9];
		$year = $strftime{'%Y', $mtime};
		$month = $strftime{'%m', $mtime};
		$day = $strftime{'%d', $mtime};
		$hour = $strftime{'%H', $mtime};
		$minute = $strftime{'%M', $mtime};
		$second = $strftime{'%S', $mtime};
	}

# Create directory tree
	my $dir;
	if (defined($dest_dir)) {
		$dir = $dest_dir;
		$dir .= '/' unless ($dir =~ /\/$/);
	}
	$dir .= "$year";
	$dir .= "/$month" unless ($no_month_dir);
	$dir .= "/$day" unless ($no_day_dir);
	$dir .= "/$hour" if ($hour_dir);
	$dir .= "/$minute" if ($minute_dir);
	make_path($dir, {
		verbose => $verbose,
		mode => 0755,
	});

# If $filename has directory names in it, remove them in $destfilename
#	my $destfilename = $filename;
#	$destfilename = $1 if ($destfilename =~ /.*\/(.*)/);

# Move file
	if (-f "$dir/$filename" && ! $force) {
		print "Skipping file $filename (exists in $dir already)\n";
		next;
	}
	if (move($filename,"$dir/$filename"))
	{
		if ($move_corresponding_xmp)
		{
			my $xmp_filename = $filename;
			$xmp_filename =~ s/(.*?)\.\w+$/$1.xmp/;
			move($xmp_filename,"$dir/$xmp_filename") if (-f $xmp_filename);
		}
	} else {
		warn "Unable to move $filename to $dir\n" unless (move($filename,"$dir/$filename"));
	}
}

# }}}
