#!/usr/bin/perl
# vim:ts=4:sw=4:foldmethod=marker:smartindent:ruler:et

# Note to vim newbies: This file uses folds. To open all folds, type zR in
# command mode.

# datedist.pl v0.2.0 docs {{{
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
# 2016-06-13:
#  - Changed to make --exif default
#
# 2016-06-14:
#  - Changed old --move-corresponding-(something) to --mcf=ext,ext2 etc.
#    Compatibility with old syntax is retained.
#  - Version changed to 0.9.9
#  - More testing to be done
#
# 2018-01-18:
#  - Removed dependencies on Time::Format and Image::ExifTool. The former is
#    removed and the code juse uses localtime(). The latter is used if present.
#    Also removed Dat::Dumper, since it wasn't in active use.
#
# 2023-10-07:
#  - Added hashing support in case of conflicts. So far most for show and all
#    it does is to check MD5 hash and then tell you if the files match or not. I'm just
#    tired, that's all...
#
# License: AGPL v3.0. See http://www.gnu.org/licenses/agpl-3.0.html for details.
#
# Roy Sigurd Karlsbakk <roy@karlsbakk.net>
#
# }}}

# Uncondional uses {{{

use strict;
use warnings;
use File::Copy;
use File::Path qw(make_path);
use Getopt::Long;
use Data::Dumper;

# }}}
# Globals and settings {{{

# Flags
my $no_day_dir = 0;
my $no_month_dir = 0;
my $hour_dir = 0;
my $minute_dir = 0;
my $second_dir = 0;
my $norun = 0;
my $help = 0;
my $verbose = 0;
my $exif = 0;
my $noexif = 0;
my $mcf = undef;
my $move_corresponding_xmp = 0;
my $move_corresponding_jpg = 0;
my $move_corresponding_png = 0;
my $move_corresponding_tif = 0;
my $move_corresponding_files = 0;

# stuff
my %mcf_exts;

# Hashing
my %hash;
my $hash_algo;

# Mostly for debugging
my $force_digest_crc = 0;
my $force_digest_md5 = 1;
my $force_crypt_digest_sha256 = 0;
my $force_crypt_digest_sha512_256 = 0;

my $force = 0;
my $print_version = 0;

# Strings
my $dest_dir = undef;
my $version = '0.1.4';

# }}}
# Condional uses {{{

my $have_image_exiftool = eval { require Image::ExifTool; 1; };
my $have_digest_crc = eval { require Digest::CRC; 1; };
my $have_digest_md5 = eval { require Digest::MD5; 1; };
my $have_crypt_digest_sha256 = eval { require Crypt::Digest::SHA256; 1; };
my $have_crypt_digest_sha512_256 = eval { require Crypt::Digest::SHA512_256; 1; };

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
   --second                 Create secondly dirs (implies --minute)
   --nomonth                Do not create monthly dirs (implies --noday)
   --noday                  Do not create daily dirs
   --exif                   Distribute files by shoot time in exif data instead
                            of file date. Will post a warning and ignore files
                            without exif data (needs Image::ExifTool).
   --noexif                 Negates exif (default).
   --move-corresponding-xmp Moves corresponding xmp too
   --move-corresponding-jpg Moves corresponding jpg too
   --move-corresponding-tif Moves corresponding tif too
   --force                  Forcely overwrite existing files

   --help                   Display this help
   --version                Show version number and exit

--nomonth/--noday are incompatible with --hour/--minute/--second
EOT
    exit (1);
}
# danke :) :)
# }}}
# sub syntax {{{

sub syntax
{
    my $s = shift;
    $s = 'wtf' unless (defined($s));
    chomp($s);
    print "$s\n";
    &help;
}
# }}}
# sub version {{{

sub version
{
    print "datedist.pl version $version\n";
    exit 0;
}

# }}}
# sub hashit(filename) {{{

sub hashit
{
    my $filename = shift;
    my $hash = '';
    my $digest;

    if ($hash_algo eq 'CRC32') {
    } elsif ($hash_algo eq 'MD5') {
        open (my $fh, '<', $filename) or die "Can't open '$filename': $!";
        binmode($fh);
        $digest = Digest::MD5->new;
        while (<$fh>) {
            $digest->add($_);
        }
        close($fh);
        $hash = $digest->b64digest;
    } elsif ($hash_algo eq 'SHA256') {
    } elsif ($hash_algo eq 'SHA512_256') {
    }
    return $hash;
}

# }}}

