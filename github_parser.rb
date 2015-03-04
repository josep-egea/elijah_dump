require './jottit_parser'
require './github_page_parser'

class GithubParser < JottitParser 
  
  @page_fetcher = nil
  @page_parser = nil
  
  def list
    page_data = page_fetcher.get_page('https://github.com/madridrb/madridrb.github.io/wiki')
    doc = Nokogiri::HTML(page_data)
    pages = []
    doc.css('#wiki-rightbar li a').each do |link|
      page = link[:href]
      page_uri = URI.parse(page)
      # Github links are relative
      page_uri.scheme = 'https'
      page_uri.host = 'github.com'
      pages << page_uri.to_s
    end
    return pages
  end
      
  def write_meeting(meeting)
    # puts meeting.to_yaml
  end
  
  private
  
  def parser_name
    return 'Github'
  end
  
  def page_parser
    if @page_parser.nil?
      @page_parser = GithubPageParser.new
    end
    return @page_parser
  end
  
  def omit_uri?(uri)
    return true if uri =~ /github.io\/wiki$/
  end
  
end
