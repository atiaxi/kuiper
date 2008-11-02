require 'engine'

class SliderBox < Opal::CompositeSprite
  include Colorable
  
  ANCHOR_LEFT = 0
  ANCHOR_RIGHT = 1
  ANCHOR_TOP = 2
  ANCHOR_BOTTOM = 3
  
  attr_accessor :displacement
  
  STATE_HIDDEN = 0
  STATE_DISPLAYING = 1
  STATE_DISPLAYED = 2
  STATE_HIDING = 3
  
  attr_reader :state
  
  # 'anchor' is one of the ANCHOR_* constants above. 'where' is the pixel 
  # location to slide around, and slide_direction is +/-1 to indicate which way
  # to slide when showing.  'displacement' is where along the non-anchored axis the box
  # should be.
  def initialize(anchor, where, slide_direction, disp = 0)
    super()
    @rl = Opal::ResourceLocator.instance
    @bgcolor = Rubygame::Color[:blue]
    @border = Rubygame::Color[:white]
    @anchor = anchor
    @where = where
    @slide_direction = slide_direction
    @displacement = disp
    @slide_offset = 0
    @speed = 120
    
    setup_gui
    hide
  end
  
  def draw(screen)
    screen.fill( @bgcolor, @rect )
    screen.draw_box( @rect.topleft, @rect.bottomright, @border )
    super
  end
  
  # How far along the slide this has to go to be fully extended
  def extent
    if @anchor == ANCHOR_TOP || @anchor == ANCHOR_BOTTOM
      return  @rect.h
    else
      return @rect.w
    end
  end
  
  # Whether or not this is fully hidden
  def hidden?
    return true if @state == STATE_HIDDEN
    ext = extent
    case(@anchor)
    when ANCHOR_TOP
      return @slide_offset <= -ext
    when ANCHOR_LEFT
      return @slide_offset <= -ext
    when ANCHOR_BOTTOM
      return @slide_offset >= 0
    when ANCHOR_RIGHT
      return @slide_offset >= 0
    end
  end
  
  # Programatically hides this box, without going through any necessary states.
  def hide
    @state = STATE_HIDDEN
    
    if @anchor == ANCHOR_TOP || @anchor == ANCHOR_LEFT
      @slide_offset = extent * -@slide_direction - 1
    else
      @slide_offset = 0
    end
    setup_gui
  end
  
  # Subclasses should override this to place things in the slider, set its
  # rect w/h and then call up to this method, as this will set the rect x/y
  def setup_gui
    x = x_for_anchor(@anchor).to_i
    y = y_for_anchor(@anchor).to_i
    translate_to(x,y)
  end
  
  def show
    @state = STATE_DISPLAYED
    
    if @anchor == ANCHOR_TOP || @anchor == ANCHOR_LEFT
      @slide_offset = 0
    else
      @slide_offset = extent * @slide_direction - 1
    end
    setup_gui
  end
  
  # Whether or not this is fully showing
  def showing?
    return true if @state == STATE_DISPLAYED
    ext = extent
    case(@anchor)
    when ANCHOR_TOP
      return @slide_offset >= 0
    when ANCHOR_LEFT
      return @slide_offset >= 0
    when ANCHOR_BOTTOM
      return @slide_offset <= -ext
    when ANCHOR_RIGHT
      return @slide_offset <= -ext
    end
  end
  
  def start_hiding
    unless @state == STATE_HIDING || @state == STATE_HIDDEN
      @state = STATE_HIDING
    end
  end
  
  def start_showing
    unless @state == STATE_DISPLAYING || @state == STATE_DISPLAYED
      @state = STATE_DISPLAYING
    end
  end
  
  def update(delay)
    if @state == STATE_DISPLAYING
      update_displaying(delay)
    elsif @state == STATE_HIDING
      update_hiding(delay)
    end
    setup_gui
  end
  
  def update_displaying(delay)
    @slide_offset += delay * @speed * @slide_direction
    @state = STATE_DISPLAYED if showing?
  end
  
  def update_hiding(delay)
    @slide_offset -= delay * @speed * @slide_direction
    @state = STATE_HIDDEN if hidden?
  end
  
  def x_for_anchor(anchor)
    return @displacement if (anchor == ANCHOR_TOP || anchor == ANCHOR_BOTTOM)
    return @where + @slide_offset
  end
  
  def y_for_anchor(anchor)
    return @displacement if (anchor == ANCHOR_LEFT || anchor == ANCHOR_RIGHT)
    return @where + @slide_offset
  end
  
end

