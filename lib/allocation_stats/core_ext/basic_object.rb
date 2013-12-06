# monkey patch to BasicObject, allowing it to respnd to :class
#
# @private
class BasicObject
  # monkey patch to BasicObject, allowing it to respnd to :class
  #
  # @private
  def class
    (class << self; self end).superclass
  end
end
