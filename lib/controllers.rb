require 'engine'
require 'set'

# This class' job is to:
#   - Be able to address the controls by name
#   - Keep track of which are active
class ControlsHolder
  
  def initialize(controls)
    @controls = controls
    @name_to_control = {}
    @active = {}
    reset
  end
  
  def [](sym)
    return @name_to_control[sym]
  end
  
  def active?(sym)
    return @active[sym]
  end
  
  def interpret(event)
    @controls.each do | control |
      if control === event
        @active[control.to_sym] = true
      elsif control.canceled_by?(event)
        @active[control.to_sym] = false
      else
        # Debugging code used to go here.  One day it may again.
      end
    end
  end
  
  def reset
    @controls.each do | control |
      @name_to_control[control.to_sym] = control
      @active[control.to_sym] = false
    end
  end
end

# Code from "AI For Game Developers" pp 22-23
# TODO: Put the following in credits:
# AI For Game Developers, by David M. Bourg and Glenn Seemann.  Copyright
# 2004 O'ReillyMedia, Inc, 0-596-00555-5
class Aimer
  
  attr_accessor :accel_angle_threshold # Default 45 degrees
  
  def initialize(model, waypoint)
    @model = model
    @waypoint = waypoint
    @accel_angle_threshold = 45.0
    
    ensure_nonzero_model
    reset
  end
  
  # Whether our model should accelerate or decelerate
  def accel
    result = 0
    thresh = @accel_angle_threshold
    angle = transformed_intercept.angle.to_degrees % 360
    result = -1  if angle < thresh || angle > (360-thresh)
    result = 1 if angle > (180-thresh)|| angle < (180+thresh)
    return result
  end

  def closing_range
    @closing_range ||= @waypoint.pos - @model.pos
    @closing_range
  end
  
  def closing_velocity
    @closing_velocity ||= waypoint_velocity - @model.velocity
    @closing_velocity
  end
  
  def ensure_nonzero_model
    @model.accelerate(0.000001) while @model.velocity.magnitude == 0
  end
  
  def intercept
    unless @intercept
      if closing_velocity.magnitude
        closing_time = closing_range.magnitude / closing_velocity.magnitude
      else
        closing_time = 0
      end
    
      future_position = @waypoint.pos + (waypoint_velocity * closing_time)
      @intercept = future_position - @model.pos
      @transformed_intercept = @intercept.dup
      @transformed_intercept.angle -= @model.facing.angle
      @transformed_intercept = @transformed_intercept.unit
    end
    return @intercept
  end

  def reset
    @closing_velocity = nil
    @closing_range = nil
    @intercept = nil
    @rotation = nil
    @accel = nil
  end
  
  # Whether our model should turn left or right to face
  def rotation
    result = 0
    tolerance = 0.05
    result = -1 if transformed_intercept.y < -tolerance
    result =  1 if transformed_intercept.y >  tolerance
    return result
  end
  
  def transformed_intercept
    intercept # Will set it for us
    return @transformed_intercept
  end
  
  def waypoint_velocity
    zero = Rubygame::Ftor.new(0,0)
    velocity = @waypoint.respond_to?(:velocity) ? @waypoint.velocity : zero
    return velocity
  end
  
end

class Aggro
  include Comparable
  
  attr_accessor :amount
  attr_accessor :toward # This is the ship model
  
  def initialize(ship, level)
    @toward = ship
    @amount = level
  end
  
  def <=>(other)
    return @amount <=> other.amount
  end
  
end

