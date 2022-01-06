#!/usr/bin/env perl

use strict;
use Getopt::Long;
use Cwd 'abs_path';

my $usage = qq{
perl my_script.pl
  Getting help:
    [--help]

};

my $folder = undef;
my $help;

GetOptions(
    "folder=s" => \$folder,
    "help" => \$help );

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

my @files = glob( $folder . '/*.fastq.gz' );

my %groups;

foreach my $file (@files) {
	my $fpath = abs_path($file);
	my $group = (split /_R[0-9]/, $file)[0];
	if (defined $groups{$group}) {
		push( @{ $groups{$group} },$fpath);
	} else {
		$groups{$group} = [ $fpath ];
	}
}

printf "famID,indivID,RGID,RGSM,RGLB,Lane,Read1File,Read2File,PaternalID,MaternalID,Sex,Phenotype\n";
my $fam_counter = 0 ;

foreach my $group (keys %groups) {

	$fam_counter += 1;

	my @reads = @{ $groups{$group} };
	my $left = @reads[0];
	my $right = @reads[1];

	my $base_name = (split "/", $left)[-1];
	my $sample = (split /_S[0-9]*/, $base_name)[0] ;
	chomp($sample);
	my $header = `zcat $left | head -n1`;

	my $info = (split " ",$header)[0] ;
	my ($instrument,$run_id,$flowcell_id,$lane,$tile,$x,$y) = (split ":", $info);
	my $readgroup = $flowcell_id . "." . $lane . "." . $sample ;
	chomp($readgroup);	
	printf "FAM" . $fam_counter . "," . $sample . "," . $readgroup . "," . $sample . "," . $sample . "," . $lane . "," . $left . "," . $right . "," . "0,0,other,-9\n";

}

