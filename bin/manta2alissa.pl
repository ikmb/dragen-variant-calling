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

if ($outfile) {
    open(STDOUT, ">$outfile") or die("Cannot open $outfile");
}

open (my $IN, "gunzip -c  $infile | ") or die "FATAL: Can't open file: $infile for reading.\n$!\n";

while (<$IN>) {

        my $line = $_;
        chomp $line;

	# The def line for the EnsEMBL accumulated score annotations
	if ($line =~ /^#.*/) {
		printf $line . "\n";
	} else {

		my @values = split(/\t/,$line);
                my ($chrom,$pos,$rsid,$ref,$alt,$qual,$filter,$info,$format) = @values[0..8];
		my @info = split( ";",$info);

		my $patients = "";
		if (scalar @values == 10) {
			$patients = @values[9];
		} else {
			$patients = join(@values[9..-1], "\t");
		}

		my $update = "";

		foreach my $i (@info) {

			next if ($i =~ /.*SVTYPE.*/) ;
			$update .= $i . ";" ;

		}	

		printf $chrom . "\t" . $pos . "\t" . $rsid . "\t" . $ref . "\t" . $alt . "\t" . $qual . "\t" . $filter . "\t" . $update . "\t" . $format . "\t"  . $patients . "\n";
	}
	
}

close($IN);


