require './meeting'

class Speaker < Struct.new(:speaker_name, :speaker_handle, :speaker_bio, :speaker_bio_md)

  include SparseJson

end
