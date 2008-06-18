# This file is specifically overrides for ruby language items

require 'utility'
require 'adapters'
require 'search'

class Array
  
  # Returns a ListAdapter for this array, with the given constraint.  If the
  # type is not supplied, it will take the type of the first item in the array
  # or Object if the array is empty
  def as_adapter(type=nil)
    t = type
    if type == nil
      t = self[0] ? self[0].class : Object
    end
    return ListAdapter.new(self, type)
  end
  
  def as_nodes(parent=nil)
    return self.collect { |x| Node.new(x,parent) }
  end
  
  def delete_first(obj)
    first = self.index(obj)
    if first
      return self.delete_at(first)
    end
    return nil
  end
  
  def random
    if size > 0
      return self[rand(size)]
    else
      return nil
    end
  end
  
  def unwrapped_from_nodes
    return self.collect { |x| x.wrapping }
  end
end

class FalseClass
  def to_boolean
    self
  end
end


# Some time ago, in some language, there was a function that would tell you what
# the sign of a number was, and it was built in.  Nothing's had it since.
class Numeric
  def positive?
    return self >= 0
  end
  
  def to_degrees
    return self * (180.0 / Math::PI)
  end
  
  def to_radians
    return self * (Math::PI / 180.0)
  end
end

class Range
  
  # Returns a random number between the first and last numbers of this interval.
  # It is assumed that the items are, in fact, numbers, and integers to boot.
  def random
    diff = self.last - self.first
    return self.first if diff == 0
    return (self.first + rand(diff+1))
  end
  
end

class String
  
  # Whether or not this string ends with the given character
  def ends_with?(char)
    return self[self.size-1] == char
  end
  
  # A string is null if it is non-empty but consists of only the null byte
  def is_null?
    self.each_byte do |byte|
      return false unless byte == 0
    end
    return self.size > 0
  end
  
  # Whether or not this string starts with the given character
  def starts_with?(char)
    return self[0] == char
  end
  
  # Converts a string to a boolean.
  # False values include "false" "f" "no" "nil", any string that's a number
  # which evaluates to zero, and the uppercase variants.
  # Anything that is not a false value is true
  def to_boolean
    down = self.downcase
    case(down)
    when "false"
      return false
    when "f"
      return false
    when "no"
      return false
    when "nil"
      return false
    end
    return false if self.number? && self.to_f == 0.0
    return true
  end
  
  # Does this string have a valid number in it?
  def number?
    value = self.to_f
    if value == 0
      return false if size == 0
      if self[0] == ?-
        return self.size > 1 && self[1] == ?0
      end
      return self[0] == ?0
    end
    return true
  end
end

# Seriously, I can't sort symbols?  WTF?
class Symbol
  
  include Comparable
  def <=>(other)
    return false if other.nil?
    return self.to_s <=> other.to_s
  end
  
end

class TrueClass
  def to_boolean
    self
  end
end

class NilClass
  def to_boolean
    return false
  end
end

