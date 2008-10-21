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
  
  def initialize(tag_name)
    @tag = tag_name
  end
  
  def is_placeholder?
    return true
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
      obj = rl.repository.everything[tag]
      unless obj
        return Placeholder.new(tag)
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
    @tag = "new_tag"
    self.labels = ""
    @rl = Opal::ResourceLocator.instance
    super
  end
  
  # Two objects are == if their tags are identical
  def ==(other)
    #return self.deep_equals(other)
    return false unless other
    return self.tag.eql?(other.tag)
  end
  
  # Two objects are === if their base tags are identical.
  def ===(other)
    return self.base_tag == other.base_tag
    #return self.do_equal(other, Set.new,true)
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
    repo = Opal::ResourceLocator.instance.storage[:repository]
    if repo
      repo.register_tag_for(self, string)
    end
    @tag = string
  end
  
  def to_xml
    @rl.repository.objects_output << self
    e = REXML::Element.new(self.type_name.downcase)
    e.add_attribute("tag", self.tag)
    self.class.attrs.each do | attr |
      sent = self.send(attr)
      e.add_attribute(attr.to_s, sent.to_s) unless sent.nil?
    end
    
    self.class.booleans.each do | boolean |
      sent = self.send(boolean)
      e.add_attribute(boolean.to_s, sent.to_s) unless sent.nil?
    end
    
    self.class.enumerations.each do | enum, possibles |
      sent = self.send(enum)
      e.add_attribute(enum.to_s, sent.to_s) unless sent.nil?
    end
    
    self.class.children.each do | child |
      children_element = REXML::Element.new("child")
      children_element.add_attribute("name", child.to_s)
      children = self.send(child)
      unless children.respond_to?(:each)
        children = [ children ]
      end
      children.each do | obj |
        if obj
          child_element = @rl.repository.ref_for(obj)
          children_element.add_element(child_element)
        end
      end
      e.add_element(children_element)
    end
    
    return e
  end
  
  def type_name
    className = self.class.to_s
    return className[3..className.size] # Cut off the 'kui'
  end

end

class KuiCargoBlueprint < KuiObject
  string_attr :name
  numeric_attr :base_price
  
  string_attr :description
  set_size_for :description, [5,40]
  
  def initialize
    super
    @name = nil
    @base_price = 0
  end
  
  # The amount of space this takes up, per unit, in the cargo hold.  In a lot of
  # places, I just assume this is 1 and go on my way, but if I ever want to
  # change that, this is where I'd begin.
  def cargo_required
    return 1
  end
  
  def playable?
    return false unless super
    return false unless @name
    return true
  end
  
  def synopsis
    return "#{@name} (blueprint)"
  end
  
end

class KuiCargo < KuiObject
  child :blueprint
  
  numeric_attr :markup
  numeric_attr :amount
  numeric_attr :average_price
  
  boolean_attr :mission_related
  
  include BlueprintDelegator
  
  def initialize
    super
    @markup = 0
    @amount = 0
    @average_price = 0
    @blueprint = nil
    @mission_related = false
  end
  
  # Two cargos are === if their blueprints are the same
  def ===(other)
    return @blueprint == other.blueprint
  end
  
  def initialize_copy(copy)
    self.tag = @rl.repository.ensure_unique_tag(copy.tag)
  end
  
  def synopsis
    if @blueprint
      if @amount > 1
        amount = " x#{@amount.to_i}"
      else
        amount = ''
      end
      
      if @average_price > 0
        avg = " (purchased for #{@average_price})"
      else
        avg = " available for #{self.price} each."
      end
      
      return @blueprint.name + amount + avg
    else
      return "Unplayable cargo (no blueprint!)"
    end
  end
  
  def playable?
    return false unless super
    return @blueprint != nil
  end
  
  def price
    if @blueprint
      return @blueprint.base_price + @markup
    else
      return nil
    end
  end
end

# The player has a set of flags that can be set
# and re-checked with conditions
class KuiFlag < KuiObject
  
  numeric_attr :value
  string_attr :note
  
  def playable?
    return false unless super
    return false unless (note || value)
    return true
  end
  
end

