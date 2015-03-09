
module SparseJson

  def to_json(*a)
    h = {}
    each_pair do |k, v|
      h[k.to_s] = v unless v.nil?
    end
    h.to_json(a)
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


