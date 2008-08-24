
require 'engine'
require 'kuiobject'
require 'planet'
require 'controllers'
require 'gameover'

require 'sectorviews'
require 'sliderbox'

# The sector state is both the state that the
# player will fly around in and the state
# for editing some parts of the sector
# (i.e. its planets)
class SectorState < Opal::State
  
  attr_accessor :center
  attr_reader :played
  attr_reader :radar
  attr_reader :sector
  attr_reader :fleet_controllers
  attr_reader :player_ship
  
  SCROLL_SPEED = 5
  DEPTH_PLAYER = -500
  DEPTH_PROJECTILE = 10
  DEPTH_PLANET = 500
  
  include Waker
  
  def initialize(sector, driver)
    super(driver)
    @continue = nil
    @jumpbox = nil
    @new_planet_mode = false
    @spacing = 3
    @spawn_delay = 0.0
    @sector = sector
    @played = false
    @models_to_sprites = {}
    @rl = ResourceLocator.instance
    
    @controllers = []
    @fleet_controllers = []
    setup_center
    setup_gui
    setup_fleets
    setup_starfield(100)
    setup_controls
  end
  
  def activate
    super
    player = @rl.repository.universe.player
    
    player.visit(@sector)
    
    unless $edit_mode
      @player_controller.controls.reset
      
      eval = MissionEvaluatorState.new(@driver, player.missions, self)
      result = eval.check
          
      if result
        eval = MissionEvaluatorState.new(@driver, @sector.plot, self)
        result = eval.award
      end
    end
  end
  
  def add_ai_fleet(fleet, random = true)
    jitter = 200
    vec = random_spot(KuiSector::JUMPIN_DISTANCE)
    
    fleetController = FleetController.new(fleet, self)
    #@controllers += fleetController.ai_controllers
    @fleet_controllers << fleetController
    
    fleet.ships.each do | ship |
      ship_sprite = ShipSprite.new(ship, @player_sprite)
      
      jitter_x = rand(jitter) - jitter/2
      jitter_y = rand(jitter) - jitter/2
      if random
        ship.x = vec.x + jitter_x
        ship.y = vec.y + jitter_y
        ship.facing = -vec.unit
      end
      
      self << ship_sprite
      @models_to_sprites[ship] = ship_sprite
    end
  end
  
  def add_projectile(projectile)
    pc = ProjectileController.new(projectile,self)
    @controllers << pc
    
    sprite = ShipSprite.new(projectile, @player_sprite)
    sprite.targetable = false
    sprite.collidable = false
    sprite.depth = DEPTH_PROJECTILE
    self << sprite
  end
  
  def attempt_landing
    closest = [ nil, 90000 ]
    player_x = @player_sprite.model.x
    player_y = @player_sprite.model.y
    player_pos = [player_x, player_y]
    @sector.planets.each do | planet |
      closest_planet, dist = closest
      planet_pos = [planet.x, planet.y]
      distance_vector = Rubygame::Ftor.new_from_to( player_pos, planet_pos )
      new_dist = distance_vector.magnitude
      if new_dist < dist
        closest = [ planet, new_dist ]
      end
    end
    closest_planet, dist = closest
    if closest_planet
      if dist < closest_planet.landing_distance
        landed = LandedState.new(@driver, closest_planet)
        callcc do | cont |
          @driver.replace(landed)
          @continue = cont
        end
     
        activate unless @continue # Do mission checks
      end
    end
  end
  
  # Returns a list of all our sprites that respond to :targetable with 'true'.
  def collidables
    return @sprites.select do | sprite |
      sprite.respond_to?(:collidable?) && sprite.collidable?
    end
  end
  
  def done
    @driver.pop
  end
  
  def draw(screen)
    draw_starfield(screen)
    super
    draw_target(screen)
  end
  
  def draw_starfield(screen)
    color = $edit_mode ? Rubygame::Color[:yellow] : Rubygame::Color[:white]
    @stars.each do | x,y, parallax |
      screen.fill(color,[ x.to_i,y.to_i, 1, 1])    
    end
  end
  
  def draw_target(screen)
    target = @player_controller.model.target
    if target
      # For now, draw a box around our target.  Get fancy later
      sprite = @models_to_sprites[target]
      if sprite
        screen.draw_box( sprite.rect.topleft, sprite.rect.bottomright, 
          Rubygame::Color[:white])
      else
        @rl.logger.warn("Player is targeting a model with no sprite: "+
          " #{target.inspect}")
      end
    end
  end
  
  def exit_planet_mode
    @new_planet_mode = false
    @new_planet.text = "New Planet"
    @new_planet.rect.right = @done.rect.right
  end
  
  def fire(projectile)
    @sector.projectiles << projectile
    add_projectile(projectile)
  end

  # While it's the PlayerController's job to react to most of the player's
  # commands, there are some commands the controller cannot handle itself
  # (e.g. going back to the main screen)
  def handle_controls(delay)
    # TODO: Now that the player controller actually knows about this class, we
    #       can move a lot of this functionality over there
    handler = @player_controller.controls
    if handler.active?(:main_menu)
      handler.reset
      @continue = nil
      @driver.swap
    elsif handler.active?(:land)
      attempt_landing
    elsif handler.active?(:map)
      open_map
    elsif handler.active?(:view_info)
      view_info
    elsif handler.active?(:radar_zoom_out)
      @radar.zoom(delay)
    elsif handler.active?(:radar_zoom_in)
      @radar.zoom(-delay)
    end
  end
  
  # This just displays the jumpbox if it's not there already.  The
  # display parameter determines whether we're showing or hiding the box
  def jump_in_progress(display)
    if display
      if @jumpbox == nil
        @jumpbox = JumpBox.new(@player_controller.model,
          SliderBox::ANCHOR_TOP,0, 1, 10)
        @jumpbox.depth = DEPTH_PLAYER
       #@jumpbox.translate_to(3, -@jumpbox.rect.h)
        self << @jumpbox
      end
      @jumpbox.start_showing
    else
      if @jumpbox
        @jumpbox.start_hiding
        if @jumpbox.hidden?
          self.sprites.delete(@jumpbox)
          @jumpbox = nil
        end
      end
    end
    
    dest = @player_controller.model.itinerary[0]
    unless dest
      self.sprites.delete(@jumpbox)
      @jumpbox = nil
    end
  end
  
  def mouseUp(event)
    x,y = event.pos
    if @new_planet_mode
      exit_planet_mode
      if @new_planet.rect.collide_point?(x,y)
        super
        return
      else
        new_planet_at(x,y)
      end
    end
    
    clicked_on = super
    clicked_on.each do | sprite |
      if sprite.respond_to?(:targetable?) && sprite.targetable?
        @player_controller.model.target = sprite.model
        @props.enabled = true if $edit_mode
      end
    end
  end
  
  def new_planet
    if @new_planet_mode
      exit_planet_mode
    else
      @new_planet_mode = true
      @new_planet.text = "Click to place the planet.  Click here to cancel"
      @new_planet.rect.right = @done.rect.right
    end
  end
  
  def new_planet_at(x,y)
    p = KuiPlanet.new
    p.name = "New Planet"
    #p.tag = "new_planet"
        
    isd = ImageSelectorDialog.new(@driver)
    callcc do | cont |
      @driver << isd
      @continue = cont
    end
    
    if isd.chosen && @rl.image_for(isd.chosen)
      dx = x - @rl.screen.width / 2
      dy = @rl.screen.height / 2 - y
      p.x = @player_sprite.model.x + dx
      p.y = @player_sprite.model.y - dy
      p.image_filename = isd.chosen
      @sector.planets << p
          
      reload_planets  
    end
    
  end
  
  # For the given target, this returns the next one in the list of viable
  # targets.  The player's the only likely user for this, so it never returns
  # him.
  def next_target(current_target)
    all_targets = @sprites.select do |s|
      s.respond_to?(:targetable?) && s.targetable?
    end
    all_targets = all_targets.collect { |t| t.model }
    current_index = all_targets.index(current_target)
    next_index = 0
    if current_index != nil
      next_index = (current_index + 1) % all_targets.size
    end

    return all_targets[next_index]
  end
  
  def open_map
    map = MapState.new(@driver)
    callcc do | cont |
      @continue = cont
      @driver << map
    end
    @player_controller.controls.reset
  end
  
  def player_jump
    ship = @player_controller.model
    if ship.can_jump?
      dest = ship.itinerary[0]
      if dest
        interim = JumpingState.new(dest, @driver,self)
        callcc do | cont |
          @driver.replace(interim)
          @continue = cont
        end
        ship.jump_complete
        ship.fuel -= ship.fuel_per_jump
        ship.itinerary.delete_at(0)
      end
    else
      @rl.visual_log << "Unable to complete jump: Insufficient fuel"
      ship.jump_complete
    end
  end
  
  def props
    selected = @player_controller.model.target
    if selected
      # TODO: If we ever display anything other than planets here, we're going
      #       to have to adapt this accordingly.
      #       For now, assume target's a planet
      dialog = PlanetEditor.new(selected, @driver)
      @driver << dialog
    end
  end
  
  def raw(event)
    @player_controller.interpret(event) if @player_controller
  end
  
  def reload_planets
    @sector.planets.each do | planet |
      sprite = PlanetSprite.new(planet, @player_sprite)
      sprite.targetable = $edit_mode
      sprite.depth = DEPTH_PLANET
      
      self << sprite
      @models_to_sprites[planet] = sprite
    end
  end
  
  def setup_center
    
    center_x, center_y = @rl.screen_rect.center
    
    if $edit_mode
      @player_sprite = InvisibleSprite.new
      @player_sprite.rect.center = [ center_x, center_y ]
    else
      model = @rl.repository.universe.player.start_ship
      @player_ship = model
      @player_sprite = PlayerSprite.new(model)
      #@player_sprite = TranslatableSprite.new(model,nil)
      @player_sprite.rect.center = [center_x, center_y]
      @models_to_sprites[model] = @player_sprite
    end
    self << @player_sprite
  end
  
  def setup_controls
    unless $edit_mode 
      model = @rl.repository.universe.player.start_ship
    else
      model = KuiShip.new
    end
    @player_controller = PlayerController.new(model,self)
    unless @controllers.index(@player_controller)
      @controllers << @player_controller
    end
    #@player_sprite.controller = @player_controller
  end
  
  def setup_fleets
    unless $edit_mode
      @sector.active_fleets.each do | active |
        add_ai_fleet(active, false)
      end
      
      # Not technically a fleet, but this is as good time as any
      @sector.projectiles.each do | projectile |
        add_projectile(projectile)
      end
    end
  end
  
  def setup_gui
    if $edit_mode
      self.clear
      rect = @rl.screen_rect
      @done = Button.new("Done") { self.done }
      @done.rect.bottomright = [ rect.right - @spacing,rect.bottom - @spacing]
      
      self << @done
        
      bottom = @done.rect.top - @spacing
      
      @new_planet_mode = false
      @new_planet = Button.new("New Planet") { self.new_planet }
      @new_planet.rect.bottomright = [ @done.rect.right, bottom ]
      self << @new_planet
      bottom = @new_planet.rect.top - @spacing
      
      @props = Button.new("Properties") { self.props }
      @props.rect.bottomright = [@done.rect.right ,bottom]
      @props.enabled = false
      self << @props
    else
      unless @radar
        @radar = RadarBox.new(self,
          SliderBox::ANCHOR_BOTTOM, @rl.screen.height, -1, 10)
        @radar.depth = DEPTH_PLAYER
        @radar.show
      end
    
      @log = LogBox.new(SliderBox::ANCHOR_BOTTOM, @rl.screen.height, -1,
        @radar.rect.right + 10)
      @log.depth = DEPTH_PLAYER
      @log.show
      @log.rect.w = @rl.screen.width - @radar.rect.right - 20
      
      @secondary = WeaponBox.new(@player_ship, SliderBox::ANCHOR_LEFT,
        0, 1, 50)
      @secondary.depth = DEPTH_PLAYER
      @secondary.show
      
      @ship_status = ShipBox.new(@player_ship, SliderBox::ANCHOR_LEFT,
        0, 1, 200)
      @ship_status.depth = DEPTH_PLAYER
      @ship_status.show 
      
      @target_ship = ShipBox.new(@player_ship.target, SliderBox::ANCHOR_RIGHT,
        @rl.screen.width, -1,200)
      @target_ship.depth = DEPTH_PLAYER
      @target_ship.show
      
      self << @radar
      self << @log
      self << @secondary
      self << @ship_status
      self << @target_ship
    end
    reload_planets
  end
  
  def setup_starfield(num_stars)
    @stars = []
    num_stars.times do
      randx = rand(@rl.screen.w)
      randy = rand(@rl.screen.h)
      parallax = rand
      @stars << [randx,randy, parallax]
    end
  end
  
  def simulate_time_passage
    ship = @rl.repository.universe.player.start_ship
    ship.phased = true
    time = rand(10)
    while time > 0
      time -= 0.2
      update(0.2)
    end
    ship.phased = false
  end
  
  def spawn(fleet)
    active = fleet.dup
    @sector.active_fleets << active
    
    add_ai_fleet(active)
  end
  
  def update(delay)
    @played = true
    x = @player_sprite.model.x
    y = @player_sprite.model.y

    unless $edit_mode

      # Update all the sprites
      @sprites.dup.each do | sprite |
        sprite.update(delay)
        @sprites.delete(sprite) unless sprite.alive
      end

      update_stars(x,y)
      
      update_spawn(delay)
      
      # Controller updates
      @controllers.dup.each do |cont|
        cont.update(delay)
        update_jumping(cont)
        @controllers.delete(cont) unless cont.model.alive
      end
      
      @fleet_controllers.dup.each do | cont |
        cont.update(delay)
        update_jumping(cont)
        @fleet_controllers.delete(cont) unless cont.alive
      end
      
      # Fleet updates
      @sector.active_fleets.dup.each do |fleet|
        fleet.update(delay)
        if fleet.ships.empty?
          fleet.kill_fleet(@sector)
          
        end
      end
      
      # Projectile culling
      @sector.projectiles.dup.each do | proj |
        @sector.projectiles.delete(proj) unless proj.alive
      end

      # Player culling!
      unless @player_ship.alive
        gameover = GameOverState.new(self)
        @driver.replace(gameover)
      end
      
      @target_ship.ship = @player_ship.target
     
      handle_controls(delay)
    else
      # TODO: On faster or slower machines, the scrolling will vary.
      if @keyStatus[:up]
        @player_sprite.model.y -= SCROLL_SPEED
      elsif @keyStatus[:down]
        @player_sprite.model.y += SCROLL_SPEED
      end
      
      if @keyStatus[:left]
        @player_sprite.model.x -= SCROLL_SPEED
      elsif @keyStatus[:right]
        @player_sprite.model.x += SCROLL_SPEED
      end
  
      update_stars(x,y)
    end
  end
  
  def update_jumping(controller)
    if controller == @player_controller
      if @player_controller.model.jump_ready
        player_jump
      elsif @player_controller.model.jumping
        jump_in_progress(true)
      else
        jump_in_progress(false)
      end
    end
  end

  # Checks to see if it's time to spawn something in
  def update_spawn(delay)
    @spawn_delay += delay
    if @spawn_delay > 1.0
      @spawn_delay -= 1.0
      # It's time, see who's on the roster
      @sector.potential_fleets.each do | fleet |
        if rand < fleet.spawn_chance
          if fleet.unique
            if @sector.active_fleets.detect { |f| f.base_tag == fleet.tag } ||
               @sector.killed_fleets.detect { |f| f.base_tag == fleet.tag }
              return 
            end
          end
          # Spawn it!
          spawn(fleet)
        end
      end
    end
  end

  # Moves the stars around by how much the
  # center moved; called only in non-edit mode.
  # x and y is the position of the center before the update.
  def update_stars(x,y)
    new_x = @player_sprite.model.x
    new_y = @player_sprite.model.y
    dx = x - new_x
    dy = y - new_y
    @stars.each do | star |
      parallax = star[2]
      scaled_dx = dx * parallax
      scaled_dy = dy * parallax
      star[0] = star[0] + scaled_dx
      if star[0] < 0
        star[0] = @rl.screen.w
        star[1] = rand(@rl.screen.h)
      elsif star[0] > @rl.screen.w
        star[0] = 0
        star[1] = rand(@rl.screen.h)
      end  
      star[1] = star[1] + scaled_dy
      if star[1] < 0
        star[1] = @rl.screen.h
        star[0] = rand(@rl.screen.w)
      elsif star[1] > @rl.screen.h
        star[1] = 0
        star[0] = rand(@rl.screen.w)
      end  
    end
  end
  
  def view_info
    ship = @rl.repository.universe.player.start_ship
    sis = ShipInfoState.new(@driver,ship)
    callcc do | cont |
      @continue = cont
      @driver << sis
    end
    @player_controller.controls.reset
  end
  
