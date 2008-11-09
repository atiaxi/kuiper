require 'observer'

require 'kuiobject'

# Any objects designed to fly around in space should inherit from this
class KuiSpaceworthy < KuiObject
  child :blueprint
  child :target
  
  # This is only important during gameplay, mostly so the target info pane can
  # tell the player who the owner of this ship is
  attr_accessor :owner
    
  # This should apply only to the player's ship; when 'phased' the other ships
  # are supposed to treat it as though it's not there.  This is helped out by 
  # the fact that KuiSector's :all_ships won't add a phased player ship.
  # Not really designed for a cloaking device, but it could be made to be
  attr_accessor :phased  
    
  numeric_attr :x, :y
  attr_reader :velocity
  raw_attr :velocity_x, :velocity_y
  
  attr_accessor :facing
  raw_attr :facing_x, :facing_y
  
  # Set this to false to be culled
  attr_accessor :alive
  
  # Ships are priced rather than blueprints, so you can sell a bare-bones ship
  # for cheaper than the tricked-out version.
  numeric_attr :price
  
  include BlueprintDelegator
  
  def initialize(blueprint = nil)
    @blueprint = blueprint
    super()
    @phased = false
    @target = nil
    @facing = Rubygame::Ftor.new(0, -1)
    @x = 0
    @y = 0
    @price = 0
    @accel = 10.0
    @alive = true
    @owner = nil
    @velocity = Rubygame::Ftor.new(0,0.0001)
  end
  
  # When new fleets are spawned, or a new ship bought, it's duplicated from the
  # original; this is us making sure they're unique
  def initialize_copy(copy)
    self.tag = @rl.repository.ensure_unique_tag(copy.tag)
    @facing = copy.facing.dup
    @velocity = copy.velocity.dup
    @anti_addons = copy.anti_addons.dup
  end
  
  def accelerate(delay)
    mag = delay * self.accel
    impulse = @facing * mag
    max = self.max_speed
    max = 0.0001 if max <= 0
    @velocity += impulse
    if @velocity.magnitude > max
      @velocity.magnitude = max
    end
  end
  
  def facing_x
    return @facing.x
  end
  
  def facing_x=(x)
    @facing.x = x.to_f
  end
  
  def facing_y
    return @facing.y
  end
  
  def facing_y=(y)
    @facing.y = y.to_f
  end
  
  def kill
    @alive = false
  end
  
  # Accelerates in the opposite direction of where we're going
  def slow(delay)
    if @velocity.magnitude > 0
      accel = self.accel
      if accel <= 0
        @velocity.magnitude = 0.0001
      else
        mag = delay * self.accel
        impulse = -@velocity.unit * mag
        if impulse.magnitude > @velocity.magnitude
          impulse.magnitude = @velocity.magnitude
        end
        @velocity += impulse
      end
    end
  end
  
  # Since the ftor's angle isn't to our liking, we'll have to convert it for
  # display purposes (and display purposes /only/ - use the facing ftor for 
  # everything else)
  def angle
    img_angle = @facing.angle.to_degrees
    img_angle = (img_angle + 90) % 360
    return img_angle
  end
  
  def playable?
    return false unless super
    return false unless @blueprint
    return false unless @blueprint.playable?
    return false unless @tag
    return true
  end

  # Position as an ftor
  def pos
    return Rubygame::Ftor.new(@x,@y)
  end
  
  def rotate(delay)
    mag = delay * self.rot_per_sec.to_radians
    @facing.angle += mag
  end
  
  # Stops the ship completely w/o deceleration
  def stop
    @velocity.x = 0
    @velocity.y = 0
  end
  
  def update(delay)
    slice = @velocity * delay
    @x += slice.x
    @y += slice.y
  end
  
  def velocity_x
    return @velocity.x
  end
  
  def velocity_x=(x)
    @velocity.x = x.to_f
  end
  
  def velocity_y
    return @velocity.y
  end
  
  def velocity_y=(y)
    @velocity.y = y.to_f
  end
  
end