# This coordinates an entire AI fleet, mainly making sure they get
# the same waypoints
class FleetController
  
  AGGRO_REBUILD = 1.0 # seconds
  
  attr_reader :ai_controllers
  
  attr_reader :sector, :fleet
  attr_reader :most_hated
  
  attr_accessor :waypoint
  
  def initialize(fleet, sector_state)
    @fleet = fleet
    @sector = sector_state.sector
    @ai_controllers = []
    @aggro = {}
    @aggro_check_countdown = 0
    @waypoint = nil
    @fighting = false
    stay = rand(fleet.max_stay - fleet.min_stay) + fleet.min_stay
    @fleet.ships.each do | ship |
      aic =  AIController.new(ship,sector_state)
      aic.behavior = setup_behavior(ship,@fleet.behavior)
      aic.stay = stay
      aic.fleet = @fleet
      @ai_controllers << aic
    end
    @people_who_shot_me = {}
    @people_who_shot_me.default = 0
    @most_hated = nil
    @target = nil # Specific ship we're fighting against
  end
  
  def alive
    any = @ai_controllers.detect { |aic| aic.alive }
    return any != nil
  end
  
  def build_aggro_list
    @aggro_check_countdown = AGGRO_REBUILD
    allShips = @sector.all_ships
    allShips.each do | ship |
      unless get_aggro_for(ship)
        if owner
          initial = owner.feelings_for(ship.owner)
          @aggro[ship] = initial if initial
        end
      end
    end
    gen_most_hated
  end
  
  # Generates the @most_hated variable and caches it because figuring out who's
  # the most hated for some reason takes forever.
  # Also, it's like genX, but more hated.
  def gen_most_hated
    # This will find the greatest value stored in the dictionary
    hate,val = @aggro.min { | hate1, hate2 | hate1[1] <=> hate2[1] }
    @most_hated = hate
  end
  
  def get_aggro_for(ship)
    return @aggro[ship]
  end
  
  # Used to coordinate retaliation; doesn't blab to other organizations (that's
  # handled in the model code)
  def hit_by(other)
    culprit = other.owner
    @people_who_shot_me[culprit] += 1
    
    if owner
      # How do we feel about these people?
      if owner.feelings_for(culprit) >= owner.friendly
        if @people_who_shot_me[culprit] <= owner.friendly_shots_threshold
          return
        end
      end
    
      aggro = get_aggro_for(other.shooter)
      if aggro
        if aggro < owner.kill_on_sight
          aggro = owner.kill_on_sight
        else
          aggro -= other.damage
        end
        gen_most_hated
      else
        build_aggro_list
        aggro = get_aggro_for(other.shooter)
        @aggro[other.shooter] = owner.kill_on_sight
      end
    end
    
  end
  
  def owner
    if @ai_controllers[0]
      return @ai_controllers[0].model.owner
    else
      return nil
    end
  end
  
  def setup_behavior(ship,behavior)
    case behavior
      when :patrol
        return PatrolBehavior.new(ship,self)
      when :trade
        return TradeBehavior.new(ship, self)
      when :scan
        return ScannerBehavior.new(ship,self)
      else
        return CrazyBehavior.new(ship)
    end
  end

  def start_fighting_with(who)
    # What's our action here?
    if @ai_controllers[0] && @ai_controllers[0].leaving
      stop_fighting
    else
      if @fleet.under_attack == :flee
        @ai_controllers.each { |aic| aic.flee }
      elsif @fleet.under_attack == :fight
        @fighting = true
        @target = who
        @ai_controllers.each { |aic| aic.fight(who, self) }
        @target.add_observer(self)
      end
    end
  end
  
  # Re-sets the ai controller behavior to its default.
  # Removes us as an observer of the target, if any.
  def stop_fighting
    @fighting = false
    @ai_controllers.each do | aic |
      aic.behavior = setup_behavior(aic.model,@fleet.behavior)
    end
    @target.delete_observer(self) if @target
  end
  
  def update(*args)
    if args.size == 1
      update_fleet(args[0])
    else
      # It's an update from a ship
      who, action = args
      if action == :gone
        @target = nil
        @aggro.delete(who)
        @people_who_shot_me.delete(who)
        stop_fighting # Removes us as observer
      end
    end
  end
    
  def update_fleet(delay)
    # Don't bother with aggro if we're on the way out.
    unless @ai_controllers[0] && @ai_controllers[0].leaving
      if (@aggro.size == 0 ||
          @aggro_check_countdown <= 0) 
        build_aggro_list
        next_target = most_hated
        #ResourceLocator.instance.logger.debug("#{@fleet.tag}: Next target is: #{next_target.tag}")
        if next_target && @aggro[next_target] <= owner.kill_on_sight
          start_fighting_with(next_target)
        elsif @fighting
          # No targets we hate enough to fight, resume our duties
          stop_fighting
        end
      end
    end
    
    @ai_controllers.each do | aic |
      aic.update(delay)
      aic.kill unless aic.model.alive
    end
    
    @aggro_check_countdown -= delay
  end
  
