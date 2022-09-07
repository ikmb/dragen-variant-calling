#!/usr/bin/env perl

use strict;
use Getopt::Long;

my $usage = qq{
perl my_script.pl
  Getting help:
    [--help]

};
my $samples = undef;
my $help;

GetOptions(
    "samples=s" => \$samples,
    "help" => \$help );

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

my @files = glob( '*.gvcf.gz' );
my %set;
foreach my $file (@files) {
	chomp($file);
	my $name = (split "\.hard", $file)[0];
	$set{$name} = 1;
}

# famID,indivID,RGID,RGSM,RGLB,Lane,Read1File,Read2File,PaternalID,MaternalID,Sex,Phenotype

open(SAMPLES,$samples) or die ("Could not open sample sheet\n");


foreach my $line (<SAMPLES>) {
	chomp($line);
	my @elements = split(",", $line);
	my ($famid,$individ,$rgid,$rgsm,$rglb,$lane,$paternal,$maternal,$sex,$pheno,$left,$right) = @elements;
	if (defined $set{ $rgsm }) {
		printf $famid . "\t" . $rgsm . "\t" . $paternal . "\t" . $maternal . "\t" . $sex . "\t" . $pheno . "\n";
	}
}

close(SAMPLES);
