#!/usr/bin/env perl

use strict;
use Getopt::Long;
use Cwd 'abs_path';
use HTTP::Tiny;
use Data::Dumper;
use JSON;

my $usage = qq{
perl my_script.pl
  Getting help:
    [--help]

};

my $folder = undef;
my $customer = undef;
my $help;

GetOptions(
    "folder=s" => \$folder,
    "help" => \$help );

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

my $http = HTTP::Tiny->new() ;
my $server = 'http://172.21.99.59/restapi/';

my @files = glob( $folder . '/*.fastq.gz' );

my %info ;

foreach my $file (@files) {

	my $r = (split "/", $file)[-1];

	# 220400005525-DS6_22Apr5525-DL006_S18_L002_R1_001.fastq.gz

	my ($barcode,$library,$s,$lane,$ori,$suffix) = (split "_", $r);

 	# Skip if we have already collected information for this library
        next if (defined $info{$library});

	my $ext = "/library/info/${library}" ;
        my $response = $http->get($server.$ext, {
	        headers => { 'Content-type' => 'application/json' }
        });

        my $ldata = decode_json($response->{content});
	my $data = $ldata->{'data'};
        my $lsample = $ldata->{'data'}{'sample'} ;
	my $sample_id = $lsample->{'sample_id'};
	my $project = $data->{'project'}{'project_name_id'};

	$info{$library} = { "library_name_id" => $library, 
		"library_id" => $data->{'library_id'}, 
		"project" => $project,
		"sample_id" => $sample_id, 
		"sample_name_id" => $lsample->{'sample_name_id'}, 
		"external_name" => $lsample->{'external_name'},
		"alissa_id" => undef
	};	

	$ext = "/diagnostic/sample_info/barcode/$barcode" ;

        my $response = $http->get($server.$ext, {
                headers => { 'Content-type' => 'application/json' }
        });

        my $clinical = decode_json($response->{content});

	if (defined $clinical->{'data'} && $clinical->{'data'}->{'ibdbase'}) {
	        my $cdata = $clinical->{'data'} ;
		my $alissa = $cdata->{'ibdbase'}{'alissa_id'} ;		
		$info{$library}{'alissa_id'} = $alissa ;
	}
}


###########################################################################
# Iterate over files again, group by library and lane, and add all metadata
###########################################################################

my %groups;
my %samples;

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

        # 220400005493-DS9_22Apr5493-DL009_S9_L002_R1_001.fastq.gz

        my @reads = @{ $groups{$group} };
        my $left = @reads[0];
        my $right = @reads[1];

	my $r = (split "/", $left)[-1];
	my ($barcode,$library,$s,$lane,$ori,$suffix) = (split "_", $r);

	if (defined $info{$library}) {
		my $meta = $info{$library} ;
	} else {
		die "Something is wrong, could not find meta data for $library!\n";
	}

	my $sample = $info{$library}{'sample_name_id'};
	my $external_id = $info{$library}{'external_name'};
	my $alissa = $info{$library}{'alissa_id'} ;
	my $project = $info{$library}{'project'};

	# Determine the running family ID (only relevant for Trios). 
	my $this_fam = undef;

	if (exists($samples{$sample})) {
                $this_fam = $samples{$sample};
        } else {
                $fam_counter += 1;
                $samples{$sample} = $fam_counter;
                $this_fam = $fam_counter;
        }

	my $sample_id = $sample ;
	my $indiv_id = $library ;

	# Generate the desired naming rules - differs between Humgen, IKMB and other. 
	if (defined $alissa) {
		$indiv_id = $alissa;
		$sample_id = $alissa;
	} elsif (defined $external_id) {
		if ( $project =~ /.*Nagel.*/) {
			$indiv_id = $external_id;
			$sample_id = $library . "_" . $external_id ;	
		} else {
			$indiv_id = $sample . "_" . $external_id;
			$sample_id = $sample ;
		}
	}

	# Get the readgroup ID and lane from the fastQ file(s)
	my $header = `zcat $left | head -n1`;

        my $info = (split " ",$header)[0] ;
        my ($instrument,$run_id,$flowcell_id,$lane,$tile,$x,$y) = (split ":", $info);
        my $readgroup = $flowcell_id . "." . $lane . "." . $sample ;
        chomp($readgroup);

	printf "FAM" . $this_fam . "," . $indiv_id . "," . $readgroup . "," . $sample_id . "," . $library . "," . $lane . "," . $left . "," . $right . ",0,0,other,0\n";

}

		