end

# This, as you may suspect, is the Controller part of the MVC.  Like the
# TranslatableSprite, it requires a model.
class ShipController
  
  attr_accessor :model
  attr_accessor :alive
  attr_accessor :fire_delay # Time until we can shoot primaries again
  
  SECS_BETWEEN_PRIMARY_FIRINGS = 0.3
  
  def initialize(model, sector_state)
    @rl = ResourceLocator::instance
    @model = model
    @alive = true
    @sector_state = sector_state
    @fire_delay = 0
    @image = nil # For collision detection purposes
  end
  
  # Can we fire our current primary weapon?
  def can_fire?
    if @fire_delay <= 0
      if @model.firing_order.size > 0
        weapon = @model.firing_order[0]
        return weapon.can_fire?
      end
    end
    return false
  end
  
  def can_fire_secondary?
    secondary = @model.chosen_secondary
    if secondary
      return secondary.can_fire?
    end
    return false
  end
  
  # Takes the given KuiWeapon and tells the sector to render it
  def fire(projectile, delay = SECS_BETWEEN_PRIMARY_FIRINGS)
    @sector_state.fire(projectile)
    @fire_delay = delay
  end
  
  def image
    unless @image
      @image = @rl.image_for(@model.image_filename)
    end
    return @image
  end

  def kill
    @alive = false
  end

  def update(delay)
    if @fire_delay > 0
      @fire_delay -= delay
      @fire_delay = 0 if @fire_delay < 0
    end
    if @model.target
      @model.target = nil unless @model.target.alive
    end
  end
  
end

# The computer tells this ship what to do
class AIController < ShipController
  
  attr_accessor :stay
  attr_accessor :behavior
  attr_accessor :fleet
  attr_reader :leaving
  
  def initialize(model, sector_state)
    super
    @leaving = false
    @stay = nil
    @fleet = nil
    @behavior = CrazyBehavior.new(@model)
    @fb = nil
  end
  
  # Force this ship to take up fighting behavior against the given target,
  # with the given FleetController coordinating
  def fight(target, fleetController)
    @behavior = FightBehavior.new(@model, target, self, fleetController)
  end
  
  # Force this ship to take up the fleeing behavior
  def flee
    @leaving = true
    @fb = FleeBehavior.new(@model)
    @behavior = @fb
  end
  
  def kill
    super
    @fleet.kill(model) if @fleet
  end
  
  def update(delay)
    super
    if @alive
      # If our time's up, transition to jumping out
      if @fleet.current_stay > @stay && @fb != @behavior
        flee
      end
      @behavior.update(delay)
    end
  end
end

class SimpleWaypoint
  
  attr_accessor :pos
  
  def initialize(ftor)
    @pos = ftor
  end
  
  def x
    @pos.x
  end
  
  def y
    @pos.y
  end
  
end


class Behavior
  
  def initialize(model)
    @model = model
    @fleet_controller = nil
  end
    
  # Steers and accelerates us to the given waypoint (which is a KuiShip)
  # Returns the aimer used to do it, in case it's needed
  def go_toward_waypoint(waypoint,delay)
    aim = Aimer.new(@model, waypoint)
    turn = aim.rotation
    accel = aim.accel
    
    @model.rotate(turn * delay) if turn
    @model.accelerate(accel * delay) if accel
    return aim
  end
  
  def pick_waypoint(force_update = false)
    if force_update || @fleet_controller.waypoint == nil
      @fleet_controller.waypoint = do_pick_waypoint
    end
  end
  
  # Do whatever it is that this behavior does
  def update(delay)
    
  end
end

class CrazyBehavior < Behavior
  def update(delay)
    # Go nuts
    @model.rotate(delay)
    @model.accelerate(delay)
  end  
end

