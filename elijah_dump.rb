require './jottit_parser.rb'
require 'yaml'

jc = JottitParser.new
jc.process_all_pages

