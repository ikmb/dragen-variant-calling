#!/usr/bin/env perl

use strict;
use Getopt::Long;

my $usage = qq{
perl my_script.pl
  Getting help:
    [--help]

};
my $samples = undef;
my $ped = 0;
my $help;

GetOptions(
    "samples=s" => \$samples,
    "ped=i" => \$ped,
    "help" => \$help );

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

my @files = glob( '*R1*.fastq.gz' );
my %set;
foreach my $file (@files) {
	$set{$file} = 1;
}
printf "RGID,RGSM,RGLB,Lane,Read1File,Read2File\n";

open(SAMPLES,$samples) or die ("Could not open sample sheet\n");

my @ped;

foreach my $line (<SAMPLES>) {

	my @elements = split "," , $line ;
	my $file = @elements[-6];
	my $fpath = (split "/", $file)[-1];

	if (defined $set{ $fpath }) {

		my ($famid,$individ,$rgid,$rgsm,$rglb,$lane,$left,$right,$patid,$matid,$sex,$pheno) = @elements;

                $left = (split "/" , $left)[-1] ;
                $right = (split "/", $right)[-1] ;

		printf $rgid . "," . $rgsm . "," . $rglb . "," . $lane . "," . $left . "," . $right . "\n";
	}
}

close(SAMPLES);
