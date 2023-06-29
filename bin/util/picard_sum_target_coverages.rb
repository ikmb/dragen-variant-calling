files = Dir["*selection_per_target_metrics.txt"]

bucket = {}

files.each do |f|

	lines = IO.readlines(f)
	header = lines.shift
	# chrom   start   end     length  name    %gc     mean_coverage   normalized_coverage     min_normalized_coverage max_normalized_coverage min_coverage    max_coverage    pct_0x  read_count

	h = header.split("\t")

	lines.each do |line|
		line.strip

		e = line.split("\t")

		data = {}
		
		h.each_with_index do |c,i|
			data[c] = e[i]
		end

		target = data["name"]

		bucket.has_key?(target) ? bucket[target] << data["mean_coverage"].to_f : bucket[target] = [ data["mean_coverage"].to_f ]

	end
end


bucket.each do |target,covs|

	sum = 0
	covs.each {|c| sum += c }
	mean = sum.to_f/covs.length.to_f

	all_covs = covs.join("\t")
	puts "#{target}\t#{mean}\t#{all_covs}"

end
		