# Like HarassBehavior, except deadlier
class FightBehavior < Behavior
  def initialize(model, target, aic, fc)
    super(model)
    @fleet_controller = fc
    @ai_controller = aic
    choose_target(target)
  end
  
  def choose_target(target)
    @waypoint = target
    @model.target = target
  end
  
  def update(delay)
    if @model.target
      aimer = go_toward_waypoint(@model.target, delay)
      
      if @ai_controller.can_fire?
        next_weapon = @ai_controller.model.firing_order[0]
        if aimer.closing_range.magnitude < next_weapon.range
          if aimer.rotation == 0
            @ai_controller.fire(@model.fire)
          end
        end
      end
      @model.next_secondary
      if @ai_controller.can_fire_secondary?
        next_weapon = @model.chosen_secondary
        if aimer.closing_range.magnitude < next_weapon.range
          if aimer.rotation == 0
            @ai_controller.fire(@model.fire_secondary, 0)
          end
        end
      end
    end
  end
end

class FleeBehavior < Behavior
  def update(delay)
    @model.accelerate(delay)
    @model.jump(delay)
  end
end

class GoBehavior < Behavior
  def update(delay)
    @model.accelerate(delay)
  end
end

# Like ScannerBehavior, except we don't ever change targets
class HarassBehavior < Behavior
  def initialize(model)
    super
  end
  
  def update(delay)
    if @model.target
      go_toward_waypoint(@model.target, delay)
    end
  end
end

class PatrolBehavior < Behavior
  CLOSE_ENOUGH = 50
  
  def initialize(model, fc)
    super(model)
    @time_this_waypoint = 0
    @sector = fc.sector
    @fleet_controller = fc
    pick_waypoint
  end
  
  # Waypoints are generally ships; in the case of Patrol, it's just an invisible
  # ship with zero velocity
  def do_pick_waypoint
    vec = random_spot(KuiSector::JUMPIN_DISTANCE)
    #waypoint = KuiShip.new
    #waypoint.x = vec.x
    #waypoint.y = vec.y
    return SimpleWaypoint.new(vec)
  end
  
  def update(delay)
    go_toward_waypoint(@fleet_controller.waypoint, delay)
    current = Rubygame::Ftor.new_from_to([@model.x, @model.y],
      [@fleet_controller.waypoint.x,@fleet_controller.waypoint.y])
    if current.magnitude < CLOSE_ENOUGH
      pick_waypoint(true)
    end
  end
end

class ScannerBehavior < Behavior
  SHIP_CLOSE_ENOUGH = 50
  
  def initialize(model, fc)
    super(model)
    @time_this_waypoint = 0
    @sector = fc.sector
    @fleet = fc.fleet
    @fleet_controller = fc
    pick_waypoint
  end
  
  def do_pick_waypoint
    tries = 5
    @time_this_waypoint = 0
    result = nil
    until(result || tries <= 0)
      tries -= 1
      ships = @sector.all_ships
      waypoint = ships.random
      
      result = waypoint if @fleet.ships.index(waypoint) == nil
      #break if tries <=0
    end
    return result
  end
  
  def update(delay)
    @time_this_waypoint += delay
    if @fleet_controller.waypoint
      go_toward_waypoint(@fleet_controller.waypoint, delay)
      current = Rubygame::Ftor.new_from_to([@model.x, @model.y],
        [@fleet_controller.waypoint.x,@fleet_controller.waypoint.y])
      if current.magnitude < SHIP_CLOSE_ENOUGH && @time_this_waypoint > 5
        pick_waypoint(true)
      end
    end
   
  end
end

class TradeBehavior < Behavior
  def initialize(model, fc)
    super(model)
    @sector = fc.sector
    @fleet_controller = fc
    pick_waypoint
    @arrived = false
  end
  
  def do_pick_waypoint
    planet = @sector.planets.random
    waypoint = nil
    if planet
      waypoint = planet
    end
    return waypoint
  end
  
  def update(delay)
    if @fleet_controller.waypoint
      go_toward_waypoint(@fleet_controller.waypoint, delay) unless @arrived
      current = Rubygame::Ftor.new_from_to([@model.x, @model.y],
        [@fleet_controller.waypoint.x, @fleet_controller.waypoint.y])
      close_enough = current.magnitude < 
        @fleet_controller.waypoint.landing_distance
      if @arrived || close_enough
        @arrived = true
        @model.slow(delay)
      end
    end  
  end
