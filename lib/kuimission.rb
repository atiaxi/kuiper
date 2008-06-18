# Missions themselves and mission related objects

require 'kuiobject'

# This module handles going through a list of conditions
# and/or actions and collecting their values.  It is intended for use inside
# ifThens and missions themselves.
module ConditionActionHandler
  
  # Tries to evaluate this list of KuiConditions or KuiActions.
  # Returns false immediately if it reaches something that evaluates to false.
  # If anything requires user response, returns a [ condition, continuation ]
  # pair; the continuation is to be called once the condition has been resolved.
  def handle_series(anArray, mission=nil)
    result = true
    anArray.each do | obj |
      changeable = obj.dup
      if changeable.respond_to?(:perform)
        selector = :perform
      else
        selector = :value
      end
      changeable.mission = mission
      result = changeable.send(selector)
      while result == nil
        callcc do |cont|
          return [ changeable, cont ]
        end
        # When we get back here, condition.value should be true/false
        result = changeable.send(selector)
        obj.shown = true if obj.respond_to?(:shown=)
      end
      return false unless result
    end
    return true
  end
  
end

module Resolvable
  
  def resolve(val)
    @value = val
  end
  
  def setup_resolvable
    @value = nil
  end
  
  def value
    return @value
  end
  
end

# Parent class of all actions
class KuiAction < KuiObject
  
  # To some actions, it matters what mission this is.
  # To most, it doesn't.  To avoid passing mission in as
  # a child (where it ties something which could be more general to one
  # specific mission) or an argument to perform (where it's wasted on all the
  # other actions), this accessor is in place.
  attr_accessor :mission
  
  def initialize
    @mission = nil
    super
  end

  # Performs this action.  This returns either true, indicating that the action
  # completed successfully, or nil, meaning it requires user input
  def perform
    
  end
  
  def player
    return @rl.repository.universe.player
  end
  
end

# Parent class of all conditions
class KuiCondition < KuiObject
  
  # See KuiAction for the use of this
  attr_accessor :mission
  
  def initialize
    super
    @mission = nil
  end
  
  def player
    return @rl.repository.universe.player
  end
  
  # Whether this condition is met.  Returns true, false, or nil.
  # This last indicates that user interaction is necessary.
  def value
    return false
  end
  
end

class KuiIfThen < KuiObject
  
  child :ifs
  child :thens
  
  include ConditionActionHandler
  
  def initialize
    super
    @ifs = []
    @thens = []
  end
  
  # Tries to evaluate this IfThen. 
  # This returns false immediately if any condition is not met.  If a condition
  # requires user input, a [ condition, continuation] pair will be returned.
  # The continuation is to be called once the condition is displayed and
  # resolved.  Actions requiring output will similarly return [ action,
  # continuation].  Finally, if all conditions were met and all action taken,
  # this will return true.
  def evaluate(mission=nil)
    ifs_result = self.handle_series(@ifs,mission)
    return ifs_result if ifs_result.respond_to?(:each)
    if ifs_result
      # Ifs have been met, do thens.
      return self.handle_series(@thens, mission)
    end
    return false
  end
    
  # Blank list of ifs are always true, blank thens do nothing
  def playable?
    return super
  end
  
  def synopsis
    ifstrings = @ifs.collect { |i| i.synopsis }
    thenstrings = @thens.collect { |t| t.synopsis }
    
    ands = ifstrings.join(" AND ")
    results = thenstrings.join(", ")
    return "IF #{ands} THEN #{results}"
    
  end
  
end

