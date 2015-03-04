require './jottit_parser.rb'
require './github_parser.rb'
require 'yaml'

meetings = []

puts("Processing Madrid.rb pages...")

jp = JottitParser.new
meetings.concat(jp.process_all_pages)

gp = GithubParser.new
meetings.concat(gp.process_all_pages)

puts("Writing results...")

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

