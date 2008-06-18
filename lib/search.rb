require 'set'

class Node
  
  attr_reader :wrapping, :parent
  
  def initialize(object, parent=nil)
    @wrapping = object
    @parent = parent
  end
  
  def to_root
    return [ self ] unless @parent
    return [self] + @parent.to_root
  end
  
end

class SectorSearcher
  
  def initialize(start, destination)
    
    @start = start
    @dest = destination
    
  end
  
  # Returns a list of sectors or nil if no path exists.
  def breadth_first
    return do_breadth_first( [Node.new(@start)], Set.new, @dest)
  end
  
  private
  def do_breadth_first( to_search, visited, destination )
    current = to_search.delete_at(0)
    return nil unless current
    visited << current
    if current.wrapping == destination
      result = current.to_root
      return result.reverse.unwrapped_from_nodes
    end
    
    links = current.wrapping.links_to.reject { |s| visited.include?(s) }
    links = links.as_nodes(current)
    return do_breadth_first(to_search+links, visited, destination)
    
  end
  
end