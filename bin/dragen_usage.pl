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
my $unit = 0.3;
my $help;

GetOptions(
    "before=s" => \$before,
    "after=s" => \$after,
    "unit=f" => \$unit,
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

my @files = glob( '*dragen_log.*.log' );

my @counts ;

foreach my $file (@files) {

	open(my $IN, '<', $file) or die "FATAL: Can't open file: $file for reading.\n";
	chomp(my @lines = <$IN>);
 
	# LICENSE_MSG| License Genome          : used 882.5/100000 Gbases since 2021-Nov-16 (882511111618 bases, 0.9%)
	# LICENSE_MSG| License Genome          : used 303.1/100001 Gbases since 2022-May-16

	my $line = @lines[1] ;
	my $consumed = (split " ", $line)[-4] ;
	my $bases = (split "/", $consumed)[0];
	$bases =~ s/\(// ;
	
	push(@counts,$bases);

	close($IN);

}

my @sorted = sort { $a <=> $b } @counts;

my $used = @sorted[-1] - @sorted[0] ;

my $entry = "<dt>Gigabases consumed</dt><dd><samp>$used</samp></dd>" ;
printf "    $entry\n";
my $cost = ($used * $unit) ;
$entry = "<dt>Cost in Euro ($unit / GB)</dt><dd><samp>$cost</samp></dd>" ;
printf "    $entry\n";