class KuiFleet < KuiObject
  
  child :ships
  child :owner
  
  numeric_attr :spawn_chance  # Chance every second that this will spawn
  numeric_attr :min_stay      # Min. seconds this fleet will stay in sector
  numeric_attr :max_stay      # Max. seconds this fleet will stay in sector
  numeric_attr :current_stay  # If spawned in, how long we've been here.
  
  enumerable_attr :behavior, [ :trade, :patrol, :scan ]
  enumerable_attr :under_attack, [ :fight, :flee ]
  
  # This is optional; random bounty missions use it and not much else.  With
  # this unset, the name of the fleet will be the name of the first ship in it.
  string_attr :name
  
  # Unique fleets only have one spawn active at a time.  If they are tracked by
  # a mission when killed, they will not respawn in the sector they died in.
  boolean_attr :unique 
  
  def initialize
    @spawn_chance = 0
    @min_stay = 0
    @max_stay = 0
    @curent_stay = 0
    @ships = []
    @behavior = :trade
    @under_attack = :flee
    @owner = nil
    @unique = false
    super
  end
  
  # This separately copies the ships, so that their destruction doesn't effect
  # yet-to-be-spawned copies
  def initialize_copy(copy)
    @ships = copy.ships.collect do |ship| 
      dupe = ship.dup
      dupe.owner = @owner
      dupe
    end
  end
  
  def kill(ship)
    @ships.delete(ship)
  end
  
  # This should only be called as the result of combat, not from jumping. It
  # informs all interested missions of the player that this fleet is dead.
  # Records this fact in the given sector if we need to.  Removes 
  def kill_fleet(sector)
    prototype = @rl.repository.everything[self.base_tag]
    player = @rl.repository.universe.player
    inform = player.missions.select do | mission |
      mission.fleets_to_die.include?(prototype)
    end
    inform.each do | mission |
      unless mission.fleets_that_died.include?(prototype)
        mission.fleets_that_died << prototype
      end
      unless sector.killed_fleets.include?(prototype)
        sector.killed_fleets << prototype
      end
      sector.active_fleets.delete(self)
    end
  end
  
  def playable?
    return false unless super
    return false unless @ships.size > 0
    return false unless @spawn_chance > 0
    return false unless @max_stay > 0 && @max_stay >= @min_stay
    return self.class.enumerations[:behavior].index(@behavior) != nil
  end
  
  def update(delay)
    @current_stay += delay
  end
end

# A Halo is placed around a sector on the map; it highlights it, probably for
# mission use
class KuiHalo < KuiObject
  
  numeric_attr :r
  numeric_attr :g
  numeric_attr :b
  
  def initialize(red=0, green=255, blue=0)
    super()
    @r = red
    @g = green
    @b = blue
  end
  
  def ==(other)
    return @r == other.r && @g == other.g && @b == other.b
  end
  
  def as_color
    return [ @r, @g, @b ]
  end
  
end

class KuiMap < KuiObject
  child :sectors
  
  def initialize
    super
    @sectors = []
  end
  
  # This just removes the sector from the map, it does no other dependency 
  # checking
  def delete(sector)
    @sectors.delete(sector) 
  end
  
  def playable?
    return false unless super
    @sectors.each { |sector| return false unless sector.playable? }
    return false if @sectors.empty?
    return true
  end
end

