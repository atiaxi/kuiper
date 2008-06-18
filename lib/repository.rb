require 'rexml/document'

class Repository
  attr_accessor :root
  
  attr_accessor :everything
  attr_accessor :objects_output
  
  TAG_SEPARATOR=':'
  
  def [](tag)
    return @everything[tag]
  end
  
  def initialize
    reset
  end
  
  # io here is intended to be an IO object, but
  # really can be anything REXML::Document.new understands
  def add(io)
    
    doc = REXML::Document.new(io)
    new_root = KuiObject.from_xml(doc.root)
    if new_root.tag=="universe"
      @root = new_root
    end
    return new_root
  end
 
  def add_from_file(filename, autoresolve = true)
    File.open(filename) do | file |
      add(file)
    end
    resolve_placeholders if autoresolve
  end
  
  # Given the base tag, create a tag that doesn't already exist.
  # (e.g. If the base tag is foo, the created tag will be foo:123)
  def ensure_unique_tag(base, separator=':')
    tagname = base
    tagname = "new_tag" unless tagname
    while(self[tagname])
      tagname = tagname.split(TAG_SEPARATOR)[0]
      number = rand(10000)
      tagname = tagname + "#{separator}#{number}"
    end
  return tagname
  end
  
  # Type is the class of object we're looking for
  # This matches exact class only, no subclasses
  # TODO: Probably want to change that.
  def everything_of_type(type)
    rl = Opal::ResourceLocator.instance
    matches = rl.repository.everything.select do | tag, item |
      item.kind_of?(type) && tag
    end
    return matches.collect { |tag,item| item }
  end
  
  # If we've already output this object, we need
  # only create a reference to it
  def ref_for(kuiobject)
    if @objects_output.include?(kuiobject)
      ref = REXML::Element.new("ref")
      ref.add_attribute("tag", kuiobject.tag)
      return ref
    else
      if kuiobject
        return kuiobject.to_xml
      else
        raise "Attempted to get nil ref"
      end  
    end
  end
  
  def reset
    @root = nil
    @objects_output = Set.new
    @everything = {}
  end
  
  def resolve_placeholders
    rl = Opal::ResourceLocator.instance
    @everything.dup.each do | key, value |
      value.class.children.each do | child_sym |
        child = value.send(child_sym)
        if child.respond_to?(:each)
          child.each do | obj |
            if obj.is_placeholder?
              index = child.index(obj)
              lookup = @everything[child.tag]
              if lookup
                rl.logger.info("Resolved #{tag} to #{lookup}")
              else
                rl.logger.fatal("Unable to resolve tag #{child.tag}")
              end
              child[index] = lookup
            end
          end
        else
          if child && child.is_placeholder?
            setter = (child_sym.to_s+"=").to_sym
            lookup = @everything[child.tag]
            rl.logger.fatal("Unable to resolve tag #{child.tag}") unless lookup
            value.send(setter, lookup)
          end
        end  
      end
      value.post_load
    end
  end
  
  def to_xml(io=$stdout)
    @objects_output = Set.new
    doc = REXML::Document.new()
    doc.add(REXML::XMLDecl.new("1.0", "UTF-8"))
    doc.add(@root.to_xml)
    doc.write(io,2)
  end
  
  def universe
    @root
  end
  
  def universe=(kuiUniverse)
    @root = kuiUniverse
  end
end