# Any object blueprints designed to fly around in space should inherit from this
class KuiSpaceworthyBlueprint < KuiObject
  string_attr :image_filename
  set_size_for :image_filename, [0,0]
  
  numeric_attr :rot_per_sec
  numeric_attr :accel
  numeric_attr :max_speed
  
  string_attr :name

  string_attr :description
  set_size_for :description, [5,40]

  def initialize
    super
    @image_filename = nil
    @name = nil
    @description=nil
    @accel = 80.0
    @max_speed = 150.0
    @rot_per_sec = 150.0 
  end

  def playable?
    return false unless super
    return false unless @image_filename
    return false unless ResourceLocator::instance.image_for(@image_filename)
    return false unless @name
    return false unless @accel > 0.0
    return true
  end

end
class KuiShip < KuiSpaceworthy
  
  include Observable
  
  child :cargo
  child :addons
  child :anti_addons
  child :weapons
  child :owner
 
  numeric_attr :shields, :armor
  numeric_attr :jumping_progress
  numeric_attr :fuel
  # Name is the name that'll show up while playing, tag is for internal use
  string_attr :name
  
  # Not a child or field
  attr_reader :jumping
  attr_reader :jump_ready

  # Though the player is currently the only one who actually uses this, I see
  # no reason not to keep it in the ship object for future ships which may
  # travel multiple sectors.
  child :itinerary
  
  # During play, it's helpful to have a list of weapons and how long they have
  # to recharge; since each weapon must be treated uniquely, we expand them into
  # this list.
  attr_reader :firing_order
  
  # Secondary weapons and the index of the currently chosen one
  child :secondaries
  numeric_attr :chosen_secondary_index
  
  # It's good to know which of the weapons we have that are actually ammo
  child :ammo
  
  def initialize(blue=nil)
    super(blue)
    @fuel = 100
    @jumping_progress = 0
    @jumping = false
    @jump_ready = false
    @itinerary = []
    @cargo = []
    @addons = []
    @anti_addons = []
    @weapons = []
    @secondaries = []
    @ammo = []
    @owner = nil
    @chosen_secondary_index = 0
    
    setup_firing_order
  end
  
  # Here for parity with add_cargo in case I ever want to do something fancier.
  # Right now it just adds the given addon amount times.
  def add_addon(addon, amount=1)
    1.upto(amount) do | index |
      @addons << addon
    end
  end
  
  # We've been struck by an anti-addon!
  def add_anti_addon(addon)
    previous = find_anti_addon(addon)
    if previous
      # NOTE: Changing += to = will disable stacking
      previous.duration += addon.duration
    else
      @anti_addons << addon.dup
    end
  end
  
  # Adds the amount of cargo to our stores.  This will add to the 'amount' field
  # of existing cargo if there, create it if not.
  def add_cargo(cargo, amount)
    preexisting = find_cargo(cargo)
    if preexisting
      total = (preexisting.amount + amount).to_f
      avg = preexisting.average_price * (preexisting.amount / total) +
         cargo.price * (amount / total)
      
      preexisting.amount = total.to_i
      preexisting.average_price = avg
    else
      new_cargo = cargo.dup
      new_cargo.amount = amount
      new_cargo.average_price = cargo.price
      @cargo << new_cargo
    end
  end
  
  # Adds the given amount of weapons to our arsenal.  Dups the weapon and sets
  # (or increases, if the weapon is already there) the amount by the given
  # amount.
  # Only if setup is true will setup_firing_order be called
  def add_weapon(weapon, amount=1,setup=true)
    preexisting = find_weapon(weapon)
    if preexisting
      preexisting.amount += amount
    else
      new_weapon = weapon.dup
      new_weapon.amount = amount
      
      if new_weapon.is_ammo
        # Go through existing weapons, see if they use this as ammo and update
        # accordingly
        all_weapons.each do | wpn |
          wpn.ammo.each do | ammo |
            if ammo.base_tag == new_weapon.base_tag
              old_index = wpn.ammo.index(ammo)
              wpn.ammo[old_index] = new_weapon
            end
          end
        end
      else
        # Go through existing ammo, see if this weapon uses any of it
        @ammo.each do | ammo |
          new_weapon.ammo.each do | new_ammo |
            if ammo.base_tag == new_ammo.base_tag
              old_index = new_weapon.ammo.index(new_ammo)
              new_weapon.ammo[old_index] = ammo
            end
          end
        end
      end  
      if new_weapon.secondary_weapon
        @secondaries << new_weapon
      elsif new_weapon.is_ammo
        @ammo << new_weapon
      else
        @weapons << new_weapon
      end
    end
    setup_firing_order if setup
  end
  
  def all_cargo
    return @cargo 
  end
  
  # Weapons both primary, secondary, and ammo
  def all_weapons
    return @weapons + @secondaries + @ammo
  end
  
  def available_cargo
    return self.max_cargo - self.total_cargo
  end
  
  def available_expansion
    return self.expansion_space - self.total_expansion
  end
  
  def available_hardpoints
    return self.hardpoints - self.total_hardpoints
  end
  
  # All this does is check fuel availability
  def can_jump?
    return self.fuel >= self.fuel_per_jump
  end
  
  # Whether or not the mission-related cargo on this ship will fit on the given
  # ship.
  def can_transfer_to?(other_ship)
    mission_total = 0
    mission_cargo.each { |mc| mission_total += mc.amount }
    return mission_total <= other_ship.available_cargo
  end
  
  # This sorts the firing_order list.
  def change_firing_order
    @firing_order.sort! { |w1,w2| (w1.cooldown <=> w2.cooldown) }
  end
  
  # Returns the currently chosen secondary; if nil, this will cycle back to the
  # beginning of the list
  def chosen_secondary
    if @chosen_secondary_index >= @secondaries.size
      @chosen_secondary_index = 0
    end
    return @secondaries[@chosen_secondary_index]
  end
  
  def dejump(delay)
    if @jumping
      @jumping_progress -= delay
      if @jumping_progress <= 0
        @jumping_progress = 0
        @jumping = false
      end
    end
  end
  
  # Ship is being removed (can also be a despawn),
  # inform observers
  def die
    changed
    notify_observers(self, :gone)
  end
  
  # Returns the first anti-addon we have that shares a tag
  def find_anti_addon(addon)
    return @anti_addons.detect { |a| a.tag == addon.tag }
  end
  
  # Returns the first cargo we have that shares a blueprint with the given
  # cargo, and is as just as mission related.
  def find_cargo(cargo)
    return @cargo.detect { |c| c===cargo &&
      c.mission_related == cargo.mission_related }
       