class KuiMission < KuiObject
  
  # The organization(s) behind this mission, if any
  child :sponsors
  
  child :worthy # Conditions that cause this mission to appear.  Note that
                # conditions here which require input are silenty dropped if
                # this is a non-plot mission.
  child :setup # Actions to take upon giving mission to player
  child :checks # IfThens which will be checked at every opportunity
  
  string_attr :name
  string_attr :description
  set_size_for :description, [5,40]
  
  # The exit code is similar to a unix exit code.  A mission that completed
  # with nothing of note should use zero here, as they will not be recorded on
  # the player's record.  A '0' implies a non-noteworthy ending, '1' success, a 
  #'-1' failure, and everything else is scenario-defined.
  numeric_attr :exit_code
  
  boolean_attr :unique # You can only have one of a specific unique mission
                       # at a time.
  # Globally unique missions can only be had once, ever. 
  boolean_attr :globally_unique
  
  # When a KuiSpawnAction takes place, it can specify that its fleets are to be
  # watched for destruction.  If a watched fleet is destroyed (whether by player
  # action or not), it is recorded in :fleets_that_died
  child :fleets_to_die
  child :fleets_that_died
                       
  include ConditionActionHandler
  
  def initialize
    super
    @sponsors = []
    @worthy = []
    @setup = []
    @checks = []
    @fleets_to_die = []
    @fleets_that_died = []
    @unique = true
    @description = ''
    @exit_code = 0
  end

  # Gives this mission to the player.  Returns true if everything is fine,
  # or a [ action, continuation ] pair if a user response is required.
  def award
    player = @rl.repository.universe.player
    
    result = handle_series(@setup,self)
    return result unless result == true
    
    player.add_mission(self)
    return true
  end
  
  # Returns true, false, or a [ condition/action, continuation ] pair
  # See ConditionActionHandler for more information.
  def awardable?
    player = @rl.repository.universe.player
    return false if player.has_mission?(self) && (@unique || @globally_unique)
    return false if @globally_unique && player.completed_missions.include?(self)
    return handle_series(@worthy, self)
  end
  
  # Called at certain points to check on mission completion.
  # Returns true if all conditions were checked (regardless of their specific
  # result), and a [ action/condition, continuation ] pair if user response is
  # needed.
  def check
    @checks.each do |ifthen|
      result = ifthen.evaluate(self)
      
      return result if result.respond_to?(:each)
    end
    return true
  end
  
  def playable?
    return false unless super
    return false unless @name
    return false if @sponsors.detect { | s | !s.playable? }
    return false if @worthy.detect { |w| !w.playable? }
    return false if @setup.detect { |a| !a.playable? }
    return false if @checks.detect { |c| !c.playable? }
    return true
  end
  
  def synopsis
    return @name if @name 
    return @tag
  end
  
end

# ACTIONS

class KuiAwardRemoveCargoAction < KuiAction
  child :cargo
  numeric_attr :amount
  boolean_attr :award # MUST SET THIS TO FALSE IF REMOVING!
                      # Using negative amounts will FAIL HORRIBLY!
  
  # Keep in mind that this can also be used to award cargo as a reward;
  # if you want the cargo to be marked mission-related, you'll have to do it
  # yourself
  def initialize(aCargo=nil, amt = 1,give=true)
    super()
    @cargo = aCargo
    @award = give
    @amount = amt
  end
  
  def perform
    ship = player.start_ship
    if @cargo
      if @award
        ship.add_cargo(@cargo, @amount)
      else
        ship.remove_cargo(@cargo, @amount)
      end
    end
    return true
  end
  
  def playable?
    return false unless super
    return false unless @cargo && @cargo.playable?
    return false unless @amount >= 0
    return true
  end
end

class KuiDescriptionAction < KuiAction
  child :target
  string_attr :new_description
  set_size_for :new_description, [5,40]
  
  def initialize(desc= nil)
    super()
    @target = nil
    @new_description = desc
  end
  
  def perform
    if @target
      @target.description = @new_description
    end
    return true
  end
  
end

class KuiEndAction < KuiAction
  numeric_attr :exit_code
  
  def initialize(code = 0)
    super()
    @exit_code = code
  end
  
  def perform
    if @mission
      player.remove_mission(@mission,@exit_code)
      @mission.fleets_to_die = []
      @mission.fleets_that_died = []
    end
    return true
  end
  
end

# First, if unset is true, this action will remove the given flag.  If not,
# it looks up flag_tag and sets /both/ number and note to new_number and
# new_note.  This will create the flag if none exists.
class KuiFlagAction < KuiAction
  numeric_attr :new_number
  string_attr :new_note
  
  # Again, not a child because we may want to update a flag; if this was a child
  # it could only ever refer to the existing flag.
  string_attr :flag_tag
  
  # Set to true, this will remove the flag altogether
  boolean_attr :unset
  
  def initialize(flag = nil)
    super()
    @flag_tag = flag
    @unset = false
  end
  
  def perform
    if @unset
      player.unset_flag(@flag_tag)
    else
      # TODO: If I end up needing to use this more than once, I can probably
      #       refactor it into KuiPlayer::add_flag
      old_flag = player.flag_for(@flag_tag)
      unless old_flag
        old_flag = @rl.repository.everything[@flag_tag]
        unless old_flag
          old_flag = KuiFlag.new
          old_flag.tag = @flag_tag
        end
        player.add_flag(old_flag)
      end
      old_flag.value = @new_number
      old_flag.note = @new_note
    end
    return true
  end
  
  def playable?
    return false unless super
    return @flag_tag != nil
  end