# Parse options {{{
Getopt::Long::Configure('bundling');
GetOptions(
    "dest-dir=s" => \$dest_dir,
    "noday" => \$no_day_dir,
    "nomonth" => \$no_month_dir,
    "hour" => \$hour_dir,
    "hours" => \$hour_dir,
    "minute" => \$minute_dir,
    "minutes" => \$minute_dir,
    "second" => \$second_dir,
    "seconds" => \$second_dir,
    "norun" => \$norun,
    "exif" => \$exif,
    "noexif" => \$noexif,
    "no-exif" => \$noexif,
    "mcf=s" => \$mcf,
    "move-corresponding-xmp" => \$move_corresponding_xmp,
    "move-corresponding-jpg" => \$move_corresponding_jpg,
    "move-corresponding-png" => \$move_corresponding_png,
    "move-corresponding-tif" => \$move_corresponding_tif,
    "move-corresponding-files" => \$move_corresponding_files,
    "force" => \$force,
    "verbose+" => \$verbose,
    "version" => \$print_version,
    "help" => \$help,
) or syntax("Illegal option!");

$no_day_dir = 1 if ($no_month_dir);
$minute_dir = 1 if ($second_dir);
$hour_dir = 1 if ($minute_dir);
&help("Incompatible options!") if ($no_day_dir and $hour_dir);
&help if ($help);
&version if ($print_version);
$exif=0 if ($noexif);

if ($exif and not $have_image_exiftool) {
    warn "Missing Image::ExifTool - disabling exif support";
    $exif = 0;
}

# crypto is fun
if ($have_crypt_digest_sha512_256) {
    $hash_algo = 'SHA512_256';
} elsif ($have_crypt_digest_sha256) {
    $hash_algo = 'SHA256';
} elsif ($have_digest_md5) {
    $hash_algo = 'MD5';
} elsif ($have_digest_crc) {
    $hash_algo = 'CRC32';
} else {
    $hash_algo = 'None';
    print STDERR "No supported hash algorithm - no smoking for me tonight...\n";
}
my $forcedhashes = $force_digest_crc + $force_digest_md5 + $force_crypt_digest_sha256 + $force_crypt_digest_sha512_256;
if ($forcedhashes > 1) {
    print STDERR "You can't force several digests - idiot!\n";
    exit 2;
}
my $forcedhashused = 'No';
if ($forcedhashes == 1) {
    $forcedhashused = 'Yes';
    if ($force_digest_crc) {
        $hash_algo = 'CRC32';
    } elsif ($force_digest_md5) {
        $hash_algo = 'MD5';
    } elsif ($force_crypt_digest_sha256) {
        $hash_algo = 'SHA256';
    } elsif ($force_crypt_digest_sha512_256) {
        $hash_algo = 'SHA512_256';
    } else {
        print STDERR "Where AM I!!!??!??!?\n";
        exit 3;
    }
}
print "In case of conflicts, check with hash algorithm $hash_algo,\n" if ($verbose);
print "(forced: $forcedhashused) if the files have the same content.\n" if ($verbose);

# Move corresponding files - new way {{{
# mcf is "move corresponding files" the new way
if (defined($mcf)) {
    chomp($mcf);
    foreach my $ext (split $mcf,',') {
        $mcf_exts{$ext}++;
    }
}
# }}}
# Backward compatibility {{{
$move_corresponding_xmp = $move_corresponding_jpg = $move_corresponding_png = $move_corresponding_tif = 1 if ($move_corresponding_files);

