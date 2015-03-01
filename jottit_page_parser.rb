# Parses a page, using one of its specialized helper classes

require './meeting'
require './node_additions'

class JottitPageParser
  
  @page_data = nil
  @page_doc = nil
  @page_content = nil
  @meeting = nil
  
  def parse_page(page_data)
    set_page_data(page_data)
    break_page_in_chapters
    parse_chapters
    return @meeting
  end
  
  private
  
  def set_page_data(page_data)
    @page_data = page_data
    @page_doc = Nokogiri::HTML(@page_data)
    @page_content = @page_doc.at_css('#content')
    @meeting = Meeting.new()
    @nodes_for_metadata = []
    @index_h1 = nil
    @index_offered_by = nil
    @index_attendees = nil
    @index_speaker = nil
  end
  
  def break_page_in_chapters
    @page_chapters = @page_content.break_in_header_chapters
  end
  
  # Applies different heuristics and fires the correct parser for the page
  def parse_chapters
    find_indexes
    return if @index_h1.nil?
    get_main_content
    get_content_for_metadata
  end
  
  def get_main_content
    header = @page_chapters[@index_h1][:header]
    contents = @page_chapters[@index_h1][:contents]
    @meeting.title = header.content
    @links_in_title = header.css('a')
    details = ""
    contents.each do |node|
      if @index_h1 == 0 && node_has_metadata?(node)
        # These are not really details
        @nodes_for_metadata << node
      else
        details << node.to_html
      end
    end
    @meeting.details = details
  end
  
  # If there are no @nodes_for_metadata and index_h1 > 0, tries to find content for metadata
  # from the prefix
  
  def get_content_for_metadata
    if @nodes_for_metadata.nil? || @nodes_for_metadata.empty?
      if @index_h1 > 0
        @page_chapters[0..(@index_h1 - 1)].each do |chapter|
          chapter[:contents].each do |node|
            if node_has_metadata?(node)
              @nodes_for_metadata << node
            end
          end
        end 
      else
        puts "No contents for metadata in page: #{@page_chapters.to_yaml}"
      end
    end
  end
  
  # Tries to determine the indexes of the relevant chapters
  
  def find_indexes
    @page_chapters.each_index do |idx|
      h = @page_chapters[idx][:header]
      if h
        hcontent = h.content
        @index_h1 = idx if h.name == 'h1'
        @index_offered_by = idx if hcontent == 'Ofrecido por' || hcontent == 'Offered by'
        @index_attendees = idx if hcontent == 'Asistentes' || hcontent == 'Attendees'
        @index_speaker = idx if   @index_speaker.nil? &&
                                  @index_h1 && 
                                  idx != @index_offered_by &&
                                  idx != @index_speaker
      end
    end
    puts "No h1 in page: #{@page_chapters.to_yaml}" if @index_h1.nil?
    puts "Index of h1: #{@index_h1}"
  end
  
  # Returns true if the text inside the node contains relevant field content
  
  def node_has_metadata?(node)
    raw_text = node.content.downcase
    puts "Find metadata in: #{raw_text}"
    return true if raw_text =~ /fecha\:\s/
    return true if raw_text =~ /hora\:\s/
    return true if raw_text =~ /lugar\:\s/
    return true if raw_text =~ /date\:\s/
    return true if raw_text =~ /time\:\s/
    return true if raw_text =~ /venue\:\s/
    # No relevant field found, so this is not a metadata block
    return false
  end
  
end