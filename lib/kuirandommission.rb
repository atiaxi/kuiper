class KuiMissionGenerator < KuiObject
  
  numeric_attr :min_generate
  numeric_attr :max_generate
  
  numeric_attr :min_reward
  numeric_attr :max_reward
  
  child :template
  
  # We can set additional ending conditions via the template's 'checks' child,
  # but we can't dole out additional awards or undo the setup items.  The items
  # in cleanup will be appended to the 'thens' child of the IfThen that checks
  # for mission completion.
  child :cleanup
  
  def initialize
    super
    @min_generate = 1
    @max_generate = 1
    @min_reward = 1000
    @max_reward = 1000
    @template = nil
    @cleanup = []
    @rl = Opal::ResourceLocator.instance
  end
  
  def award_action
    money = (@min_reward..@max_reward).random
    giveMoney = KuiMoneyAction.new(money)
    giveMoney.tag = unique_tag("random_kma")
    return giveMoney
  end
  
  def end_actions(exit_code = 0)
    endMission = KuiEndAction.new
    endMission.tag = unique_tag("random_end")
    endMission.exit_code = exit_code
    return [endMission] + @cleanup
  end
  
  def mission
    result = @template.dup
    tag = unique_tag('random_mission')
    result.tag = tag
    return result
  end
  
  # Returns between min_generate and max_generate missions.
  # source is a KuiPlanet or a KuiSector, and indicates where this mission is
  # being generated
  def generate(source=nil)
    result = []
    num = (@min_generate..@max_generate).random.to_i
    num.times { result << self.generate_one(source) }
    return result
  end
  
  # Returns one randomly generated mission.  Should be overridden by subclasses
  # which will generate one mission of their kind.
  # source is a KuiPlanet or a KuiSector, and indicates where this mission is
  # being generated
  def generate_one(source=nil)
    raise NotImplementedError.new
      ("A subclass should have overridden generate_one")
  end
  
  def playable?
    return false unless super
    return false unless template && template.playable?
    return false unless @min_generate <= @max_generate
    return false unless @min_generate >= 0
    return false unless @max_generate > 0
    return true
  end
  
  def substitute_tokens(string)
    result = string.dup
    self.token_map.each do |key,symbol|
      value = self.send(symbol)
      result.gsub!("%#{key}%",value.to_s)
    end
    return result
  end
  
  # Takes all the text content for the given mission, and substitutes in our
  # tokens.
  def substitute_tokens_for(mission)
    # Final template changes
    mission.name = substitute_tokens(mission.name)
    mission.description = substitute_tokens(mission.description)
  end
  
  def token_map
    return {}
  end
  
  # Shortcut for Repository::ensure_unique_tag, but uses '/' as its separator.
  def unique_tag(original)
    return @rl.repository.ensure_unique_tag(original,"/")
  end
  
end

# Generators
module RandomCargo
  
  # Implementors should do the following:
#  numeric_attr :min_amount
#  numeric_attr :max_amount  
#  child :cargo
  
  attr_accessor :amount
  attr_accessor :cargo_picked
  
  def setup_random_cargo
    @min_amount = 1
    @max_amount = 10
    
    @cargo = []
  end
  
  def award_cargo_action(picked)
    award = KuiAwardRemoveCargoAction.new(picked, @amount)
    award.tag = unique_tag("random_karca")
    return award
  end
  
  def remove_cargo_action(picked)
    remove = KuiAwardRemoveCargoAction.new(picked, amount,false)
    remove.tag = unique_tag("random_karca")
    return remove
  end
  
  def sufficient_room_condition
    @amount ||= (@min_amount..@max_amount).random.to_i
    free = KuiCargoFreeCondition.new(@amount)
    free.tag = unique_tag("random_kcfc")
    return free
  end
  
  def pick_cargo
    picked = @cargo.random.dup
    @cargo_picked = picked.blueprint.name
    picked.mission_related = true # In case it isn't already
    return picked
  end
  
  def random_cargo_playable?
    return false unless @min_amount > 0
    return false unless @max_amount >= @min_amount
    return false unless @cargo.size > 0
    return true
  end
  
  def random_cargo_tokens
    return { 'AMOUNT' => :amount,
      'CARGO' => :cargo_picked }
  end
  
end

module RandomDestination
  
  attr_accessor :destination
  
  # I don't have the metaclass magic on the module side to make declaring
  # a 'child' here make any sense.  So I'm just noting in a comment:
  
  # Implementors should do the following:
  #child :destinations 
  #labelable_attr :destinations_labels
  
  def arrived_check_for(location)
    arrived = KuiIfThen.new
    arrived.tag = unique_tag("are_we_there_yet?")
    
    atThere = KuiAtCondition.new
    atThere.tag = unique_tag("random_kac")
    atThere.locations << location
    arrived.ifs << atThere
    
    return arrived
  end
  
  def pick_destination
    there = nil
    if @destinations.size > 0
      there = @destinations.random
    else
      dests = @rl.repository.everything_with_labels(@destinations_labels_array)
      dests.reject! {|dest| !(dest.class == KuiSector ||
                              dest.class == KuiPlanet)}
      there = dests.to_a.random
    end
    @destination = there.name
    return there
  end
  
  def random_destination_playable?
    return false unless @destinations.size > 0 || 
      @destinations_labels_array.size >0
    return true
  end
  
  def random_destination_tokens
    return { 'DESTINATION' => :destination }
  end
  
  def setup_random_destination
    @destinations = []
    @destinations_labels_array = []
  end
  