#    return @cargo.detect { |c| (c.blueprint == cargo.blueprint) &&
#                               (c.mission_related == cargo.mission_related) }
  end
  
  # Returns the first weapon we have that shares a tag with the given weapon
  def find_weapon(weapon)
    return all_weapons.detect { |w|
      w.base_tag == weapon.base_tag }
  end
  
  # Marks the current weapon as fired, re-sets its cooldown, and re-sorts the
  # firing order
  def fire
    active = nil
    weapon = @firing_order[0]
    if weapon
      active = weapon.fire(self)
      change_firing_order
      # TODO: For turrets, probably want to change the facing & velocity
    end
    return active
  end
  
  # Fire the currently selected secondary
  def fire_secondary
    weapon = self.chosen_secondary
    if weapon
      return weapon.fire(self)
    end
  end
  
  # We've been hit!!!!
  def hit_by(projectile)
    damage = projectile.damage
    
    projectile.anti_addons.each do | addon |
      add_anti_addon(addon)
    end
    
    if @jumping
      total = self.max_shields + self.max_armor
      percent = damage / total.to_f
      setback = percent * self.secs_to_jump
      self.dejump(setback)
    end
    self.shields  -= damage
    if self.shields < 0
      damage = self.shields.abs
      self.shields = 0
      die
    else
      damage = 0
    end
    
    # Who did this to me?  They will pay!
    culprit = projectile.owner
    self.armor -= damage
    if self.armor < 0
      self.kill 
      self.armor = 0
      @owner.org_killed_me(culprit) if @owner && culprit
    else
      # Bad mouth them to everyone
      if @owner && culprit
        @owner.org_shot_me(culprit)
      end  
    end
    
  end
  
  # Everyone needs their own set of weapons
  def initialize_copy(copy)
    super(copy)
    @weapons = copy.weapons.dup
    setup_firing_order
  end
  
  def jump(delay)
    unless @jump_ready
      @jumping = true
      @jumping_progress += delay
      if @jumping_progress >= self.secs_to_jump
        @jumping_progress = self.secs_to_jump
        @jump_ready = true
      end
    end
  end
  
  # Restores this ship to its non-jumping state
  def jump_complete
    @jump_ready = false
    @jumping_progress = 0
    @jumping = false
  end
  
  def mission_cargo
    return @cargo.select { |c| c.mission_related }
  end
  
  def delegate(name, attrs=[])
    if @blueprint
      result = @blueprint.send(name, *attrs)
      if result.is_a? Numeric
        @addons.each do | addon |
          result += addon.send(name, *attrs)
        end
        @anti_addons.each do | addon |
          result += addon.send(name, *attrs)
        end
      end
      return result
    end
    super
  end
  
  # Switches either the current secondary's ammo or, if there's nothing new
  # there, the current secondary weapon
  def next_secondary
    secondary = self.chosen_secondary
    if secondary
      unless secondary.next_ammo
        @chosen_secondary_index += 1
      end
    end
  end
  
  def non_mission_cargo
    return @cargo.reject { |c| c.mission_related }  
  end
  
  def playable?
    return false unless super
    return false unless @shields + @armor > 0
    return false unless @name
    return true
  end
  
  def post_load
    setup_firing_order
  end
  
  def remove_addon(addon,amount=1)
    1.upto(amount) do | index |
      @addons.delete_first(addon)
    end
  end
  
  # Remove the given amount of cargo from the ship's hold.
  # If the cargo is entirely depleted, will remove it.
  def remove_cargo(cargo, amount)
    preexisting = find_cargo(cargo)
    if preexisting
      if preexisting.amount > amount
        preexisting.amount -= amount
      else
        @cargo.delete(preexisting)
      end
    end
  end
  
  def remove_weapon(weapon, amount=1)
    
    preexisting = find_weapon(weapon)
    if preexisting
      if preexisting.amount > amount
        preexisting.amount -= amount
      else
        @weapons.delete(preexisting)
        @secondaries.delete(preexisting)
        @ammo.delete(preexisting)
      end
    end
    setup_firing_order
  end
  
  # When we have a new weapon, expands them into the list
  def setup_firing_order
    @firing_order = []
    @weapons.each do | weapon |
      amount = weapon.amount
      1.upto(amount) do | index |
        expanded = weapon.dup
        expanded.transient = true
        expanded.amount = 1
        @firing_order << expanded
      end
    end
    change_firing_order
  end
  
  def total_cargo
    normal = @cargo.inject(0) { |prev,c| prev+c.amount }
    return normal
  end
  
  def total_expansion
    addTotal = @addons.inject(0) do | prev,addon|
      prev + addon.expansion_required
    end
    weapTotal = all_weapons.inject(0) do | prev,weapon|
      prev+ (weapon.expansion_required * weapon.amount)
    end
    return addTotal + weapTotal
  end
  
  def total_hardpoints
    addTotal =  @addons.inject(0) do | prev, addon |
      prev + (addon.hardpoints_required)
    end
    weapTotal = @weapons.inject(0) do | prev, weapon |
      prev + (weapon.hardpoints_required * weapon.amount)
    end
    return addTotal + weapTotal
  end
  
  # How much this ship is worth on a tradein.  It's 75% of the ship's base
  # value, 85% of the addon/weapons cost, plus the average price for any cargo.
  def tradein
    total = 0.75 * self.price
    @addons.each { |a| total += 0.85 * a.price }
    self.all_weapons.each { |w| total += 0.85 * w.price }
    self.non_mission_cargo.each { |c| total += (c.amount * c.average_price) }
    return total
  end
  
  def update(delay)
    super
    @firing_order.each do | weapon |
      weapon.update(delay)
    end
    @secondaries.each do | weapon |
      weapon.update(delay)
    end
    @anti_addons.dup.each do | addon |
      addon.duration -= delay
      if addon.duration <= 0
        @anti_addons.delete(addon)
      end
    end
    
    if @armor < self.max_armor
      regen = self.armor_regen * self.max_armor * delay
      @armor += regen
      @armor = self.max_armor if @armor > self.max_armor
    elsif @shields < self.max_shields
      regen = self.shield_regen * self.max_shields * delay
      @shields += regen
      @shields = self.max_shields if @shields > self.max_shields
    end
    
    if @fuel < self.max_fuel
      regen = self.fuel_regen * self.max_fuel * delay
      @fuel += regen
      @fuel = self.max_fuel if @fuel > self.max_fuel
    end
  end
