#!/usr/bin/perl
# vim:ts=4:sw=4:sts=4:et:ai:fdm=marker

# Dir {{{
# Dirs {{{
# 01/
# 02/
# 03/
# 04/
# 05/
# 06/
# 07/
# 08/
# }}}
# 20210403_194642.jpg
# 20210409_011648.jpg
# 20210410_193210.jpg
# 20210410_233448.jpg
# 20210410_233628.jpg
# 20210417_233812.jpg
# 20210417_233817.jpg
# 20210419_121314.jpg
#
# }}}

use strict;
use warnings;

my $dirname = '.';
my ($y,$m,$d,$serial);

opendir ( CWD, $dirname ) || die "Error in opening dir $dirname\n";
while (( my $fn = readdir(CWD))) {
    next if (-d $fn);
    unless (-f $fn) {
        print STDERR "'$fn' isn't a file\n";
        next;
    }
    unless (-w $fn) {
        print STDERR "Can't change '$fn'\n";
        next;
    }
    if ($fn =~ /^(\d{4})(\d{2})(\d{2})_(\d+)/) {
        ($y,$m,$d,$serial) = ($1,$2,$3,$4);
    } else {
        print STDERR "Can't recognize filename '$fn'\n";
        next;
    }
    print("$filename\n");
}
closedir(CWD);