# Displays the contents of the log
class LogBox < SliderBox
  
  def initialize(anchor, where, slide_direction, disp=0,lines = 5)
    @lines = lines
    @labels = []
    @spacing = 3
    super(anchor,where,slide_direction,disp)
    #@bgcolor = [ 0, 0, 255, 128]
    setup_lines
  end
  
  def setup_lines
    y = @rect.y + @spacing
    x = @rect.x + @spacing
    w = @spacing * 2
    (0...@lines).each do 
      line = Label.new(" ")
      line.rect.x = x
      line.rect.y = y
      @labels << line
      self << line
      y += line.rect.h + @spacing
      w = line.rect.w + @spacing*2 if line.rect.w > w
    end
    @rect.h = y - @rect.y
  end
  
  def setup_gui
    log = ResourceLocator.instance.visual_log
    if log
      @labels.each_with_index do | label,index |
        text = log[-(index+1)]
        label.text = text if text
      end
    end
    super
  end
  
end

# Shows the user how close they are to jumping
class JumpBox < SliderBox
  
  def initialize(ship, anchor, where, slide_direction, disp=0)
    @explainLabel = nil
    @ship = ship
    @spacing = 3
    super(anchor,where,slide_direction,disp)
  end
  
  def setup_gui
    unless @explainLabel
      rl = ResourceLocator.instance
      itin = rl.repository.universe.player.start_ship.itinerary
      dest = itin[0]
      if dest
        @explainLabel = Label.new("Jumping to #{dest.name}")
      else
        @explainLabel = Label.new("Unable to jump, no destination")
      end
      @explainLabel.rect.x = @rect.x + @spacing
      @explainLabel.rect.y = @rect.y + @spacing
      self << @explainLabel
      
      @remainLabel = Label.new("%0.2f seconds remaining")
      @remainLabel.rect.x = @rect.x + @spacing * 2
      @remainLabel.rect.y = @explainLabel.rect.bottom + 3
      self << @remainLabel if dest
    end
    @rect.w = [ @explainLabel.rect.w + @spacing*2,
      @remainLabel.rect.w + @spacing*2 ].max
    @rect.h = @explainLabel.rect.h + @remainLabel.rect.h + @spacing*3
    super
  end
  
  def update(delay)
    remain = @ship.secs_to_jump - @ship.jumping_progress
    @remainLabel.text = sprintf("%0.2f seconds remaining", remain)
    super
  end
end

# Displays everything in the sector
class RadarBox < SliderBox
  
  ZOOM_SPEED = 2.5
  attr_reader :scale
  
  def initialize(sector_state, anchor, where, slide_direction, disp=0)
    @sector_state = sector_state
    @scale = 10.0
    @inverse_scale = 0.1
    super(anchor,where,slide_direction,disp)
    @bgcolor = Rubygame::Color[:black]
  end
  
  def draw(screen)
    screen.fill( @bgcolor, @rect )
    
    oldClip = screen.clip
    screen.clip = @rect
    @sector_state.sprites.each do | sprite |
      if sprite.respond_to?(:scaled_rect)
        rect = sprite.scaled_rect(@inverse_scale)
        rect.centerx += @rect.centerx
        rect.centery += @rect.centery
        color = sprite.radar_color
        screen.draw_circle_s( rect.center, [rect.w/2,rect.h/2].min, color)
      end
    end
    
    draw_center_indicator(screen)
    
    screen.clip = oldClip
    screen.draw_box( @rect.topleft, @rect.bottomright, @border)
  end
  
  def draw_center_indicator(screen)
    player_ship = @sector_state.player_ship
    hide_dist = [@rect.w,@rect.h].min
    pos = player_ship.pos
    if pos.magnitude/(@scale/2) >= hide_dist
      forward = pos.unit
      back = -forward
      pos = back * 10
      
      point = back * 30
      
      counter = forward * 5
      counter.angle -= 45.to_radians
      
      clock = forward * 5
      clock.angle += 45.to_radians
      
      center = @rect.center
      screen.draw_line( [ center[0] + pos.x,
        center[1] + pos.y ],
        [center[0]+point.x, center[1]+point.y],
        [0, 255, 0])
      
      displaced_point = [ center[0] + point.x, center[1]+point.y]
      screen.draw_line( displaced_point,
        [displaced_point[0]+counter.x,
         displaced_point[1]+counter.y],
        [0,255,0])
      
      screen.draw_line( displaced_point,
        [displaced_point[0]+clock.x,
         displaced_point[1]+clock.y],
        [0,255,0])
    end
  end
  
  def scale=(new_scale)
    @scale = new_scale
    @inverse_scale = 1.0 / new_scale
  end
  
  def setup_gui
    @rect.w = 150 if @rect.w == 0
    @rect.h = 150 if @rect.h == 0
    super
  end
  
  # Adjusts the scale (and inverse_scale) by the given amount * ZOOM_SPEED
  def zoom(delay)
    self.scale += delay * ZOOM_SPEED
  end
