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
my $project = (split "/", $folder)[-1];
printf STDERR $project . "\n";

my $ext = "/project/info/${project}";

my $response = $http->get($server.$ext, { 
	headers => { 'Content-type' => 'application/json' }
});

my $project_info = decode_json($response->{content});
my $project_id = $project_info->{'project_id'};

my %lookup;

$ext = "/project/pool_info/${project_id}" ;
$response = $http->get($server.$ext, {
        headers => { 'Content-type' => 'application/json' }
});

printf STDERR Dumper($response) . "\n";

my $data = decode_json($response->{content});
my $pools = $data->{'pools'};

foreach my $pool (@$pools) {
	my $libs = $pool->{'libraries'};
	foreach my $lib (@$libs) {
		my $lib_name = $lib->{'library_name_id'};
		my $lib_id = $lib->{'library_id'};
		$ext = "/library/info/${lib_id}";
		$response = $http->get($server.$ext, {
   			headers => { 'Content-type' => 'application/json' }
		});
		my $lib_data = decode_json($response->{content});
		my $external = $lib_data->{'sample'}->{'external_name'};
		if ($external) {
			$lookup{$lib_name} = $external;	
		}
	}
}

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

	my $base_name = (split "/", $left)[-1];
	#my $sample = (split /_S[0-9]*_/, $base_name)[0] ;
	my $library = (split /_L00/, $base_name)[0] ;
	my $sample = undef;
	if ($base_name =~ /^\d+.*/) {
		$sample = (split /_/, $base_name)[1] ;
	} else {
		$sample = (split /_/, $base_name)[0] ;
	}

	chomp($sample);

	my $external_name = $sample;

	if ($lookup{$sample}) {
		$external_name = $lookup{$sample};
	} else {
		$ext = "/library/info/${sample}" ;
		$response = $http->get($server.$ext, {
        		headers => { 'Content-type' => 'application/json' }
		});

		my $ldata = decode_json($response->{content});
		my $lsample = $ldata->{'data'}{'sample'} ;
		$external_name = $lsample->{'external_name'};		
	}
		
	printf STDERR $sample . "\n";
	my $this_fam = 0;

	my $prefix = $sample;

	if ($folder =~ /.*Nagel.*/) {
		$prefix = "${sample}_${external_name}";
	} else {
		$external_name = $prefix . "_" . $external_name ;
	}

	if (exists($samples{$sample})) {
		$this_fam = $samples{$sample};
	} else {
		$fam_counter += 1;
		$samples{$sample} = $fam_counter;
		$this_fam = $fam_counter;
	}

	my $header = `zcat $left | head -n1`;

	my $info = (split " ",$header)[0] ;
	my ($instrument,$run_id,$flowcell_id,$lane,$tile,$x,$y) = (split ":", $info);
	my $readgroup = $flowcell_id . "." . $lane . "." . $sample ;
	chomp($readgroup);	
	printf "FAM" . $this_fam . "," . $external_name . "," . $readgroup . "," . $prefix . "," . $library . "," . $lane . "," . $left . "," . $right . ",0,0,other,0\n";
	printf STDERR $sample . "\t" . $external_name . "\n";
}

