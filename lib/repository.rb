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
    kuiper = doc.root
    # TODO: Version checks
    kuiper.elements.each do | element |
      obj = KuiObject.from_xml(element)
      if obj.tag == "universe"
        @root = obj
      end
      @everything[obj.tag] = obj
    end

    return @root
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
    # Yes, I am aware that this is not the best way.
    while(self[tagname])
      tagname = tagname.split(TAG_SEPARATOR)[0]
      number = rand(10000)
      tagname = tagname + "#{separator}#{number}"
    end
  return tagname
  end
  
  # Type is the class of object we're looking for
  # Anything that satisfied kind_of? will work
  # If base_only is set, only items that are base-tags will work
  # (e.g. they're not Laser:3344)
  def everything_of_type(type, base_only = false)
    rl = Opal::ResourceLocator.instance
    matches = rl.repository.everything.select do | tag, item |
      kind = item.kind_of?(type)
      result = base_only ? kind && (item.tag == item.base_tag) : kind
      result
    end
    return matches.collect { |tag,item| item }
  end
  
  # Generates a unique tag for the given object
  def generate_tag_for(object)
    total = []
    prefix = object.class.to_s
    prefix = prefix[3...prefix.size()] # Skip 'kui'
    total << prefix.downcase
    
    exclusions = [ 'the','a','an','in','of','from','is', 'and' ]
    
    if object.respond_to?(:name)
      name = object.name
      name = name.strip.downcase
        
      exclusions.each do |x|
        excludeBeginning = Regexp.new("^#{x}\s")
        excludeMiddle = Regexp.new("\s#{x}\s")
        name.gsub!(excludeBeginning,'')
        name.gsub!(excludeMiddle,' ')
      end
     
      total += name.split
    end
    
    initial = total.join("_")
    if initial != object.tag
      initial = ensure_unique_tag(initial,'-')
    end
    return initial
  end
  
  # Returns a <ref> tag for the given object
  def ref_for(kuiobject)
    if kuiobject.tag
      ref = REXML::Element.new("ref")
      ref.add_attribute("tag", kuiobject.tag)
      return ref
    else
      return kuiobject.to_xml
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
              lookup = @everything[obj.tag]
              if lookup
                rl.logger.info("Resolved #{obj.tag} to #{lookup}")
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

    doc = self.to_xml_document
    doc.write(io,2)
  end
  
  def to_xml_document
    doc = REXML::Document.new()
    doc.add(REXML::XMLDecl.new("1.0", "UTF-8"))
    kuiper = REXML::Element.new("kuiper")
    major,minor,bug = $KUIPER_VERSION
    kuiper.add_attribute("major",major.to_s)
    kuiper.add_attribute("minor",minor.to_s)
    kuiper.add_attribute("bug",bug.to_s)
    @everything.each_value do | kui |
      kuiper.add(kui.to_xml)
    end
    doc.add(kuiper)
    return doc
  end
  
  def universe
    @root
  end
  
  def universe=(kuiUniverse)
    @root = kuiUniverse
  end
end