end

class ShipBox < SliderBox
  
  attr_accessor :ship
  attr_reader :suppress_owner
  
  def initialize(ship, anchor, where, slide_direction,disp=0)
    @nameLabel = nil
    @ship = ship
    @spacing = 3
    @suppress_owner = false
    super(anchor,where,slide_direction,disp)
  end
  
  def setup_gui
    unless @nameLabel
      @nameLabel = Label.new(' <No Target> ')
      @nameLabel.rect.x = @rect.x + @spacing
      @nameLabel.rect.y = @rect.y + @spacing
      self << @nameLabel
      
      @shieldsLabel = Label.new(" ")
      @shieldsLabel.rect.x = @rect.x + @spacing
      @shieldsLabel.rect.y = @nameLabel.rect.bottom + @spacing
      self << @shieldsLabel

      @armorLabel = Label.new(" ")
      @armorLabel.rect.x = @rect.x + @spacing
      @armorLabel.rect.y = @shieldsLabel.rect.bottom + @spacing
      self << @armorLabel
      
      @labelY = @armorLabel.rect.bottom + @spacing
      @bottom = @armorLabel
      
      @fuelLabel = Label.new(" ")
      @fuelLabel.rect.x = @rect.x + @spacing
      if @ship && @ship == @rl.repository.universe.player.start_ship
        @fuelLabel.rect.y = @labelY
        self << @fuelLabel
        @labelY = @fuelLabel.rect.bottom + @spacing
        @bottom = @fuelLabel
      end
      
      @ownerLabel = Label.new(" ")
      @ownerLabel.rect.x = @rect.x + @spacing
      if @ship != @rl.repository.universe.player.start_ship
        @ownerLabel.rect.y = @labelY
        self << @ownerLabel
        @labelY = @ownerLabel.rect.bottom + @spacing
        @bottom = @ownerLabel
      end
      
    end
    
    if @ship
      @nameLabel.text = @ship.name
      @shieldsLabel.text = "Shields: %.1f/%.1f" %
        [@ship.shields,@ship.max_shields]
      @armorLabel.text = "Armor: %.1f/%.1f" %
        [@ship.armor, @ship.max_armor]
      @fuelLabel.text = "Fuel: %.1f/%.1f (%d jumps)" %
        [@ship.fuel, @ship.max_fuel, @ship.fuel / @ship.fuel_per_jump]
      if @ship.owner
        player_org = @rl.repository.universe.player.org
        feelings = @ship.owner.symbol_for_attitude(player_org)
        @ownerLabel.text = "#{@ship.owner.name} (#{feelings})"
      end
      start_showing
    else
      @nameLabel.text = " No target "
      @shieldsLabel.text = " "
      @armorLabel.text = " "
      @ownerLabel.text = " "
      start_hiding
    end

    widths = [@nameLabel.rect.w, @shieldsLabel.rect.w, @armorLabel.rect.w,
      @fuelLabel.rect.w + @ownerLabel.rect.w]
    @rect.w = widths.max + @spacing * 2
    @rect.h = @bottom.rect.bottom - @nameLabel.rect.top + @spacing
    #@rect.h = @nameLabel.rect.top - @labelY

    super  
  end
  
end

class WeaponBox < SliderBox
  
  NO_WEAPON = "(No secondary weapon selected)"
  
  def initialize(ship, anchor, where, slide_direction, disp=0)
    @secondaryLabel = nil
    @ship = ship
    @spacing = 3
    super(anchor, where, slide_direction,disp)
  end
  
  def setup_gui
    unless @secondaryLabel
      @secondaryLabel = Label.new(NO_WEAPON)
      @secondaryLabel.rect.x = @rect.x + @spacing
      @secondaryLabel.rect.y = @rect.y + @spacing
      self << @secondaryLabel
      
      @statusLabel = Label.new(' ')
      @statusLabel.rect.x = @rect.x + @spacing
      @statusLabel.rect.y = @secondaryLabel.rect.bottom + @spacing
      self << @statusLabel
    end
    weapon = @ship.chosen_secondary
    if weapon
      @secondaryLabel.text = weapon.name
      @statusLabel.text = weapon.status
    else
      @secondaryLabel.text = NO_WEAPON
      @statusLabel.text = ' '
    end
    widths = [ @secondaryLabel.rect.w, @statusLabel.rect.w]
    @rect.w = widths.max + @spacing*2
    @rect.h = @secondaryLabel.rect.h + @statusLabel.rect.h + @spacing*3
    super
  end
end