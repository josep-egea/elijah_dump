class PageCache
  
  def get(uri)
    filename = filename_for_uri(uri)
    filepath = path_for_filename(filename)
    page_data = nil
    begin
      f = File.open(filepath)
      page_data = f.read
      f.close
    rescue
      # Not found
    end
    return page_data
  end
  
  def store(uri, page_data)
    filename = filename_for_uri(uri)
    filepath = path_for_filename(filename)
    f = File.new(filepath, File::CREAT|File::TRUNC|File::WRONLY)
    f.write(page_data)
    f.close
  end
  
  private
  
  def filename_for_uri(uri)
    return uri.gsub('/', '-_-')
  end
  
  def path_for_filename(filename)
    if !File.directory?('page_cache')
      Dir.mkdir('page_cache')
    end
    return './page_cache/' + filename
  end
  
end