require 'overrides'
require 'engine'

require 'set'
require 'rexml/document'

# This module delegates anything the includer doesn't understand to that
# class' blueprint, if it exists.
module BlueprintDelegator
  
  def delegate(name, attrs=[])
    if @blueprint
      return @blueprint.send(name,*attrs)
    else
      raise NoMethodError.new
        ("undefined method #{name} for #{self}:#{self.class}")
    end
  end
  
  def method_missing(name, attrs = [])
    delegate(name, attrs)
  end
  
  alias :old_respond_to? :respond_to?
  
  def respond_to?(symbol)
    return true if old_respond_to?(symbol)
    if not super(symbol)
      @blueprint ||= nil
      if @blueprint
        return @blueprint.respond_to?(symbol)
      end
      return false
    end
  end
  
end

class Placeholder
  attr_accessor :tag
  attr_accessor :in_list
  
  def initialize(tag_name, in_list=nil)
    @tag = tag_name
    @in_list = in_list
  end
  
  def is_placeholder?
    return true
  end
  
  def replace_with(aKuiObject)
    index = nil
    while(index = @in_list.index(self))
      @in_list[index] = aKuiObject
    end
  end
  
  def to_s
    return "#<Placeholder for: #{@tag}>"
  end
end

# Root class of all objects intended to be 
# serializable via XML.
# Attributes are made into accessors and such,
# so don't name them something like 'id'!
class KuiObject
  # Editable, or "Field" attributes
  def self.attrs
    return @attrs if @attrs
    @attrs = Set.new

    if(self.superclass.respond_to?(:attrs))
      inherited = self.superclass.attrs
      @attrs = @attrs.merge(inherited)
    end
    @attrs
  end
  
  def self.booleans
    return @booleans if @booleans
    @booleans ||= Set.new

    if(self.superclass.respond_to?(:booleans))
      inherited = self.superclass.booleans
      @booleans = @booleans.merge(inherited)
    end
    @booleans
  end
  
  # Like numeric_attr but for booleans
  def self.boolean_attr( *arr)
    self.booleans.merge(arr)
    
    attr_reader(*arr)
    arr.each do | a |
      setter = (a.to_s + "=").to_sym
      class_eval do
        define_method( setter ) do | v |
          instance_variable_set("@" + a.to_s, v.to_boolean)
        end
      end
    end
  end
  
  def self.children
    return @children if @children
    @children ||= Set.new
    
    if self.superclass.respond_to?(:children)
      inherited = self.superclass.children
      @children = @children.merge(inherited)
    end
    
    @children
  end
  
  def self.enumerations
    @enums ||= {}

    if(self.superclass.respond_to?(:enumerations))
      inherited = self.superclass.enumerations
      @enums = @enums.merge(inherited)
    end
    @enums
  end
  
  # enumerable_attr acts a little differently than the others; you can define
  # only one symbol as the enumerable per line, the other arg is a list of valid
  # entries.
  def self.enumerable_attr( arg, possibles )
    attr_reader(arg)
    self.enumerations[arg] = possibles
    
    setter = (arg.to_s + "=").to_sym
    class_eval do
      define_method( setter ) do |v|
        valids = self.class.enumerations[arg.to_sym]
        if valids.index(v.to_sym)
          instance_variable_set("@" +arg.to_s, v.to_sym)
        else
          msg = "Attempt to call #{setter} with invalid enum #{v}"
          Opal::ResourceLocator.instance.logger.warn(msg)
        end
      end
    end
  end  
  
  def self.from_xml(element)
    rl = Opal::ResourceLocator.instance
    if element.name=="ref"
      tag = element.attributes["tag"]
      obj = rl.repository.retrieve(tag)
      unless obj
        holder = Placeholder.new(tag)
        rl.repository.add_placeholder(holder)
        return holder
      end
    else
      subclass = subclasses(true).detect do | sub |
        fullname = "kui"+element.name
        fullname == sub.name.downcase
      end  
      if subclass
        obj = subclass.new
      else
        rl.logger.fatal("Unable to create a(n) #{element.name}")
      end
    end
    
    # Set all the attributes
    element.attributes.each do | key,value |
      setter = (key+"=").to_sym
      begin
        obj.send(setter, value)
      rescue NoMethodError
        rl.logger.warn("#{obj.class} does not recognize #{setter}: Likely "+
          "file format incompatability")
      end  
    end
    
    kids = element.children.select { |c| c.is_a?(REXML::Element) }
    
    kids.each do | child |
      child_name = child.attribute('name').value
      current = nil
      begin
        current = obj.send(child_name)
      rescue NoMethodError 
        rl.logger.warn("#{obj.class} does not recognize #{child_name}: Likely "+
          "file format incompatability")
        next
      end
      child.children.each do | new_obj_element |
        if new_obj_element.is_a?(REXML::Element)
          new_obj = KuiObject.from_xml(new_obj_element)
          if current.respond_to?(:<<)
            current << new_obj
          else
            child_setter = (child_name + "=").to_sym
            obj.send(child_setter, new_obj)
          end
        end
      end
    end
    
    return obj
  end
  
  # Courtesy ruby-talk post 11740
  # Adapted because I only care about KuiObject subclasses in this instance
  def self.inherited(subclass)
    if @subclasses
      @subclasses << subclass
    else
      @subclasses = [subclass]
    end
  end
  
  # Just registers the given args as (ordinary) attributes,
  # without creating getters and setters for them.
  def self.raw_attr(*args)
    self.attrs.merge(args)
  end
  
  # All the direct subclases of this class.
  # if expand is true, all their subclasses (and so on)
  def self.subclasses(expand = false)
    @subclasses ||= []
    subs = []
    if expand
      subs = @subclasses.collect { |sub| sub.subclasses(true) }
      subs.flatten!
    end
    return @subclasses + subs
  end
  
  # numeric_attr is a special attr_accessor that converts the setter to
  # a number
  def self.numeric_attr( *arr )
    self.attrs.merge(arr)
    
    attr_reader(*arr)
    arr.each do | a |
      setter = (a.to_s + "=").to_sym
      class_eval do
        define_method( setter ) do | v |
          instance_variable_set("@" + a.to_s, v.to_f)
        end
      end
    end
  end
  
  # string_attr is attr_accessor but also registers us in the @attrs array.
  def self.string_attr( *arr )
    self.attrs.merge(arr)
    
    attr_accessor(*arr)

  end
  
  # commentable_attr is a string_attr that reports different values for its
  # accessor if not in $edit_mode.  Specifically, anything between /* */ is
  # deleted
  def self.commentable_attr(*arr)
    self.attrs.merge(arr)
    
    attr_writer(*arr)
    arr.each do |getter|
      class_eval do
        define_method(getter) do
          result = instance_variable_get("@" +getter.to_s)
          # Regexp courtesy http://ostermiller.org/findcomment.html
          if result && !$edit_mode
            result.gsub!(/\/\*(.|[\r\n])*?\*\//, '')
          end
          result
        end
      end
    end
  end
  
  # Registers in a 'children' array
  def self.child(*arr)
    self.children.merge(arr)
    
    attr_accessor(*arr)
  end
  
  # Hints to the GUI as to what size (in rows and columns) the entry box for
  # the given attribute should be.  If either is zero, this attribute will not
  # appear at all, and thus cannot be changed by the user.
  def self.set_size_for(attr, value)
    @sizes ||= {}
    @sizes[attr] = value
  end
  
  def self.size_for(attr)
    @sizes ||={}
    if self.superclass.respond_to?(:size_for)
      size = self.superclass.size_for(attr)
      @sizes[attr] = size if size
    end
    return @sizes[attr]
  end
  
  raw_attr :labels
  attr_reader :label_array

  def initialize()
    @tag = nil
    self.labels = ""
    @rl = Opal::ResourceLocator.instance
    super
  end
  
  # Two objects are == if their tags are identical
  def ==(other)
    #return self.deep_equals(other)
    return false unless other
    if self.respond_to?(:tag) && other.respond_to?(:tag)
      return self.tag.eql?(other.tag)
    else
      return self.eql?(other)
    end
  end
  
  # Two objects are === if their base tags are identical.
  def ===(other)
    return self.base_tag == other.base_tag
    #return self.do_equal(other, Set.new,true)
  end
  
  # So I don't have objects calling obj.blarg=new_list
  # all over the damn place, this essentially does that.
  def adopt_child(sym,new_list)
    if !sym.to_s.ends_with?($=)
      sym = (sym.to_s + "=").to_sym
    end
    self.send(sym, new_list)
  end
  
  def base_tag(separator = Repository::TAG_SEPARATOR)
    return @tag.split(separator)[0] if @tag
    return nil
  end

  # Old ==, compares fields, children, everything.
  def deep_equals(other)
    return self.do_equal(other)
  end
  
  # Fully recursive equals - very slow!  Use only if you actually need it.
  def do_equal(other, already_compared = Set.new,base=false)
    return true if already_compared.include?(other)
    
    return false unless self.class == other.class
    
    self.class.attrs.each do | attr |
      # This is slightly awkward because I was debugging and needed to print
      # equal out.
      equal = false
      if attr.eql?(:tag)
        if base
          equal = self.base_tag == other.base_tag
        else
          equal = self.tag == other.tag
        end
      else
        #puts "About to get our result for: #{attr}"
        our_result = self.send(attr)
        their_result = other.send(attr)
        equal = our_result == their_result
      end
      return false unless equal
    end
    
    self.class.booleans.each do | boolean |
      
      our_result = self.send(boolean)
      their_result = other.send(boolean)
      equal = self.send(boolean) == other.send(boolean)

      return false unless equal
    end
    
    self.class.enumerations.each do | enum, possibles |
      equal = self.send(enum) == other.send(enum)
      return false unless equal
    end
    
    already_compared << other
    
    self.class.children.each do | child_sym |
      our_children = self.send(child_sym)
      their_children = other.send(child_sym)
      if our_children.respond_to?(:each_index)
        return false unless our_children.size == their_children.size
        our_children.each_index do | index |
          our_child = our_children[index]
          their_child = their_children[index]
          return true if our_child.nil? && their_child.nil?
          result = our_child.do_equal(their_child, already_compared,base)
          return result
        end
      else
        if our_children
          return our_children.do_equal(their_children, already_compared,base)
        else
          return our_children == their_children
        end
      end
    end      
    
    return true
    
  end
  
  def is_placeholder?
    return false
  end
  
  # Returns a Binding object for this KuiObject; for use in ERB
  def kuibinding
    return binding()
  end
  
  def labels
    return @labels
  end
  
  # CSV is, as you might expect, a comma separated list of values that represent
  # the labels for this object.
  def labels=(csv)
    @labels = csv
    label_array = csv.split(",")
    label_array = label_array.collect { |l| l.downcase.strip }
    @label_array = label_array.reject { |l| l.size <= 0 }
  end
  
  # Returns true if this has all the fields it requires to be in the game, as
  # well as whether its required children are playable.  This isn't a
  # substitute for actually functioning; a ship with tiny acceleration is
  # 'playable' because the game won't barf, not because it'll be fun.
  def playable?
    return false unless @tag
    return true
  end
  
  #If an object needs to do something after it's been fully loaded, this is
  # the method to override.
  def post_load
    
  end

  def synopsis
    return @tag
  end

  # All kuiobjects with a non-blank tag can be
  # looked up in the repository
  string_attr :tag

  # Setting a KuiObject's tag will cause the object to store itself
  # in the repository under that name.
  def tag=(string)
    rl = Opal::ResourceLocator.instance
    repo = rl.storage[:repository]
    if repo
      repo.register_tag_for(self, string)
    end
    @tag = string
  end
  
  def to_xml
    @rl.repository.objects_output << self
    e = REXML::Element.new(self.type_name.downcase)
    e.add_attribute("tag", self.tag)
    fields = fields_to_xml
    e.add(fields)
    
    children = children_to_xml
    e.add(children)
    
    return e
  end
  
  def fields_to_xml()
    result = REXML::Element.new('fields')
    enums = self.class.enumerations.keys
    fields = self.class.attrs + self.class.booleans + enums
    fields.delete(:tag)
    fields.each do | attr |
      result.add(field_to_xml(attr))
    end
    
    return result
  end
  
  def field_to_xml(field)
    sent = self.send(field)
    result = REXML::Element.new(field.to_s)
    # For now, all fields are exported as CData
    value = REXML::CData.new(sent.to_s)
    result.add(value)
    return result
  end
  
  def children_to_xml()
    result = REXML::Element.new('children')
    self.class.children.each do |child|
      result.add(child_to_xml(child))
    end
    return result
  end
  
  def child_to_xml(child)
    result = REXML::Element.new(child.to_s)
    children = self.send(child)
    unless children.respond_to?(:each)
        children = [ children ]
    end
    children.each do | obj |
      child_element = nil
      if obj && obj.tag
        child_element = @rl.repository.ref_for(obj)
      elsif obj
        child_element = obj.to_xml
      end
      result.add(child_element) if child_element
    end
    return result
  end
  
  def type_name
    className = self.class.to_s
    return className[3..className.size] # Cut off the 'kui'
  end

end

# Include items we refactored out
require 'kuiderived'
require 'kuispaceworthy'
require 'kuimission'