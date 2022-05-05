#!/bin/env perl

use Bio::FeatureIO;
use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $usage = qq{
perl ensembl_get_utr.pl
  Getting help:
    [--help]

  Input data
	[--list filename]
	The list of gene names to get BED coordinates for

	[--assembly name]
	Name of the genome assembly to use (GRCH37, hg19, GRCh38)	

  Ouput:
    [--output_file filename]
        The name of the output file. By default the output is the
        standard output
};

my $species = "homo_sapiens";
my $output_file = undef;
my $list = undef;
my $assembly = "GRCh38";
my $help;

GetOptions(
    "help" => \$help,
    "assembly=s" => \$assembly,
    "list=s" => \$list,
    "output_file=s" => \$output_file);
    

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

my $options = 3306;
my $prefix = "chr";

if ($assembly eq "GRCh37" or $assembly eq "hg19") {
	$options = 3337;
} elsif ($assembly eq "GRCh38") {
	# do nothing
} else {
	exit 1, "Unknown assembly version provided should be one of: hg19, GRCh37 or GRCh38 (default).\n";
}
if ($assembly eq "GRCh37") {
	$prefix = "";
}

my $registry = 'Bio::EnsEMBL::Registry';

$registry->load_registry_from_db(
    -host => 'ensembldb.ensembl.org',
    -user => 'anonymous',
    -port => $options);

my $gene_adaptor = $registry->get_adaptor( $species, 'Core', 'Gene' );

my $fh = IO::File->new();
$fh->open( $list);

foreach $line (<$fh>) {

	chomp($line);

	# Some genes may have different canonical names in different assemblies	
	my @genes = (split ",", $line);
	my $skip = 0;

	foreach my $gene_name (@genes) {

		printf STDERR "Searching for $gene_name ...\n";

		next if ($skip == 1);

		# Theoretically, one HGNC can map to multiple Genes
		my $gene = $gene_adaptor->fetch_by_display_label($gene_name);

		next if (!$gene);

		# We have a found a match, don't need to check the alternative names, if any
		$skip = 1;

		my $transcript = $gene->canonical_transcript;

		my @exons = @{ $transcript->get_all_translateable_Exons() } ;
		foreach my $exon (@exons) {
			next if (!$exon->is_coding($transcript) ) ;
			my $ref_start = $exon->coding_region_start($transcript);
			my $ref_end = $exon->coding_region_end($transcript);
			if ($ref_start > $ref_end) {
				($ref_start,$ref_end) = ($ref_end,$ref_start);
			}
			my $strand = $exon->strand == 1 ? "+" : "-" ;
			printf $prefix . $gene->seq_region_name . "\t" . $ref_start . "\t" . $ref_end . "\t" . $line . "." . $transcript->stable_id . "."  . $exon->rank($transcript) . "\t" . 100 . "\t" . $strand . "\n";
		}
	}

	die "Gene not found " . $line . "\n" if ($skip == 0);
		
}
close ($fh);


