#!/usr/bin/env perl

use strict;
use Getopt::Long;
use Excel::Writer::XLSX;

my $usage = qq{
perl my_script.pl
  Getting help:
    [--help]

  Input:
    [--infile filename]
		The name of the file to read. 
    [--ref filename]
		A file containing a list of known bad target exons to filter against
    [--skip filename]
		Am interval list of panel exons not included in the exome target

  Ouput:    
    [--outfile filename]
        The name of the output file. By default the output is the
        standard output
};

my $outfile = undef;
my $infile = undef;
my $min_cov = 30;
my $ref = undef;
my $skip = undef;

my $help;

GetOptions(
    "help" => \$help,
    "infile=s" => \$infile,
    "skip=s" => \$skip,
    "min_cov=i" => \$min_cov,
    "ref=s" => \$ref,
    "outfile=s" => \$outfile);

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

if ($outfile) {
    open(STDOUT, ">$outfile") or die("Cannot open $outfile");
}

my %ref_panel;
my %skip_exon;

# Ignore all exons that are known to be uncovered based on a kill list
if (defined $ref) {
	open my $ref_list , '<', $ref;
	chomp(my @lines = <$ref_list>);
	foreach my $line (@lines) {
		my ($target,$mean_cov) = split("\t", $line);
		$ref_panel{$target} = sprintf("%.2f",$mean_cov);
	}

	close $ref_list;
}

# Ignore all exons that are known to be absent from the exome target
if (defined $skip) {

	open my $skip_list, '<', $skip;
	chomp( my @lines = <$skip_list> );
	foreach my $line (@lines) {
		next if ($line =~ /^@.*/ ) ;
		my @elements = split(" ", $line);
		my $exon = @elements[-1];
		$skip_exon{$exon} = 1;
	}
	close $skip_list;
}

die "Must specify an outfile (--outfile)" unless (defined $outfile);

# Initiate the XLS workbook
my $workbook = Excel::Writer::XLSX->new($outfile);

# Add a new sheet
my $worksheet = $workbook->add_worksheet();

my $row = 0;

my $fh = IO::File->new();
$fh->open( $infile );

foreach my $line (<$fh>) {

	chomp($line);
	my ($chrom,$start,$end,$length,$name,$gc,$mean_coverage,$normalized_coverage,$min_normalized_coverage,$max_normalized_coverage,$min_coverage,$max_coverage,$pct_0x,$read_count) = split("\t", $line);
	my $status = "";
	unless ($mean_coverage =~ /^m.*/) {
		$mean_coverage = sprintf("%.2f",$mean_coverage);
	}
	if ($mean_coverage < $min_cov) {
		if ( exists($ref_panel{$name}) ) {
			$status = $ref_panel{$name} ;
		} else {
			if ( exists($skip_exon{$name}) ){
				$status = "NOT_IN_TARGET" ;
			} else {
				$status = "IN_TARGET" ;
			}
		}
		# work-around for the header of the table
		if ($name eq "name") {
			$status = "reference_coverage";
		}
		my @ele = ( $name, $mean_coverage, $status );
		&write_xlsx($worksheet, $row, @ele);

		++$row;
	}
	
}

close($fh);

sub write_xlsx{
    my ($worksheet, $tem_row, @ele) = @_;
    for(my $i = 0; $i < @ele; ++$i){
        $worksheet->write( $tem_row, $i, $ele[$i]);
    }
}