end

class KuiHaloAction < KuiAction
  child :halo
  child :sectors
  
  def initialize(aHalo = nil)
    @halo = aHalo
    @sectors = []
    super()
  end
  
  def perform
    @sectors.each do | sector |
      sector.halos << @halo
    end
    return true
  end
  
  def playable?
    return false unless super
    return false unless @halo && @halo.playable?
    return false unless @sectors.size > 0
    return true
  end
end

class KuiInfoAction < KuiAction
  
  string_attr :message
  set_size_for :message, [5, 40]
  
  boolean_attr :show_once_only
  boolean_attr :shown
  
  include Resolvable
  
  def initialize(message = nil)
    super()
    @message = message
    @show_once_only = false
    @shown = false
  end
  
  
  def perform
    return true if @show_once_only && @shown
    return self.value
  end
  
  def playable?
    return false unless super
    return @message != nil
  end
  
end

class KuiMoneyAction < KuiAction
  
  numeric_attr :amount

  def initialize(amt = 0)
    super()
    @amount = amt
  end
  
  def perform
    player.credits += @amount
    return true
  end
  
  # Nothing special for playability
end

class KuiDespawnAction < KuiAction
  
  child :spawner
  child :fleets
  child :locations
  
  def initialize
    super
    @fleets = []
    @locations = []
  end
  
  def perform
    # First undo what the given spawner did
    if @spawner
      @spawner.locations.each do | location |
        location.potential_fleets -= @spawner.fleets
        location.killed_fleets -= @spawner.fleets
      end
    end
    # Then de-spawn our own things
    @locations.each do |location|
      location.potential_fleets -= @fleets
      location.killed_fleets -= @fleets
    end
  end
  
  def playable?
    return false unless super
    return true
  end
  
end

# Start selling the given weapon(s) at the given location(s)
# This is a one-time deal; if (for example) the weapon is sold at all an org's
# planets, and another planet converts to that org, it won't get this weapon
class KuiSellItemsAction < KuiAction
  
  child :locations
  child :orgs
  
  child :weapons
  child :cargo
  child :addons
  child :ships
  
  def initialize
    super
    @locations = []
    @orgs = []
    @weapons = []
    @cargo = []
    @addons = []
    @ships = []
  end
  
  def perform
    locs = @locations.dup
    
    planets = @rl.repository.everything_of_type(KuiPlanet)
    interested = planets.select do | planet |
      @orgs.include?(planet.owner)
    end
    (locs + interested).each do | planet |
      planet.cargo_for_sale += @cargo
      planet.addons_for_sale += @addons
      planet.weapons_for_sale += @weapons
      planet.ships_for_sale += @ships
    end
    
    return true
  end
  
end

class KuiSpawnAction < KuiAction
  
  child :fleets
  child :locations
  
  boolean_attr :watch_for_destruction
  
  def initialize
    super
    @fleets = []
    @locations = []
    @spawn = true
  end
  
  def perform
    @locations.each do |location|
      location.potential_fleets += @fleets
    end
    if @watch_for_destruction
      if @mission
        @mission.fleets_to_die += @fleets
      else 
        @rl.logger.warn("#{self} is watching its fleets with no mission!")
      end
    end
    
    return true
  end
  
  def playable?
    return false unless super
    return true
  end
  
end

class KuiUnhaloAction < KuiAction
  child :haloer
  
  def initialize(aKuiHaloAction = nil)
    super()
    @haloer = aKuiHaloAction
  end
  
  def perform
    if @haloer
      @haloer.sectors.each do | sector |
        sector.halos.delete(@haloer.halo)
      end
    end
    return true
  end
  
  def playable?
    return false unless super
    return false unless @haloer && @haloer.playable?
    return true
  end
  
end

