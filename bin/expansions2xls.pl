#!/usr/bin/env perl

use strict;
use Getopt::Long;
use Excel::Writer::XLSX;
use JSON::Parse 'json_file_to_perl';


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

if ($outfile) {
    open(STDOUT, ">$outfile") or die("Cannot open $outfile");
}

#die "Must specify an outfile (--outfile)" unless (defined $outfile);

## Initiate the XLS workbook
my $workbook = Excel::Writer::XLSX->new($outfile);

## Add a new sheet
my $worksheet = $workbook->add_worksheet();

my $row = 0;

my $json = json_file_to_perl($infile);

my $loci = $json->{'LocusResults'};

my @header = ( "Lokus", "Variante" , "Coverage", "Allele" , "Genotyp" , "CI", "RepeatUnit","Varianten_Typ", "Region" );
&write_xlsx($worksheet, $row, @header);
++$row;

foreach my $locus (keys %$loci) {
		
	printf $locus . "\n";
	
	my $alleles = $loci->{$locus}->{'AlleleCount'};
	my $variants = $loci->{$locus}->{'Variants'};
	my @var_names = keys %$variants ;
	my $coverage = $loci->{$locus}->{'Coverage'};

	foreach my $var (@var_names) {

		my $variants = $loci->{$locus}->{'Variants'}->{$var}->{'Genotype'} ;
		my $region = $loci->{$locus}->{'Variants'}->{$var}->{'ReferenceRegion'};
		my $var_type = $loci->{$locus}->{'Variants'}->{$var}->{'VariantType'};
		my $ci = $loci->{$locus}->{'Variants'}->{$var}->{'GenotypeConfidenceInterval'};
 		my $ru = $loci->{$locus}->{'Variants'}->{$var}->{'RepeatUnit'};

		#printf $alleles . "\t" . $variants . "\t" . $region . "\t" . $var_type . "\n";

		my @ele = ( $locus, $var , $coverage, $alleles , $variants , $ci, $ru, $var_type, $region );

		&write_xlsx($worksheet, $row, @ele);

		++$row;

	}
	
}

sub write_xlsx{
    my ($worksheet, $tem_row, @ele) = @_;
    for(my $i = 0; $i < @ele; ++$i){
        $worksheet->write( $tem_row, $i, $ele[$i]);
    }
}