end


class KuiRandomCargo < KuiMissionGenerator
  
  include RandomCargo
  numeric_attr :min_amount
  numeric_attr :max_amount  
  child :cargo
  
  include RandomDestination
  child :destinations
  labelable_attr :destinations_labels
  
  def initialize
    super
    @destinations_labels = []
    setup_random_cargo
    setup_random_destination
  end
  
  def generate_one(source=nil)
    m = self.mission
    
    # First, the condition that they have enough cargo
    @amount = nil # So sufficient_room_condition will pick a new amount
    free = sufficient_room_condition
    m.worthy << free
    
    picked = pick_cargo
    
    # Award it
    award = award_cargo_action(picked)
    m.setup << award
    
    # Are we there yet?
    there = pick_destination
    arrived = arrived_check_for(there)
    
    # Take away that cargo what we gave
    remove = remove_cargo_action(picked)
    arrived.thens << remove
    
    # Give them their filthy money
    arrived.thens << award_action
      
    # End it all!
    arrived.thens += end_actions
    
    m.checks << arrived
    substitute_tokens_for(m)
    
    return m
  end
  
  def playable?
    return false unless super
    return false unless random_cargo_playable?
    return false unless random_destination_playable?
    return true
  end
  
  def token_map
    cargos = random_cargo_tokens
    return cargos.merge(random_destination_tokens)
  end
end

class KuiRandomScout < KuiMissionGenerator
  
  include RandomDestination
  child :destinations
  labelable_attr :destinations_labels
  
  def initialize
    super
    setup_random_destination
  end
  
  def generate_one(source=nil)
    m = self.mission
    
    there = pick_destination
    arrived = arrived_check_for(there)
    arrived.thens << award_action
    arrived.thens += end_actions
    
    m.checks << arrived
    
    substitute_tokens_for(m)
    return m    
  end
  
  def token_map
    return random_destination_tokens
  end
  
  def playable?
    return false unless super
    return false unless random_destination_playable?
    return true
  end
  
end

class KuiRandomFetch < KuiMissionGenerator

  include RandomCargo
  numeric_attr :min_amount
  numeric_attr :max_amount  
  child :cargo
  
  include RandomDestination
  child :destinations
  labelable_attr :destinations_labels
  
  def initialize
    super
    setup_random_cargo
    setup_random_destination
  end
  
  def generate_one(source)
    m = self.mission
    
    # Phase I: From source to destination
    there = pick_destination
    arrived = arrived_check_for(there)
    # Give cargo once there, if room
    arrived.ifs << sufficient_room_condition
    
    picked = pick_cargo
    award = award_cargo_action(picked)
    arrived.thens << award
    # Set the mission flag
    
    flag_tag =unique_tag(self.base_tag('/')+"_flag")
    flag = KuiFlagAction.new(flag_tag)
    flag.new_number=1
    arrived.thens << flag
    
    m.checks << arrived
    
    # Phase II: From destination to source
    back = arrived_check_for(source)
    # Make sure they actually picked up cargo
    flagSet = KuiFlagCondition.new(flag_tag)
    back.ifs << flagSet
    
    # Un-set the flag
    flag = KuiFlagAction.new(flag_tag)
    flag.unset = true
    back.thens << flag
    # Un-load the cargo
    back.thens << remove_cargo_action(picked)
    # Re-ward the money
    back.thens << award_action
    # En-d the mission
    back.thens += end_actions
    
    m.checks << back
    substitute_tokens_for(m)
    
    return m
  end
  
  def playable?
    return false unless super
    return false unless random_cargo_playable?
    return false unless random_destination_playable?
    return true
  end

  def token_map
    cargos = random_cargo_tokens
    return cargos.merge(random_destination_tokens)
  end
  
end

class KuiRandomBounty < KuiMissionGenerator
  
  include RandomDestination
  child :destinations
  labelable_attr :destinations_labels
  
  child :fleets
  
  attr_accessor :fleet
  
  def initialize
    super
    @fleets = []
    setup_random_destination
  end
  
  def generate_one(source=nil)
    m = self.mission
    
    there = pick_destination
    
    chosen_fleet = @fleets.random
    @fleet = chosen_fleet.name
    if @fleet == nil
      if chosen_fleet.ships.size > 0
        @fleet = chosen_fleet.ships[0].name
      else
        @fleet = "an empty fleet"
      end
    end
    
    spawn = KuiSpawnAction.new
    spawn.locations << there
    spawn.fleets << chosen_fleet
    spawn.watch_for_destruction = true
    m.setup << spawn
    
    finished = KuiIfThen.new
    finished.tag = unique_tag("crushed_our_enemies?")
    
    destroyed = KuiDestroyedCondition.new
    destroyed.spawner = spawn
    finished.ifs << destroyed
    
    despawn = KuiDespawnAction.new
    despawn.tag = unique_tag("random_kda")
    despawn.spawner = spawn
    finished.thens << despawn
    finished.thens << award_action
    finished.thens += end_actions
    
    m.checks << finished
    substitute_tokens_for(m)
    
    return m
  end
  
  def playable?
    return false unless super
    return false unless random_destination_playable?
    return false unless @fleets.size >= 1
    return true
  end
  
  def token_map
    fleet_name = { 'FLEET' => :fleet }
    return fleet_name.merge(random_destination_tokens)
  end
  
end