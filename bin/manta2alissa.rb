#!/usr/bin/env ruby
# == NAME
# manta2alissa.rb
#
# == USAGE
# ./this_script.rb [ -h | --help ]
#[ -i | --infile ] |[ -o | --outfile ] | 
# == DESCRIPTION
# A skeleton script for Ruby
#
# == OPTIONS
# -h,--help Show help
# -i,--infile=INFILE input file
# -o,--outfile=OUTFILE : output file

#
# == EXPERT OPTIONS
#
# == AUTHOR
#  Marc Hoeppner, mphoeppner@gmail.com

require 'optparse'
require 'ostruct'

### Define modules and classes here

class VCFEntry

  attr_accessor :seq, :pos, :id, :ref, :alt, :qual, :filter, :info, :format, :samples

  def initialize(string)

    @seq, @pos, @id, @ref,@alt,@qual,@filter,@info,@format = string.strip.split("\t")[0..8]
    @samples = string.split("\t")[9..-1]

  end

  def to_s
	samples = self.samples.join("\t")
	return "#{self.seq}\t#{self.pos}\t#{self.id}\t#{self.ref}\t#{self.alt}\t#{self.qual}\t#{self.filter}\t#{self.info}\t#{self.format}\t#{samples}"
  end

end

### Get the script arguments and open relevant files
options = OpenStruct.new()
opts = OptionParser.new()
opts.banner = "A script description here"
opts.separator ""
opts.on("-i","--infile", "=INFILE","Input file") {|argument| options.infile = argument }
opts.on("-o","--outfile", "=OUTFILE","Output file") {|argument| options.outfile = argument }
opts.on("-h","--help","Display the usage information") {
 puts opts
 exit
}

opts.parse! 

options.infile ? input_stream = File.open(options.infile,"r") : input_stream = $stdin
options.outfile ? output_stream = File.new(options.outfile,'w') : output_stream = $stdout

while (line = input_stream.gets)

	line.strip!

	if line.match(/^#.*/)
		output_stream.puts line
	else

		entry = VCFEntry.new(line.strip)

		if entry.alt == "<INS>"
			entry.alt = "<DUP>"
		end
		if entry.id.include?("MantaINS")
			info = entry.info
			if entry.alt.match(/\<[A-Z]+\>/)
				entry.info = info.gsub(/SVTYPE\=[A-Z]+\;/, "SVTYPE=DUP;")
			else
	                        entry.info = info.gsub(/SVTYPE\=[A-Z]+\;/, "")
			end
		elsif entry.id.include?("MantaDEL") && entry.alt != "<DEL>"
                        info = entry.info
			entry.info = info.gsub(/SVTYPE\=[A-Z]+\;/, "")
		end
		output_stream.puts entry.to_s
	end

end

input_stream.close
output_stream.close
