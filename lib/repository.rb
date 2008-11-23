require 'rexml/document'

class Repository
  attr_accessor :root
  
  #attr_accessor :everything
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
    post_load
  end
  
  def add_placeholder(holder)
    @placeholders[holder.tag] ||= []
    @placeholders[holder.tag] << holder
  end
  
  def all_labels
    results = Set.new
    labels = @everything.values.collect do |obj|
      results.merge(obj.label_array.to_set)
    end
    return results.to_a
  end
  
  def delete(obj)
    @everything.delete(obj)
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

  # Returns an array of every tagged object in the repository
  def everything
    return @everything.values
  end
  
  # Type is the class of object we're looking for
  # Anything that satisfied kind_of? will work
  # If base_only is set, only items that are base-tags will work
  # (e.g. they're not Laser:3344)
  def everything_of_type(type, base_only = false)
    rl = Opal::ResourceLocator.instance
    matches = @everything.select do | tag, item |
      kind = item.kind_of?(type)
      result = base_only ? kind && (item.tag == item.base_tag) : kind
      result
    end
    return matches.collect { |tag,item| item }
  end
  
  # Like everything_of_type, only, you know, for any of the given types
  def everything_of_types(types,base_only=false)
    result = []
    types.each do |type|
      result << everything_of_type(type,base_only)
    end
    return result.flatten
  end
  
  def everything_with_label(label)
    return (@everything.values.select do | kui |
      kui.label_array.include?(label)
    end).to_set
  end
  
  def everything_with_labels(labels)
    result = Set.new
    labels.each do | label |
      result.merge(everything_with_label(label))
    end
    return result
  end
  
  # Generates a unique tag for the given object
  def generate_tag_for(object, use_this_name=nil)
    total = []
    prefix = object.class.to_s
    prefix = prefix[3...prefix.size()] # Skip 'kui'
    total << prefix.downcase
    
    exclusions = [ 'the','a','an','in','of','from','is', 'and' ]
    
    if object.respond_to?(:name)
      name = use_this_name || object.name
      if name && name.size > 0
        name = name.strip.downcase
          
        exclusions.each do |x|
          excludeBeginning = Regexp.new("^#{x}\s")
          excludeMiddle = Regexp.new("\s#{x}\s")
          name.gsub!(excludeBeginning,'')
          name.gsub!(excludeMiddle,' ')
        end
       
        total += name.split
      else
        name = "new_object"
      end
    end
    
    initial = total.join("_")
    if initial != object.tag
      initial = ensure_unique_tag(initial,'-')
    end
    return initial
  end
  
  # Every placeholder for the given tag.
  # will return nil if none
  def placeholders_for(tag)
    return @placeholders[tag]
  end
  
  # Does a post_load on everything in the repository
  def post_load
    @everything.keys.dup.each do | tag |
      obj = @everything[tag]
      obj.post_load
    end
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
    
  def register(object)
    register_tag_for(object,object.tag)
  end
  
  def register_tag_for(object, tag, old_tag = nil)
    old = @everything[tag]
    #return if old == object
    rl = Opal::ResourceLocator.instance
    @everything[tag] = object
    if old_tag && old_tag != tag
      old_base = compute_base_tag(old_tag,Repository::TAG_SEPARATOR)
      new_base = compute_base_tag(tag,Repository::TAG_SEPARATOR)
      if old_base != new_base
        @everything.delete(old_tag)
      end
      
    end
    resolve_placeholders_for(object)
    if old
      #rl.logger.debug("Replaced #{old} with #{object} for #{tag}")
    end
  end
  
  def reset
    @root = nil
    @objects_output = Set.new
    @everything = {}
    # Of the form key : [placeholders...]
    @placeholders = {}
  end
  
  # Attempts to crawl the object tree for placeholders.
  # If any are left unresolved, emits an WARN line and
  # returns false
  def resolve_placeholders()
    rl = Opal::ResourceLocator.instance
    
    resolved = true
    @placeholders.dup.each do | tag, holders |
      obj = @everything[tag]
      if obj
        # For some reason, this didn't trigger like it ought to have.  Oh well
        resolve_placeholders_for(obj)
      else
        rl.logger.warn("Could not locate #{tag} ,#{holders.size} needed!")
        resolved = false
      end
    end
    
    return resolved
  end
  
  # This here object was just created; if any placeholders exist for it,
  # replace them with this.
  def resolve_placeholders_for(object)
    rl = Opal::ResourceLocator.instance
    holders = @placeholders[object.tag]
    if holders
      holders.dup.each do | placeholder |
        placeholder.replace_with(object)
      end
      @placeholders.delete(object.tag)
    end
  end
  
  def retrieve(tag)
    return @everything[tag]
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
    @everything.keys.sort.each do | key |
      kui = @everything[key]
      unless kui.transient
        kuiper.add(kui.to_xml)
      end
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