end

class KuiShipBlueprint < KuiSpaceworthyBlueprint
  numeric_attr :max_shields, :max_armor
  numeric_attr :shield_regen, :armor_regen, :fuel_regen
  numeric_attr :hardpoints, :expansion_space
  numeric_attr :secs_to_jump
  numeric_attr :max_cargo
  numeric_attr :max_fuel
  numeric_attr :fuel_per_jump
  
  def initialize
    super
    @secs_to_jump = 10
    @max_cargo = 10.0
    @hardpoints = 1
    @max_fuel = 100
    @fuel_per_jump = 25
    @expansion_space = 10.0
    @shield_regen = 0.01 # 100 sec to recharge
    @armor_regen = 0.005 # 200 sec to recharge
    @fuel_regen =  0.001 # 1,000 sec to recharge
  end
  
  def playable?(addon_exceptions = false)
    return false unless super()
    unless addon_exceptions
      return false unless @max_shields + @max_armor > 0
      return false unless @max_fuel > @fuel_per_jump
      return false unless @rot_per_sec > 0.0
    end
    return true
  end
end

class KuiAddon < KuiShipBlueprint
  
  numeric_attr :expansion_required
  numeric_attr :hardpoints_required
  numeric_attr :duration
  numeric_attr :price
  
  def initialize
    super
    @expansion_required = 0
    @hardpoints_required = 0
    @max_shields = 0
    @max_armor = 0
    @shield_regen = 0
    @armor_regen = 0
    @hardpoints = 0
    @expansion_space = 0
    @rot_per_sec = 0
    @accel = 0
    @max_speed = 0
    @secs_to_jump = 0
    @max_cargo = 0
    @max_fuel = 0
    @fuel_per_jump = 0
    @price = 0
    @duration = 30
  end
  
  def playable?
    # Not calling super because superclass playability is overly-specific
    # to ships
    return false unless @tag
    return false unless @name
    return true
  end
  
