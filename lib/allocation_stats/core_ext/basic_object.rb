class BasicObject
  def class
    (class << self; self end).superclass
  end
end