class KuiOrg < KuiObject
  
  FANATIC_DEVOTION = 1000000
  UTTER_LOATHING = -1000000
  LEVEL_NAMES = [ "Kill on Sight",
    "Unfriendly",
    "Neutral",
    "Friendly",
    "Devoted" ]
  LEVEL_SYMBOLS = [
    :kill_on_sight,
    :unfriendly,
    :neutral,
    :friendly,
    :devoted
  ]

  numeric_attr :shooting_mod
  numeric_attr :killing_mod
  # If our attitude is friendly or above, we multiply by this whenever
  # bad things are done to us by our friend
  numeric_attr :friendly_multiplier
  numeric_attr :friendly_shots_threshold
  
  # The 'steps'
  numeric_attr :kill_on_sight
  numeric_attr :unfriendly    # We'll like people who hurt these
  numeric_attr :neutral
  numeric_attr :friendly      # We'll dislike people who hurt these
  numeric_attr :devoted
  
  numeric_attr :gullibility
  
  string_attr :name
  
  child :feelings
  
  def initialize
    super
    @shooting_mod = -10
    @killing_mod = -50
    @friendly_multiplier = 0.5
    @friendly_shots_threshold = 3
    
    @kill_on_sight = -1000
    @unfriendly = -500
    @neutral = 0
    @friendly = 500
    @devoted = 1000
    
    @gullibility = 0.8
    @name = nil
    @feelings = ArraySet.new
    @feelings << KuiRelation.new(self, FANATIC_DEVOTION)
  end

  # Rat out the person who hurt us to everyone.
  def broadcast_feeling_change(org, adjustment)
    orgs = @rl.repository.everything_of_type(KuiOrg)
    orgs.each { |recipient| 
      recipient.receive_feeling_change(self,org, adjustment) }
  end

  def feelings_for(org)
    relation = relation_for(org)
    
    return relation.feeling
  end
  
  def index_for_attitude(org)
    attitude = feelings_for(org)
    index = case(attitude)
    when UTTER_LOATHING..@kill_on_sight then 0
    when @kill_on_sight..@unfriendly then 1
    when @unfriendly..@friendly then 2
    when @friendly..@devoted then 3
    else 4
    end
    return index  
  end
  
  # Someone did something bad, put it on their permanent record and tell
  # everyone else about it.
  def org_bad_things(org, mod)
    current = self.feelings_for(org)
    adjustment = mod
    if current > @friendly
      adjustment *= @friendly_multiplier
    end
    broadcast_feeling_change(org, adjustment)
  end
  
  # This is where I feel worse toward whoever did that
  def org_shot_me(org)
    org_bad_things(org,@shooting_mod)
  end
  
  # Forgive and forget, my ass!
  def org_killed_me(org)
    org_bad_things(org,@killing_mod)    
  end
  
  def playable?
    return false unless super
    return false unless @name
    return false unless (@kill_on_sight <= @unfriendly) &&
      (@unfriendly <= @neutral) && 
      (@neutral <= @friendly) &&
      (@friendly <= @devoted)
    return true
  end
 
  # Listen to our gossipy friends.
  def receive_feeling_change(fromOrg, aboutOrg, adjustment)
    return if fromOrg == aboutOrg # Don't listen to what other people say
    feeling_mult = 0
    feel_about_sender = self.feelings_for(fromOrg)
    feeling_mult = -1 if feel_about_sender <= @unfriendly
    feeling_mult = 1 if feel_about_sender >= @friendly
    belief = @gullibility
    if fromOrg == self
      belief = 1.0 # Trust ourselves implicitly.
    end
    
    relation = relation_for(aboutOrg)
    final_adjust = (belief * feeling_mult * adjustment)
    relation.feeling = relation.feeling + final_adjust
    relation.feeling = UTTER_LOATHING if relation.feeling < UTTER_LOATHING
    relation.feeling = FANATIC_DEVOTION if relation.feeling > FANATIC_DEVOTION
  end
  
  def relation_for(org)
    relation = @feelings.detect do | rel |
      rel.target_org == org
    end
    
    unless relation
      relation = KuiRelation.new
      relation.target_org = org
      relation.feeling = @neutral
      @feelings << relation
    end
    return relation
  end
  
  def symbol_for_attitude(org)
    return LEVEL_SYMBOLS[index_for_attitude(org)]
  end

end

class KuiPlanet < KuiObject
  string_attr :image_filename
  set_size_for :image_filename, [0,0]
  
  child :cargo_for_sale
  child :addons_for_sale
  child :weapons_for_sale
  child :ships_for_sale
  child :owner
  child :missions # Regular 'mission board' missions
  child :plot # 'Plot' missions that can ambush the player
  child :random_missions # The result of these generators will be in the
                         # mission board.
  string_attr :name
  string_attr :description  
  set_size_for :description, [5,40]
  
  numeric_attr :x, :y
  numeric_attr :landing_distance
  numeric_attr :fuel_cost
  
  def initialize
    super
    @image_filename = nil
    @x = 0
    @y = 0
    @fuel_cost = 1
    @landing_distance = 100
    @cargo_for_sale = ArraySet.new
    @addons_for_sale = ArraySet.new
    @weapons_for_sale = ArraySet.new
    @ships_for_sale = ArraySet.new
    @random_missions = []
    @owner = nil
    @missions = []
    @plot = []
  end
  
  def playable?
    return false unless super
    return false unless @image_filename
    return false unless ResourceLocator::instance.image_for(@image_filename)
    # Planets with 0 landing distance are still playable; they're just
    # decoration.
    return true
  end
  
  # Position as an ftor
  def pos
    return Rubygame::Ftor.new(@x,@y)
  end
end

