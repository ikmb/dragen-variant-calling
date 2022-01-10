#!/usr/bin/env perl

use strict;
use Getopt::Long;

my $usage = qq{
perl my_script.pl
  Getting help:
    [--help]

  Input:
    [--infile filename]
		The name of the file to read. 
  Ouput:    
    [--outfile filename]
        The name of the output file. By default the output is the
        standard output
};

my $outfile = undef;
my $infile = undef;
my $help;

GetOptions(
    "help" => \$help,
    "infile=s" => \$infile,
    "outfile=s" => \$outfile);

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

open (my $IN, '<', $infile) or die "FATAL: Can't open file: $infile for reading.\n$!\n";

chomp(my @lines = <$IN>);

my $ecode = 0;

my $header = shift @lines;

my $ref_header = "famID,indivID,RGID,RGSM,RGLB,Lane,Read1File,Read2File,PaternalID,MaternalID,Sex,Phenotype" ;

my @elements = split("," , $ref_header);

$header eq $ref_header or die "Header mis-formed!\n";

my $lc = 0;

my %valid_sex = ( 1 => "true", 2 => "true" , "other" => "true" );
my %valid_pheno = ( "1" => 0, "2" => 0 , "0" => 0, "-9" => 0 );

my %fam_hash;

foreach my $line (@lines) {

	$lc += 1;

	my @el = split(",", $line);

	scalar(@el) == scalar(@elements) or die "Incorrect number of elements detected in line $lc\n";

	# famID,indivID,RGID,RGSM,RGLB,Lane,Read1File,Read2File,PaternalID,MaternalID,Sex,Phenotype

	my ($fam_id,$indiv_id,$rgid,$rgsm,$rglb,$lane,$r1,$r2,$patid,$matid,$sex,$pheno) = @el ;

	$fam_hash{$rgsm} = $fam_id ;

	if (!defined $valid_sex{$sex}) {
		die "Found invalid sex: $sex \n";
	}
	if (!defined $valid_pheno{$pheno}) {
		die "Found invalid phenotyoe: $pheno \n";
	}
	
}

foreach my $line (@lines) {

	my ($fam_id,$indiv_id,$rgid,$rgsm,$rglb,$lane,$r1,$r2,$patid,$matid,$sex,$pheno) = split(",", $line) ;

	if ($patid ne 0) {
		if (!defined $fam_hash{$patid}) {
			die "Found invalid paternal ID: $patid - not defined as a sample name anywhere\n"
		} else {
			if ($fam_hash{$patid} ne $fam_id) {
				die "Family ID is different between parent and child!\n";
			}
		}
	}
	if ($matid ne 0) {
                if (!defined $fam_hash{$matid}) {
                        die "Found invalid maternal ID: $matid - not defined as a sample name anywhere\n"
                } else {
                        if ($fam_hash{$matid} ne $fam_id) {
                                die "Family ID is different between parent and child!\n";
                        }
                }

        }

}

close($IN);

exit 0;
