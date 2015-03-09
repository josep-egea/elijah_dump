
module SparseJson
  
  def values_hash
    h = {}
    each_pair do |k, v|
      h[k.to_s] = v unless v.nil?
    end
    return h
  end

  def to_json(*a)
    values_hash.to_json(a)
  end
  
  def encode_with(coder)
    coder.tag = nil
    values_hash.each do |k,v|
      coder[k] = v
    end
  end
  
end

class Meeting < Struct.new(:title, :meeting_date, :meeting_time, :venue, :details, :details_md, :offered_by, :offered_by_html, :attendees, :map_url, :original_url, :topics)
  
  include SparseJson
  
  def initialize(*args)
    super
    self[:topics] = []
  end
  
end

class Date
  
  def to_json(*a)
    return self.to_s.to_json(a)
  end
  
end