end

class KuiWeaponBlueprint < KuiSpaceworthyBlueprint
  child :ammo
  child :anti_addons
  
  numeric_attr :cooldown # How many secs until we can shoot again
  numeric_attr :max_cooldown # What :cooldown will be reset to when we do fire.
  boolean_attr :turreted
  boolean_attr :seeking
  boolean_attr :auto_accelerate
  boolean_attr :is_ammo
  boolean_attr :secondary_weapon
  numeric_attr :amount
  numeric_attr :damage
  numeric_attr :max_ttl # How many secs this sticks around once fired
  
  numeric_attr :expansion_required
  numeric_attr :hardpoints_required
  
  # Since non-blueprint weapons are actually projectiles,
  # we have to move price over here.
  numeric_attr :price
    
  def initialize()
    super()
    @ammo = ArraySet.new
    @anti_addons = ArraySet.new
    @selected_ammo = nil
    @max_cooldown = 3.0
    @cooldown = 0.0
    @turreted = false
    @seeking = false
    @secondary_weapon = false
    @auto_accelerate = true
    @is_ammo = false
    @amount = 0.0
    @damage = 0.0
    @max_ttl = 5.0
    @expansion_required = 0
    @hardpoints_required = 0
    @price = 0.0
    
    @accel = 500
    @max_speed = 500
    @rot_per_sec = 720
    @derived_from = nil
  end
  
  def can_fire?
    if @cooldown <= 0
      if @ammo.size > 0
        return self.selected_ammo.amount > 0
      else
        return true
      end
    end
    return false
  end
  
  # Marks this blueprint as having fired; returns a newly initialized
  # KuiWeapon.
  def fire(fired_by)
    @cooldown = @max_cooldown
    if @ammo.size > 0
      self.selected_ammo.amount -= 1
    end
    parent = @derived_from || self
    fired = KuiWeapon.new(parent,fired_by, selected_ammo)
    return fired
  end
  
  def initialize_copy(copy)
    self.tag = @rl.repository.ensure_unique_tag(copy.tag)
    @derived_from = copy
  end
  
  # Switches us to the next ammo.  Returns true if this worked without issue, 
  # false if we had to wrap around or if this doesn't require ammo
  def next_ammo
    if @ammo.size > 0
      selected = self.selected_ammo
      index = ammo.index(selected)
      new_selected = @ammo[index + 1]
      unless new_selected
        @selected_ammo = @ammo[0]
        return false
      end
      @selected_ammo = new_selected
      return true
    end
    return false
  end
  
  def playable?
    if @is_ammo
      return false unless @image_filename
      return false unless ResourceLocator::instance.image_for(@image_filename)
      return false unless @name
    else
      return false unless super
      return false unless @max_ttl > 0.0
    end
    return true
  end
  
  # Based on this weapon's stats and the currently selected ammo
  # Overestimates because it assumes weapon is always at full speed
  # Fix later if it's a problem
  def range
    ttl = @max_ttl
    ttl += @selected_ammo.max_ttl if selected_ammo
    max = @max_speed
    max += @selected_ammo.max_speed if selected_ammo
    
    return max * ttl
  end
  
  def selected_ammo
    unless @selected_ammo && @ammo.index(@selected_ammo)
      @selected_ammo = @ammo[0]
    end
    return @selected_ammo
  end
  
  def status
    ammo = ''
    selected = self.selected_ammo
    if selected
      if selected.amount > 0
        ammo = self.synopsis
      else
        ammo = "No #{selected.name} remaining"
      end
    end
    time = '(Ready)'
    if @cooldown > 0
      time = "(Ready in #{@cooldown.to_i + 1}s)"
    end
    return "#{ammo}#{time}"
  end
  
  def synopsis
    result = self.name || self.tag
    if @amount > 1
      result += " x#{@amount}"
    end
    return result
  end
  
  def update(delay)
    if @cooldown > 0
      @cooldown -= delay
      @cooldown = 0 if @cooldown < 0
    end
  end