if ($move_corresponding_xmp) {
    $mcf_exts{'xmp'}++;
}
if ($move_corresponding_jpg) {
    $mcf_exts{'jpg'}++;
    $mcf_exts{'jpeg'}++;
}
if ($move_corresponding_png) {
    $mcf_exts{'png'}++ ;
}
if ($move_corresponding_tif) {
    $mcf_exts{'tiff'}++ ;
}
# }}}
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
        unless (defined($exifinfo)) {
            print STDERR "Ignoring $filename - undefined exifinfo\n";
            next;
        }
        my $exifdatetime = $exifinfo->{'DateTimeOriginal'};
        # sånn - hvis den ikke kjenner igjen exifdataene, så driter den i fila. ok ok
        print "Photo taken $exifdatetime\n" if ($verbose);
        #if (/2007:02:23 22:53:45
        if (defined($exifdatetime) and $exifdatetime =~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
            ($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6);
        } else {
            print STDERR "Can't read exif data from file $filename\n";
            next;
        }
    } else {
        $mtime = (stat($filename))[9];
        ($second,$minute,$hour,$day,$month,$year) = localtime($mtime);
        $year += 1900;
        $month = sprintf("%02d", $month+1);
		$day = sprintf("%02d", $day);
		$hour = sprintf("%02d", $hour);
		$minute = sprintf("%02d", $minute);
		$second = sprintf("%02d", $second);
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
    $dir .= "/$second" if ($second_dir);
    make_path($dir, {
        verbose => $verbose,
        mode => 0755,
    });

# If $filename has directory names in it, remove them in $destfilename
#   my $destfilename = $filename;
#   $destfilename = $1 if ($destfilename =~ /.*\/(.*)/);

# Move file
    if (-f "$dir/$filename" && ! $force) {
        $hash{"$dir/$filename"} = hashit("$dir/$filename");
        $hash{"$filename"} = hashit("$filename");
        my $not = '';
        $not = "not " if ($hash{"$dir/$filename"} ne $hash{"$filename"});
        print "Skipping file $filename (exists in $dir already and the two are ${not}equal)\n";
        next;
    }
    if (move($filename,"$dir/$filename"))
    {
        # det er denne blokka du vil kopiere og endre. ok bruk stor V - så merker den hele linjer.
        # k
        if ($move_corresponding_jpg)
        {
            my $jpg_filename = $filename;
            $jpg_filename =~ s/(.*?)\.\w+$/$1.jpg/i;
            unless (-f $jpg_filename) {
                print "Can't find jpg file '$jpg_filename'\n" if ($verbose);
                $jpg_filename = "$filename.jpg";
                print "Trying '$jpg_filename' for $filename\n" if ($verbose);
            }
            if (-f $jpg_filename) {
                if (move($jpg_filename,"$dir/$jpg_filename")) {
                    my $jpg_xfs_filename = "$jpg_filename.xmp";
                    if ( -f $jpg_xfs_filename ) {
                        move($jpg_xfs_filename,"$dir/$jpg_xfs_filename");
                    }
                }
            } else {
                print "Can't find jpg file '$jpg_filename', ignoring it (about $filename)\n" if ($verbose);
            }

        }
        if ($move_corresponding_png)
        {
            my $png_filename = $filename;
            $png_filename =~ s/(.*?)\.\w+$/$1.png/i;
            unless (-f $png_filename) {
                print "Can't find png file '$png_filename'\n" if ($verbose);
                $png_filename = "$filename.png";
                print "Trying '$png_filename' for $filename\n" if ($verbose);
            }
            if (-f $png_filename) {
                if (move($png_filename,"$dir/$png_filename")) {
                    my $png_xfs_filename = "$png_filename.xmp";
                    if ( -f $png_xfs_filename ) {
                        move($png_xfs_filename,"$dir/$png_xfs_filename");
                    }
                }
            } else {
                print "Can't find png file '$png_filename', ignoring it (about $filename)\n" if ($verbose);
            }
        }

        if ($move_corresponding_tif)
        {
            my $tif_filename = $filename;
            $tif_filename =~ s/(.*?)\.\w+$/$1.tif/i;
            unless (-f $tif_filename) {
                print "Can't find tif file '$tif_filename'\n" if ($verbose);
                $tif_filename = "$filename.tif";
                print "Trying '$tif_filename' for $filename\n" if ($verbose);
            }
            if (-f $tif_filename) {
                if (move($tif_filename,"$dir/$tif_filename")) {
                    my $tif_xfs_filename = "$tif_filename.xmp";
                    if ( -f $tif_xfs_filename ) {
                        move($tif_xfs_filename,"$dir/$tif_xfs_filename");
                    }
                }
            } else {
                print "Can't find tif file '$tif_filename', ignoring it (about $filename)\n" if ($verbose);
            }
        }

        if ($move_corresponding_xmp)
        {
            my $xmp_filename = $filename;
            $xmp_filename =~ s/(.*?)\.\w+$/$1.xmp/i;
            unless (-f $xmp_filename) {
                print "Can't find xmp file '$xmp_filename'\n" if ($verbose);
                $xmp_filename = "$filename.xmp";
                print "Trying '$xmp_filename' for $filename\n" if ($verbose);
            }
            if (-f $xmp_filename) {
                move($xmp_filename,"$dir/$xmp_filename") if (-f $xmp_filename);
            } else {
                print "Can't find xmp file '$xmp_filename', ignoring it (about $filename)\n" if ($verbose);
            }
        }
    } else {
        warn "Unable to move $filename to $dir\n" unless (move($filename,"$dir/$filename"));
    }
}

# }}}
#
# finito
#
# finitato
