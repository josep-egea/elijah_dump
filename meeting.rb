
class Meeting < Struct.new(:title, :meeting_date, :meeting_time, :venue, :details, :speaker_name, :speaker_handle, :speaker_bio, :video_url, :offered_by, :offered_by_html, :attendees, :map_url, :slides_url, :original_url)

  def to_json(*a)
    h = {}
    each_pair do |k, v|
      h[k.to_s] = v unless v.nil?
    end
    h.to_json(a)
  end
  
end

class Date
  
  def to_json(*a)
    return self.to_s.to_json(a)
  end
  
end


