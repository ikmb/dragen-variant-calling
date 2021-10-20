#!/usr/bin/env perl

use strict;
use Getopt::Long;

my $usage = qq{
perl my_script.pl
  Getting help:
    [--help]

};

my $help;

GetOptions(
    "help" => \$help );

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

my @files = glob( '*.fastq.gz' );

my %groups;

foreach my $file (@files) {

	my $group = (split /_R[0-9]/, $file)[0];
	if (defined $groups{$group}) {
		push( @{ $groups{$group} },$file);
	} else {
		$groups{$group} = [ $file ];
	}
}

printf "RGID,RGSM,RGLB,Lane,Read1File,Read2File\n";

foreach my $group (keys %groups) {

	my @reads = @{ $groups{$group} };
	my $left = @reads[0];
	my $right = @reads[1];

	my $sample = (split /_S[0-9]*/, $left)[0] ;

	my $header = `zcat $left | head -n1`;

	my $info = (split " ",$header)[0] ;
	my ($instrument,$run_id,$flowcell_id,$lane,$tile,$x,$y) = (split ":", $info);
	my $readgroup = $flowcell_id . "." . $lane . "." . $sample ;
	
	printf $readgroup . "," . $sample . "," . $sample . "," . $lane . "," . $left . "," . $right . "\n";

}

