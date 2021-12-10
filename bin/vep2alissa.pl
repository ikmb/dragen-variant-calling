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

open (my $IN, '<', $infile) or die "FATAL: Can't open file: $infile for reading.\n$!\n";

my %structure;

# VEP specific keys we wish to deconstruct and put into their stand-alone info field
my %recover = ( "ada_score" => { "Type" => "Float", "Number" => "1"}, 
		"rf_score" => { "Type" => "Float", "Number" => "1"}, 
		"ExACpLI" => { "Type" => "Float", "Number" => "1"}, 
		"GERP++_RS" => { "Type" => "Float", "Number" => "1"}, 
		"LRT_score" => { "Type" => "Float", "Number" => "1"},
		"CLIN_SIG" => { "Type" => "String", "Number" => "1"}, 
		"PHENO" => { "Type" => "String", "Number" => 1},
		"CADD_phred" => { "Type" => "Float", "Number" => 1},
		"DANN_score" => { "Type" => "Float", "Number" => 1},
		"M-CAP_pred" => { "Type" => "String", "Number" => 1},
		"Existing_variation" => {"Type" => "String", "Number" => "1"},
		"five_prime_UTR_variant_annotation" => {"Type" => "String", "Number" => "1"},
		"five_prime_UTR_variant_consequence" => {"Type" => "String", "Number" => "1"},
		"existing_InFrame_oORFs" => {"Type" => "String", "Number" => "1"},
		"existing_OutOfFrame_oORFs" => {"Type" => "String", "Number" => "1"},
		"existing_uORFs" => {"Type" => "String", "Number" => "1"},
		"Mastermind_MMID3" => { "Type" => "String", "Number" => "1"},
		"REVEL" => { "Type" => "Float", "Number" => "1" },
		"SpliceAI_pred" => { "Type" => "String", "Number" => "1"}
	);

while (<$IN>) {

        my $line = $_;
        chomp $line;

	# The def line for the EnsEMBL accumulated score annotations
	if ($line =~ /^##INFO\=\<ID\=CSQ.*/) {

		my @elements = split (/ / , $line);

		#printf $elements[-1] . "\n";

		my @info = split /\|/ , @elements[-1];

		my $counter = 0	 ;
	
		foreach my $e (@info) {
			$e =~ s/[<\",\">]//g ;
			$structure{$e} = $counter;
			$counter += 1;
		}
		foreach my $r (keys %recover) {

			if (defined $structure{$r}) {
				my $t = $recover{$r}{"Type"};
				my $n = $recover{$r}{"Number"};
				printf "##INFO=<ID=$r,Number=$n,Type=$t,Description=\"$r\">\n" ;
			}
		
		}
	
	# any other def line
	} elsif ($line =~ /^#.*/) {
		printf $line  . "\n";
				
	# presumably a variant annotation
	} else {
		my @values = split(/\t/,$line);
                my ($chrom,$pos,$rsid,$ref,$alt,$qual,$filter,$info,$format) = @values[0..8];
		my $array_len = scalar(@values);
		my $last_pos = $array_len-1;	
		my $patients = join("\t", @{values[9..$last_pos]} );

		my %ip ;
	
		# Split the info field
		my @infos = split( ";",$info);

		foreach my $i (@infos) {

			# deconstruct into pair-values
			my ($k,$v) = split("=",$i);

			# if not a VEP string, just use as-is
			if ($k ne "CSQ") {
				$ip{$k} = ( $v );
			} else {

				# VEP can and will list multiple sets if more than one transcript maps over this variant				
				my @data_blocks = split("," , $v);

				# We run VEP in a way that the first entry should be sufficient for our purpose
				my @data = split(/\|/,@data_blocks[0]);
				foreach my $r (keys %structure) {
					my $pos = $structure{$r};
					my $val = @data[$pos];
					if (defined $val && length($val)>0) {

						if (defined $ip{$r}) {
							push @{ $ip{$r} }, $val;
						} else {
							$ip{$r} = ( $val );
						}
					}
				}

			}

		}

		# construct the new info field
		my $update = "";
		foreach my $k (keys %ip) {

			my @val = $ip{$k};
			my $values = join(",",@val);
			$update .= $k . "=" . $values . ";" ;			
		}

		printf $chrom . "\t" . $pos . "\t" . $rsid . "\t" . $ref . "\t" . $alt . "\t" . $qual . "\t" . $filter . "\t" . $update . "\t" . $format . "\t"  . $patients . "\n";		

	}

	
}

close($IN);


