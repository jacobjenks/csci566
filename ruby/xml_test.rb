#!/usr/bin/env ruby

require 'nokogiri'

@base_directory = File.expand_path(File.dirname(__FILE__))
@base_directory = @base_directory.gsub(/ruby/, "")

docs = Dir[@base_directory+"questions/*"]
output = ""

docs.each do |doc|
	badly_formed = File.read(doc)
	begin
		bad_doc = Nokogiri::XML(badly_formed) { |config| config.options = Nokogiri::XML::ParseOptions::STRICT }
	rescue Nokogiri::XML::SyntaxError => e
		output += "Error in "+File.basename(doc)+"\r\n"
		output += "     caught exception: #{e}"+"\r\n"
	end
end

if(output.length > 0)
	puts output
else
	puts "No errors found"
end