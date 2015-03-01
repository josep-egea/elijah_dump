require 'open-uri'
require './page_cache'

class PageFetcher

  @page_cache = nil
  
  def get_page(uri)
    page_data = page_cache.get(uri)
    if !page_data
      open(uri) do |f|
        page_data = f.read
      end
      page_cache.store(uri, page_data) unless page_data.nil?
    end
    return page_data
  end
  
  private  
  
  def page_cache
    if @page_cache.nil?
      @page_cache = PageCache.new
    end
    return @page_cache
  end
  
  
end