end

class KuiWeapon < KuiSpaceworthy
  child :immune
  child :owner
  child :shooter
  numeric_attr :ttl
  
  def initialize(blueprint = nil, fired_by = nil, ammo=nil)
    super(blueprint)
    @ammo = ammo
    @alive = true
    @shooter = fired_by
    @immune = []
    @immune << fired_by if fired_by
    if blueprint
      @ttl = blueprint.max_ttl
    else
      @ttl = 0
    end
    
    if fired_by
      @x = fired_by.x
      @y = fired_by.y
      @velocity = fired_by.velocity.dup
      @facing = fired_by.facing.dup
      @owner = fired_by.owner
      
      if self.auto_accelerate
        accelerate(0.00000001) # magnitude= breaks on the zero vector
        @velocity.magnitude = self.max_speed
      end
      
      if fired_by.target && self.turreted
        interval = 0.1
        turn = 1
        while turn != 0
          aimer = Aimer.new(self, fired_by.target)
          turn = aimer.turn
          rotate(interval * turn)
        end
      end
      
      self.target = fired_by.target
      
      @velocity.angle = @facing.angle
    end
  end
  
  # Anti addons are those of the weapon and its ammo
  def anti_addons
    base = @blueprint.anti_addons
    return base + @ammo.anti_addons if @ammo
    return base
  end
  
  # Here to shadow the blueprint's image so that different ammo doesn't have to
  # inherit the same image filename
  def image_filename
    if @ammo
      return @ammo.image_filename
    end
    return @blueprint.image_filename
  end
  
  # Gives projectiles and ammo the same kind of relationship that ships and
  # addons have
  def method_missing(name, attrs = [])
    result = @blueprint.send(name, *attrs)
    if @ammo
      if result.is_a? Numeric
        result += @ammo.send(name, *attrs)
      end
    end
    return result
  end
  
  def seeking
    if @ammo
      return @ammo.seeking
    else
      return @blueprint.seeking
    end
  end
  
  def update(delay)
    super
    @ttl -= delay
    @alive = false if @ttl <= 0
  end
  
end