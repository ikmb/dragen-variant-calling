#!/usr/bin/ruby
# == NAME
# lims_get_sample_info.rb
#
# == AUTHOR
#  Marc Hoeppner, mphoeppner@gmail.com

require 'optparse'
require 'ostruct'
require 'rest_client'
require 'json'

### Define modules and classes here

def get_sample_info(project_id)
	warn "Asking: project/sample_info/#{project_id}"
	samples = rest_get("project/sample_info/#{project_id}")
	return samples
end

def get_library_info(library_name)
        linfo = rest_get("library/info/#{library_name}")
        return linfo
end

def validate_folder(path)

	status = Dir.exist?(path)

	return status unless status

	folders = Dir["#{path}/*"]

	warn folders.inspect

	expected = [ /^.*_results/, "FastQC" ]

	missing = []
	expected.each do |e|
		missing << e unless folders.find {|f| f.match(e) }
	end

	missing.empty? ? status = status : status = "Missing expected outputs: #{missing.join(',')}"
	return status

end
	
def rest_get(url)
  $request_counter ||= 0   # Initialise if unset
  $last_request_time ||= 0 # Initialise if unset

  # Rate limiting: Sleep for the remainder of a second since the last request on every third request
  $request_counter += 1
  if $request_counter == 15 
    diff = Time.now - $last_request_time
    sleep(1-diff) if diff < 1
    $request_counter = 0
  end

  begin
    response = RestClient.get "#{$server}/#{url}", {:accept => :json}

    $last_request_time = Time.now
    JSON.parse(response)
  rescue RestClient::Exception => e
    puts "Failed for #{url}! #{response ? "Status code: #{response}. " : ''}Reason: #{e.message}"

    # Sleep for specified number of seconds if there is a Retry-After header
    if e.response.headers[:retry_after]
      sleep(e.response.headers[:retry_after].to_f)
      retry # This retries from the start of the begin block
    else
      abort("Quitting... #{e.inspect}")
    end
  end
end

### Get the script arguments and open relevant files
options = OpenStruct.new()
opts = OptionParser.new()
opts.on("-f","--folder", "=FOLDER", "Input folder") {|argument| options.folder = argument }
opts.on("-n","--name", "=RUNNAME","Run name") {|argument| options.run_name = argument }
opts.on("-o","--outfile", "=OUTFILE","Output file") {|argument| options.outfile = argument }
opts.on("-h","--help","Display the usage information") {
 puts opts
 exit
}

opts.parse! 

options.outfile ? output_stream = File.new(options.outfile,'w') : output_stream = $stdout

$server = 'http://172.21.99.59/restapi'

status = validate_folder(options.folder)

abort "Encountered error: #{status} - aborting" unless status

qc_files = Dir["#{options.folder}/FastQC/*.html"]

library_name = qc_files[0].split("_L00")[0].split("/")[-1].split("_")[1..-2].join("_")

warn library_name

library_info = get_library_info(library_name)["data"]

library_id = library_info["library_name_id"]
external_name = library_info["sample"]["external_name"] ||= ""
sample_id = library_info["sample"]["sample_name_id"]
lims_project_name = library_info["project"]["project_name_id"]
lims_project_id = library_info["project"]["project_id"]

d = DateTime.now
date = d.strftime("%Y-%m-%d")
rname = options.run_name ||= ""

data = {	
	"library_id" => library_id,
	"external_name" => external_name,
	"sample_id" => sample_id,
	"lims_project_name" => lims_project_name,
	"lims_project_id" => lims_project_id,
	"run_date" => date,
	"run_name" => rname
}

output_stream.puts data.to_json
