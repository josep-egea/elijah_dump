require './meeting'

class Topic < Struct.new(:title, :details, :video_url, :slides_url, :speakers)

  include SparseJson

  attr_accessor :topic_indexes
  attr_accessor :speaker_indexes
  attr_accessor :resource_indexes
  attr_accessor :additional_indexes
  attr_accessor :found_links

  def initialize(*args)
    super
    self[:speakers] = []
    self.topic_indexes = []
    self.speaker_indexes = []
    self.resource_indexes = []
    self.additional_indexes = []
    self.found_links = []
  end
  
  def has_no_indexes?
    return  topic_indexes.empty? && speaker_indexes.empty? && resource_indexes.empty? && 
            additional_indexes.empty? && found_links.empty?
  end
  
end
