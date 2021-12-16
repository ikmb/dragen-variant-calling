#!/usr/bin/env perl

use strict;
use Getopt::Long;
use Cwd qw(getcwd);

my $usage = qq{
perl my_script.pl
  Getting help:
    [--help]

  Ouput:    
    [--outfile filename]
        The name of the output file. By default the output is the
        standard output
};

my $outfile = undef;
my $before = undef;
my $after = undef;
my $help;

GetOptions(
    "before=s" => \$before,
    "after=s" => \$after,
    "help" => \$help,
    "outfile=s" => \$outfile);

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

if ($outfile) {
    open(STDOUT, ">$outfile") or die("Cannot open $outfile");
}

my $header = qq(
id: 'dragen_usage'
section_name: 'Dragen Usage'
plot_type: 'html'
description: 'specifies the # bases processed by DRAGEN.'
data: |\n  <dl class="dl-horizontal">
);

printf $header . "\n";

open(my $BEFORE, '<', $before) or die "FATAL: Can't open file: $before for reading.\n";

chomp(my @lines = <$BEFORE>);
 
# LICENSE_MSG| License Genome          : used 882.5/100000 Gbases since 2021-Nov-16 (882511111618 bases, 0.9%)

my $line = @lines[1] ;

my $bases_before = (split " ", $line)[-3] ;
$bases_before =~ s/\(// ;

close($BEFORE);

open(my $AFTER, '<', $after) or die "FATAL: Can't open file: $after for reading\n";

chomp(my @lines  = <$AFTER>);

my $line = @lines[1] ;

my $bases_after = (split " ", $line)[-3] ;
$bases_after =~ s/\(// ;

close($AFTER);

my $used = $bases_after - $bases_before ;

my $entry = "<dt>Bases consumed</dt><dd><samp>$used</samp></dd>" ;
printf "    $entry\n";