class KuiPlayer < KuiObject
  child :start_sector, :start_ship
  child :org
  child :missions
  child :completed_missions
  child :flags
  
  # This is used for missions to determine if the player is on this planet.
  # It's saved in case I want to use it later (i.e. save/resume from planetside)
  child :on_planet
  
  string_attr :name
  
  numeric_attr :credits
  
  def initialize
    super
    @missions= []
    @completed_missions = []
    @flags = []
    @on_planet = nil
    @credits = 0
    @name = nil
    @start_ship = nil
    self.tag="player"
  end
  
  def add_mission(mission)
    @missions << mission
  end
  
  def add_flag(flag)
    @flags << flag unless flag_for(flag.tag)
  end
  
  # Buys a ship.  Credits us with the tradein value
  # and transfers mission-related cargo over.
  def buy_ship(other)
    @credits -= (other.price -  @start_ship.tradein)
    @start_ship.mission_cargo.each do | cargo |
      other.add_cargo(cargo, cargo.amount)
    end
    @start_ship = other.dup
  end
  
  # Mostly compares credits and can_transfer_to?
  def can_buy_ship?(other)
    return false unless @credits >= (other.price - @start_ship.tradein)
    return @start_ship.can_transfer_to?(other)
  end
  
  # Easier to get to flags this way, especially if I transition to a Hash
  def flag_for(tag)
    return @flags.detect { |flag| flag.tag == tag}
  end
  
  # Returns false if the player never had the mission, and the exit code
  # of the mission if they did
  def had_mission?(mission)
    names = @completed_missions.collect { |c| c.name }
    detected = @completed_missions.detect{ |m| m === mission }
    if detected
      return detected.exit_code
    end
    return false
  end
  
  def has_mission?(mission)
    return @missions.detect{ |m| m == mission }
  end

  def playable?
    # We're not calling super here because the player doesn't need a tag.
    return false unless @start_sector && @start_sector.playable?
    return false unless @start_ship && @start_ship.playable?
    return false unless @org && @org.playable?
    return @credits != 0 # Either reward or penalize
  end
  
  def remove_mission(mission,exit_code=0)
    done = @missions.delete(mission)
    if done && exit_code
      if  exit_code != 0  || mission.globally_unique
        # TODO: Replace the exit code of this mission if, for example, we failed
        #       it before.
        done.exit_code = exit_code
        @completed_missions << done
          
      end
    end
  end
  
  def unset_flag(flag_tag)
    @flags.delete_if { |flag| flag.tag == flag_tag }
  end
  
  # By default, the player has no name.  This is one of the ways that the
  # engine detects that we're starting up a new game rather than loading one.
  def unnamed?
    return @name == nil || @name.size == 0
  end
  
  def visit(sector)
    sector.visited = true
  end
  
end

# Explains how we feel toward another org
class KuiRelation < KuiObject
  
  child :target_org
  numeric_attr :feeling
  
  def initialize(target = nil, feelings = 0)
    super()
    @target_org = nil
    @feeling = feelings
    @target_org = target
    @tag = nil # We explicitly have no tag
  end
  
  # Need a different comparator, since we don't use tags
  def ==(other)
    return false unless other
    return @target_org == other.target_org && @feeling == other.feeling    
  end
  
  def playable?
    # Not calling super because relations aren't important enough to have a tag
    return @target_org != null && @target_org.playable?
  end
  
end


class KuiSector < KuiObject
  JUMPIN_DISTANCE = 300
  
  child :links_to, :planets
  
  # Potential fleets are those that can be spawned, active fleets are those that
  # have already been.
  child :potential_fleets, :active_fleets
  
  # These are fleets that have been destroyed - they will only be recorded here
  # if the KuiSpawnAction that created them is flagged to do so.  They remain
  # until removed by a KuiDespawnAction
  child :killed_fleets
  
  # KuiWeapons en route to destruction
  child :projectiles
  
  # Highlights for this sector
  child :halos
  
  # Plot missions this sector can grant
  child :plot
  
  numeric_attr :x, :y
  string_attr :name
  string_attr :description
  set_size_for :description, [5,40]
  
  boolean_attr :visited
  
  def initialize
    super
    @name = 'New Sector'
    @description = ''
    @x = 0
    @y = 0
    @links_to = ArraySet.new
    @planets = []
    @projectiles = []
    
    @potential_fleets = []
    @active_fleets = []
    @killed_fleets = []
    @halos = []
    @plot = []
    @visited = false
  end
  
  def all_ships
    ships = @active_fleets.collect { |f| f.ships }
    ships.flatten!
    player_ship = ResourceLocator.instance.repository.universe.player.start_ship
    ships << player_ship unless player_ship.phased
    return ships
  end
  
  def delete_planet(planet)
    @planets.delete(planet)
  end
  
  def links_to?(sector)
    return @links_to.include?(sector)
  end
  
  def playable?
    return false unless super
    @planets.each { |planet| return false unless planet.playable? }
    return false unless @name
    return false unless @name.size > 0
    return false unless @description
    return true
  end
end

class KuiUniverse < KuiObject
  child :map
  child :player
  
  string_attr :name
  string_attr :description
  boolean_attr :save_as_dev
  
  set_size_for :description , [5,40]
  
  def initialize
    super
    @map = KuiMap.new
    @map.tag = "map"
    @player = KuiPlayer.new
    @player.tag="player"
    @save_as_dev = false
  end
  
  def playable?
    # Not calling super here because the universe doesn't need a tag
    return false unless @map.playable?
    return false unless @player.playable?
    return true
  end
end

# Include items we refactored out
require 'kuispaceworthy'
require 'kuimission'