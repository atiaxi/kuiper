require 'engine'

# This is the base class of sprites which can
# be moved around another spot.  They depend
# only on their models having an x and y component
class TranslatableSprite < OpalSprite
  
  attr_reader :model
  
  # TranslatableSprite subclasses provide the view, but they need an underlying
  # model; at this level all we care is that they respond to :x and :y
  # center is the TranslatableSprite around which we're centered.  (Though it
  # doesn't have to be; it just has to respond to :model and :rect)
  # If nil, this sprite undergoes no translation and just uses whatever its
  # :rect is.  (Most useful for the sprite that's at the center)
  def initialize(model, center)
    super()
    @model = model
    @center = center
    @rect = Rubygame::Rect.new(0, 0, 0, 0)
    @depth = 0
  end
  
  # Whether or not this should be tested for collisions with projectiles
  def collidable?
    return true
  end
  
  def radar_color
    return Rubygame::Color[:white]
  end
  
  def rect
    return @rect if @center == nil # Self centered!
    dx = @model.x - @center.model.x
    dy = @model.y - @center.model.y
    
    screen_center_x, screen_center_y = @center.rect.center
    #w, h = @rect.size
    @rect.center = [ screen_center_x + dx, screen_center_y + dy]
    return @rect
  end
  
  # Returns a rectangle suitable for display on, say, a radar.
  # The x and y parts of the rectangle are offsets from center
  def scaled_rect(scale)
    rect unless @rect # Make sure we've initialized our rectangle
    scaled = @rect.dup
    scaled.w = (scaled.w * scale).to_i
    scaled.h = (scaled.h * scale).to_i
    scaled.w = 1 if scaled.w < 1
    scaled.h = 1 if scaled.h < 1
    scaled.centerx = 0
    scaled.centery = 0
    return scaled if @center == nil
    
    dx = (@model.x - @center.model.x)*scale
    dy = (@model.y - @center.model.y)*scale
    scaled.centerx = dx.to_i
    scaled.centery = dy.to_i
    return scaled
  end
  
  # Whether or not this is able to be targeted by the player.
  def targetable?
    return true
  end
  
  def update(delay)
    
  end

end

class InvisibleSprite < TranslatableSprite
  def initialize
    super(nil, nil)
    @image = Rubygame::Surface.new( [1, 1] )
    @image.fill( [ 0, 0, 0] )
    @image.set_colorkey( [0, 0, 0] )
    @rect.w = 1
    @rect.h = 1
    @model = Rubygame::Rect.new( [ 0, 0, 1, 1] )
  end
  
  # The only thing other ships require of our model is that it reports its
  # location via :x and :y, and Rect fills the bill!
  def model
    return @model
  end
end

class ShipSprite < TranslatableSprite
  
  attr_accessor :kill_on_jump
  attr_writer :targetable
  attr_writer :collidable
  
  def initialize(ship, center)
    super
    @radar_color = Rubygame::Color[:blue]
    @kill_on_jump = true
    @rl = ResourceLocator.instance
    @raw_image = @rl.image_for(ship.image_filename)
    prepare_frames
    @targetable = true
    @collidable = true
  end
  
  def collidable?
    return @collidable
  end
  
  def draw(screen)
    super
    if @model.respond_to?(:jumping) and @model.jumping
      percent = @model.jumping_progress / @model.secs_to_jump.to_f
      w = (@rect.w / 2) * percent
      rgba = [255, 255, 255, percent*255]
      screen.draw_circle_s(@rect.center, w, rgba)
    end
  end
  
  def image
    frame = @model.angle.to_i / 10
    return @images[frame]
  end
  
  def prepare_frames
    @images = []
    frame_width = @raw_image.w / 6
    frame_height = @raw_image.h / 6
    @images = []
    (0...36).each do |frame|
      frame_x = frame % 6 * frame_width
      frame_y = frame / 6 * frame_height
      tmpimage = Rubygame::Surface.new( [frame_width, frame_height ])
      # Offsets because of the border that ImageButton gave us
      source = [frame_x, frame_y, frame_width, frame_height]
      tmpimage.fill(@raw_image.colorkey)
      @raw_image.blit(tmpimage, [0,0], source)
      tmpimage.set_colorkey( @raw_image.colorkey )
      @images << tmpimage
    end
    @rect.w = frame_width
    @rect.h = frame_height
  end
  
  # If our model is targeting the player, we're red, otherwise we're our
  # default color
  def radar_color
    player_ship = @rl.repository.universe.player.start_ship
    if player_ship.target.equal?(@model)
      return Rubygame::Color[:white]
    elsif @model.target.equal?(player_ship)
      return Rubygame::Color[:red]
    end
    return @radar_color
  end
  
  # Every targetable sprite is required to have a radius for collision detection
  def radius
    return [@rect.w,@rect.h].max / 2
  end

  # Debugging override
  def rect
    return @rect if @center == nil # Self centered!
    dx = @model.x - @center.model.x
    dy = @model.y - @center.model.y
    
    screen_center_x, screen_center_y = @center.rect.center
    #w, h = @rect.size
    @rect.center = [ screen_center_x + dx, screen_center_y + dy]
    return @rect
  end
  
  def targetable?
    return @targetable
  end
  
  def update(delay)
    @model.update(delay) unless @model.phased
    
    responds = @model.respond_to?(:jump_ready)
    
    if responds && @model.jump_ready && @kill_on_jump
      @model.alive = false
    end
    self.kill unless @model.alive
  end
end

class PlanetSprite < TranslatableSprite
  
  attr_writer :targetable
  
  def initialize(planet, center)
    super
    rl = ResourceLocator.instance
    @image = rl.image_for(planet.image_filename)
    @rect.w = @image.w
    @rect.h = @image.h
    @targetable = false
  end
  
  def collidable?
    return false
  end
  
  def radar_color
    return Rubygame::Color[:orange]
  end
  
  def targetable?
    return @targetable
  end
  
  #def draw(screen)
  #  @image.blit(screen, @rect)
  #end
  
end

class PlayerSprite < ShipSprite
  
  # The PlayerSprite alone knows its controller, mainly because it gets keyTyped
  # events and we need to pass them on
  attr_accessor :controller
  
  def initialize(ship)
    super(ship,nil)
    @kill_on_jump = false
    @depth = SectorState::DEPTH_PLAYER
    @controller = nil

  end
  
  def keyTyped(event)
    @controller.keyTyped(event) if @controller
  end
  
  def targetable?
    return false
  end
  
end

