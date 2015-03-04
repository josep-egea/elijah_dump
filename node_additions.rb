require 'nokogiri'

# Extends the Node class to "chapterize" the contents of a node
# We define chapterizing as finding all header tags that are direct children of the provided
# node and group each header node with the content that follows it (until the next header)

class Nokogiri::XML::Node
  
  # Returns an array of hashes, where each has:
  #   :header => The header node
  #   :contents => An array of nodes
  # Options
  #   :exclude_orphans 
  #     If true, the content before the first header is skipped. 
  #     If false, it's added with a nil header.
  #     Default: false
  #   :include_whitespace
  #     If false, blocks of blank text (spaces, tabs, newlines, etc) are skipped
  #     Default: false
  
  def break_in_header_chapters(options = {})
    exclude_orphans = options[:exclude_orphans] || false
    include_whitespace = options[:include_whitespace] || false
    ignore_headers_beyond_level = options[:ignore_headers_beyond_level] || 9
    chapters = []
    current_chapter_header = nil
    current_chapter_nodes = []
    self.children.each do |node|
      if node.name =~ /^h[1-#{ignore_headers_beyond_level}]$/
        # We have a new header. First, we store the current one, if any
        if current_chapter_header || !exclude_orphans
          unless !include_whitespace && current_chapter_nodes.empty?
            chapters << {   :header => current_chapter_header, :contents => current_chapter_nodes} 
          end
        end
        current_chapter_header = node
        current_chapter_nodes = []
      else
        # Not a header. We add the node to the current one, if any
        if current_chapter_header || !exclude_orphans
          current_chapter_nodes << node unless (!include_whitespace && node.blank?)
        end
      end
    end
    # And last, if we have a current header, we store it too...
    if current_chapter_header || !exclude_orphans
      unless !include_whitespace && current_chapter_nodes.empty?
        chapters << {   :header => current_chapter_header, :contents => current_chapter_nodes} 
      end
    end
    # puts chapters.to_yaml
    return chapters
  end
    
end