# CONDITIONS
class KuiAtCondition < KuiCondition
  
  # These can be sectors, planets, or organizations
  # (If the latter, they apply to any planet owned by
  #  any of the organizations), or a mix of the three.
  # If the player is at any of them, this is true.
  child :locations
  
  def initialize
    super
    @locations = []
  end
  
  def playable?
    return false unless @locations
    return false if @locations.detect { |l| !l.playable? }
    return @locations.size > 0
  end
  
  def value
    sector = player.start_sector
    result = @locations.include?(sector)

    return true if result
    if player.on_planet
      return true if @locations.include?(player.on_planet)
      return true if @locations.include?(player.on_planet.owner)
    end
    return false
  end
  
end

class KuiCargoFreeCondition < KuiCondition
  
  numeric_attr :minimum
  
  def initialize(min = 1)
    super()
    @minimum = min
  end
  
  def value
    ship = @rl.repository.universe.player.start_ship
    return ship.available_cargo >= @minimum
  end
  
  def playable?
    return false unless super
    return @minimum >= 0
  end
  
  def synopsis
    return "Player has #{@minimum} cargo space free"
  end
  
end

# Whether or not the given mission was completed.
# If exit_code here is a non-zero value, will check to see that the mission was
# completed with that exit code
class KuiCompletedCondition < KuiCondition
  child :completed
  numeric_attr :exit_code
  
  def initialize(code = 0)
    super()
    @completed = nil
    @exit_code = code
  end
  
  def playable?
    return false unless super
    return @completed && @completed.playable?
  end
  
  def value
    code = player.had_mission?(@completed)
    if @exit_code != 0
      return code == @exit_code
    end
    return code != false && code != nil
  end
  
end

# Whether or not the given fleet has been destroyed.  In order for this to work
# properly, the KuiSpawnAction has to indicate that its fleets were to be
# watched for destruction. (And only fleets spawned by that action can be
# tracked with this condition)  Like KuiDespawnAction, this can also use the
# KuiSpawnAction itself.
class KuiDestroyedCondition < KuiCondition
  
  child :fleets
  child :spawner
  
  def initialize
    @fleets = []
    @spawner = nil
    super
  end
  
  def value
    if @mission
      fleets_alive = @fleets.detect do |fleet|
        !@mission.fleets_that_died.include?(fleet)
      end
      spawns_alive = false
      if @spawner
        spawns_alive = @spawner.fleets.detect do | fleet |
          !@mission.fleets_that_died.include?(fleet)
        end
      end
      return !(fleets_alive || spawns_alive)
    end
    return false
  end
  
  # Nothing special for playable
  
end

# This evaluates to true immediately if is_set is true and the flag is set.
# Secondly, it will look at is_not_set and, if that is true, return true if
# the flag in question is not set.
# After this point, if the flag is not set, it will return false.  Otherwise
# tt will check number_is and note_is, and return true if either match.
class KuiFlagCondition < KuiCondition
  
  numeric_attr :number_is
  string_attr :note_is
  
  # This is not a child because we may want to check for the /absense/
  # of a tag being set, in which case it may not exist.
  string_attr :flag_tag
  boolean_attr :is_set
  boolean_attr :is_not_set

  def initialize(flag=nil)
    super()
    @flag_tag = flag
    @is_set = false
    @is_not_set = false
  end
  
  def value
    flag = player.flag_for(@flag_tag)
    
    return true if flag && @is_set
    return true if flag == nil && @is_not_set
    
    return false unless flag
    number_result = flag.value == @number_is
    note_result = flag.value == @note_is
    return number_result || note_result
  end
  
  def playable?
    return false unless super
    return @flag_tag != nil
  end
end

class KuiYesNoCondition < KuiCondition
  
  string_attr :message
  set_size_for :message, [5, 40]
  
  boolean_attr :expected_response
  boolean_attr :ask_once_only
  # If the question has been asked before, and is only to be asked once, what
  # answer should be used as the default?
  boolean_attr :default_answer
  boolean_attr :shown
  
  include Resolvable
  
  def initialize(message = nil)
    super()
    @message = message
    @expected_response = true
    @ask_once_only = false
    @default_answer = false
    @shown = false
  end
  
  def value
    return @default_answer if @show_once_only && @shown
    return super
  end
  
  def playable?
    return false unless super
    return @message != nil
  end
  
end

require 'kuirandommission'