end

# Displays info about the whole ship
class ShipInfoState < DataActionDialog
  
  def initialize(driver, ship)
    super(driver)
    @rl = ResourceLocator.instance
    @ship = ship
  end
  
  def is_player_ship?
    return @ship == @rl.repository.universe.player.start_ship
  end
  
  def layout_actions
    
    layout_action_item("Cargo") { self.show_cargo }
    layout_action_item("Addons") { self.show_addons }
    layout_action_item("Weapons") { self.show_weapons }
    layout_action_item("Missions") { self.show_missions } if is_player_ship?
    
  end
  
  def layout_data
    @title = Label.new("Ship info")
    layout_data_item(@title)
    layout_data_item(Label.new(" ")) # Vertical space
    
    @shipInfo = Label.new("TODO: Display some stats about the ship here.")
    layout_data_item(@shipInfo)
  end
  
  def show_addons
    transition_with(ShipAddonAdapter.new(@ship),"Addons")  
  end
  
  def show_cargo
    transition_with(ShipCargoAdapter.new(@ship),"Cargo on Board")
  end
  
  def show_missions
    player = @rl.repository.universe.player
    sis = ShipPartViewer.new(@driver,PlayerMissionAdapter.new(player))
    sis.title_text = "Missions"
    sis.allow_jettison = false
    @driver << sis
  end
  
  def show_weapons
    transition_with(ShipWeaponAdapter.new(@ship),"Weapons Available")
  end

  def transition_with(adapter, title=nil)
    sis = ShipPartViewer.new(@driver,adapter)
    if title
      sis.title_text = title
    end
    @driver << sis
  end
  
end


# This displays a white background, and manages the changeover to the new
# SectorState.
class JumpingState < Opal::State
  
  def initialize(destination, driver, source_state)
    super(driver)
    @sector = destination
    @source_state = source_state
  end
  
  def draw(screen)
    screen.fill( Rubygame::Color[:white] )
  end
  
  def do_jump
    rl = ResourceLocator.instance
    uni = rl.repository.universe
    uni.player.start_sector = @sector
    
    vec = random_spot(KuiSector::JUMPIN_DISTANCE)
    ship = uni.player.start_ship
    ship.x = vec.x
    ship.y = vec.y
    ship.facing = -vec.unit
    ship.velocity.angle = ship.facing.angle
    ship.target = nil
    
    dest_state = SectorState.new(@sector, @driver)
  
    dest_state.simulate_time_passage
    dest_state.radar.scale = @source_state.radar.scale
    rl.visual_log << "Arrived in #{@sector.name}"
    
    @driver.replace(dest_state)
  end
  
  def update(delay)
    do_jump  
  end
  
end