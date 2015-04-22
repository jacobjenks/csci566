#!/usr/bin/env ruby

require 'nokogiri'

@base_directory = File.expand_path(File.dirname(__FILE__))
@base_directory = @base_directory.gsub(/ruby/, "")

docs = @base_directory+"questions"

docs.each do |doc|
	puts doc
	bad_doc = File.open(doc)
	begin
	  bad_doc = Nokogiri::XML(badly_formed) { |config| config.options = Nokogiri::XML::ParseOptions::STRICT }
	rescue Nokogiri::XML::SyntaxError => e
	  puts "caught exception: #{e}"
	end
end