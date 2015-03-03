require './jottit_parser.rb'
require 'yaml'

puts("Processing Madrid.rb pages...")

jp = JottitParser.new
meetings = jp.process_all_pages

puts("Writing reesults...")

if !File.directory?('out')
  Dir.mkdir('out')
end

json = JSON.pretty_generate(meetings)
File.open('out/meetings.json', File::CREAT|File::TRUNC|File::WRONLY) do |f|
  f.write(json)
end
puts("Wrote JSON output to out/meetings.json")

yaml = meetings.to_yaml
File.open('out/meetings.yml', File::CREAT|File::TRUNC|File::WRONLY) do |f|
  f.write(yaml)
end
puts("Wrote YAML output to out/meetings.yml")

puts("Done!")