end

# Controls the given ship by interpreting the embedded ControlsHolder
class PlayerController < ShipController
  
  attr_reader :controls
  
  def initialize(model, sector_state)
    super
    @controls = ControlsHolder.new(@rl.options.controls)
    @main_action = nil
    @fireOnceControls = Set.new
  end
  
  # checks to see if a one-per-press control (like :next_target) is active
  def control_active_once?(sym)
    if @controls.active?(sym)
      unless @fireOnceControls.include?(sym)
        @fireOnceControls << sym
        return true
      end
    else
      @fireOnceControls.delete(sym)
    end
    return false
  end
  
  def interpret(event)
    @controls.interpret(event)
  end
  
  def keyTyped(event)

  end
  
  def target_nearest_hostile
    player_ship = ResourceLocator.instance.repository.universe.player.start_ship
    chosen = nil
    dist = 10000
    all_targets = @sector_state.sprites.select do |s|
      s.respond_to?(:targetable?) && s.targetable?
    end
    all_targets.each do |sprite|
      has_model = sprite.respond_to?(:model)
      model = has_model ? sprite.model : nil
      puts model
      if has_model && !model.equal?(player_ship)
        targeting = model.respond_to?(:target)
        if model.respond_to?(:target) && model.target.equal?(player_ship)
          sprite_dist = (model.pos - player_ship.pos).magnitude
          if sprite_dist < dist
            chosen = sprite
            dist = sprite_dist
          end
        end
      end
    end
    if chosen
      player_ship.target = chosen.model if chosen
    end
  end
  
  def update(delay)
    super
    
    if @controls.active?(:accelerate)
      @model.accelerate(delay)
    elsif @controls.active?(:slow)
      @model.slow(delay)
    end
    
    if @controls.active?(:rotate_left)
      @model.rotate(-delay)
    elsif @controls.active?(:rotate_right)
      @model.rotate(delay)
    end
    
    if @controls.active?(:jump) && @model.itinerary.size > 0
        @model.jump(delay)
    else
      @model.dejump(delay)
    end
    
    if @controls.active?(:fire_primary_weapons)
      if self.can_fire?
        self.fire(@model.fire)
      end
    end
    
    if control_active_once?(:next_target)
      @model.target = @sector_state.next_target(@model.target)
    end
   
    if control_active_once?(:next_secondary_weapon)
      @model.next_secondary
    end
    
    if @controls.active?(:fire_secondary_weapon)
      if self.can_fire_secondary?
        self.fire(@model.fire_secondary, 0)
      end
    end
   
    if control_active_once?(:quicksave)
      player = @rl.repository.universe.player
      save_game(player.name, $QUICKSAVE_SUFFIX)
    end
   
    if control_active_once?(:nearest_hostile_target)
      self.target_nearest_hostile
    end
   
  end
end

class ProjectileController < ShipController
  
  attr_accessor :behavior
  attr_accessor :waypoint
  
  def initialize(model, sector_state)
    super
    @behavior = setup_behavior
    @waypoint = nil
  end
  
  def setup_behavior
    if @model.seeking
      return HarassBehavior.new(@model)
    end
    return GoBehavior.new(@model)
  end
  
  def update(delay)
    super
    if @alive
      @behavior.update(delay)
      
      # Collision detection
      img = self.image
      my_radius = [img.h, img.w].max / 12 # Half of six frames
      
      potentials = @sector_state.collidables
      potentials = potentials.reject { |p| @model.immune.include?(p.model) }
      if @model.target
        potentials = potentials.select do |p|
          p.model.equal?(@model.target) 
        end
      end
      
      hits = potentials.select do | sprite |
        total_radius = my_radius + sprite.radius
        distance = (@model.pos - sprite.model.pos).magnitude
        distance <= total_radius
      end
        
      hits.each do | sprite |
        sprite.model.hit_by(@model)
        hit_fleets = @sector_state.fleet_controllers.select do |fc|
          ships = fc.ai_controllers.collect { |aic| aic.model }
          ships.include?(sprite.model)
        end
        hit_fleets.each { |fc| fc.hit_by(@model) }
        @model.kill
      end
    end
  end
end