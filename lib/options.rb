require 'yaml'
require 'overrides'

# Holder class for every option in the game
class Options
  
  attr_accessor :filename
  attr_accessor :screen_size
  attr_accessor :fullscreen
  
  attr_reader :controls
  
  def self.from_file(fullpath)
    result = YAML::load_file(fullpath)
    result.filename = fullpath
    return result
  end
  
  def initialize(fullpath=nil)
    @filename = fullpath
    @screen_size = [ 800, 600 ]  
    @fullscreen = false  
    @controls = default_controls
  end
  
  # Note that these controls only apply to flying around, and not to editing
  # or once landed on a planet.
  def default_controls
    result = []
    result << KeyDownControl.new('Accelerate', Rubygame::K_UP)
    result << KeyDownControl.new('Slow', Rubygame::K_DOWN)
    result << KeyDownControl.new('Rotate Left', Rubygame::K_LEFT)
    result << KeyDownControl.new('Rotate Right', Rubygame::K_RIGHT)
    result << KeyDownControl.new('Main Menu', Rubygame::K_ESCAPE)
    result << KeyDownControl.new('Land', Rubygame::K_L)
    result << KeyDownControl.new('Map', Rubygame::K_M)
    result << KeyDownControl.new('Jump', Rubygame::K_J)
    result << KeyDownControl.new('View Info', Rubygame::K_I)
    result << KeyDownControl.new('Radar Zoom Out', Rubygame::K_MINUS)
    result << KeyDownControl.new("Radar Zoom In", Rubygame::K_PLUS )
    result << KeyDownControl.new("Fire Primary Weapons", Rubygame::K_SPACE)
    result << KeyDownControl.new("Next Target", Rubygame::K_TAB)
    result << KeyDownControl.new("Next Secondary Weapon", Rubygame::K_Q)
    result << KeyDownControl.new("Fire Secondary Weapon", Rubygame::K_F)
    result << KeyDownControl.new("Quicksave", Rubygame::K_F5)
    result << KeyDownControl.new("Nearest Hostile Target", Rubygame::K_R)
    return result
  end
  def save
    if @filename
      File.open(@filename,"w") do |f| 
        f.write(self.to_yaml)
      end
    end
  end
  
end

class Control
  
  attr_accessor :name
 
  def self.from_event(event)
    case(event)
    when Rubygame::KeyDownEvent
      return KeyDownControl.new('',event.key)
    when Rubygame::JoyAxisEvent
      return JoyAxisControl.new('',event.joynum, event.axis, event.value > 0)
    when Rubygame::JoyBallEvent
      return JoyBallControl.new('',event.joynum, event.ball, *event.rel)  
    when Rubygame::JoyDownEvent
      return JoyDownControl.new('',event.joynum, event.button )
    when Rubygame::JoyHatEvent
      return JoyHatControl.new('',event.joynum, event.hat, event.value)
    when Rubygame::MouseDownEvent
      return MouseDownControl.new('', event.button )
    when Rubygame::MouseMotionEvent
      return MouseMotionControl.new('', *event.rel)
    else
      return nil
    end
  end

  def initialize(name)
    @name = name
  end
  
  def ===(event)
    return false
  end
  
  # Each control is caused by an event (as determined by === ) and canceled by
  # one or more events.  (i.e. KeyDowns are canceled by an equal KeyUp).  This
  # tests for cancellations
  def canceled_by?(event)
    return false
  end

  def to_s
    return "Base Control class that should have been overridden"
  end
  
  def to_sym
     return @name.gsub(" ","_").downcase.to_sym
  end
  
end

# Control for the user pressing keys, probably
# the most common
class KeyDownControl < Control
  
  attr_accessor :sym
  
  def initialize(name, sym)
    super(name)
    @sym = sym
  end
  
  def ===(event)
    if event.class == Rubygame::KeyDownEvent
      return event.key == @sym
    end
    return false
  end
  
  def canceled_by?(event)
    return false unless event.class == Rubygame::KeyUpEvent
    return event.key == @sym
  end
  
  def to_s
    return "Key '#{@sym}' pressed"
  end
  
end

# A control which responds to joystick axis
# movement.  Right now it doesn't really
# understand how throttles work, but there's
# no way of differentiating them in SDL from
# other axes.
class JoyAxisControl < Control
  
  attr_accessor :stick, :axis, :positive
  
  # stick: The joystick number we're expecting
  # axis:  The axis number we're expecting
  # pos:   Whether the change we're looking for is positive
  def initialize(name, stick, axis, pos)
    super(name)
    @stick = stick
    @axis = axis
    @positive = pos
  end
  
  def ===(event)
    if event.class == Rubygame::JoyAxisEvent
      return false unless @stick == event.joynum
      return false unless @axis == event.axis
      if @positive
        return event.value > 0
      else
        return event.value < 0
      end
    end
    return false
  end
  
  def canceled_by?(event)
    return false unless event.class == Rubygame::JoyAxisEvent
    return false unless @stick == event.joynum
    return false unless @axis == event.axis
    return true if event.value == 0
    if @positive
      return event.value < 0
    else
      return event.value > 0
    end
  end
  
  def to_s
    pos = @positive ? "up" : "down"
    return "Joystick \##{@stick} axis \##{@axis} #{pos}"
  end
end

module RelativeMotion
  attr_accessor :dx, :dy

  # Unfortunately, relative motion's canceler would be lack of motion, but we
  # don't get events about that!  So we cancel if it's any other direction or
  # even the right direction but not strong enough, which should catch the 
  # slowing down proceeding a stop.
  def canceled_by_motion( rel )
    return !matches_motion(rel)
  end

  def direction_to_s
    xdir = ''
    ydir = ''
    if @dy > 0
      ydir = 'up'
    elsif @dy < 0
      ydir = 'down'
    end
    
    if @dx > 0
      xdir = 'right'
    elsif @dx < 0
      xdir = 'left'
    end

    return "#{ydir}#{xdir}"
  end
  
  def matches_motion( rel )
    other_dx, other_dy = rel
    
    x_result = false
    y_result = false
    
    if other_dx.abs >= @dx.abs
      return false if (other_dx.positive? != @dx.positive?)
      x_result = true
    end
    if other_dy.abs >= @dy.abs
      return false if (other_dy.positive? != @dy.positive?)
      y_result = true
    end
    return false if @dx.zero? != other_dx.zero?
    return false if @dy.zero? != other_dy.zero?
    
    return x_result | y_result
  end
end

# I've never even seen a Joystick with a trackball.
# Nontheless....
class JoyBallControl < Control
  attr_accessor :stick, :ball
  
  include RelativeMotion
  
  # stick: The joystick number
  # ball:  The trackball number
  # dx:    What movement in the X direction we're expecting.  If the absolute
  #        value of this is > 1, it's a threshold that the change must match or
  #        exceed.
  # dy:    Movement in Y direction to expect, same caveats as above
  def initialize(name, stick, ball, dx, dy)
    super(name)
    @stick = stick
    @ball = ball
    @dx = dx
    @dy = dy
  end
  
  def ===(event)
    if event.class == Rubygame::JoyBallEvent
      return false unless @stick == event.joynum
      return false unless @ball == event.ball
      return matches_motion(event.rel)
    end
    return false
  end

  def canceled_by?(event)
    return false unless event.class == Rubygame::JoyBallEvent
    return false unless @stick == event.joynum
    return false unless @ball == event.ball
    return canceled_by_motion(event.rel)  
  end
  
  def to_s
    dir = direction_to_s
    return "Joystick \##{@stick} ball \##{@ball} #{dir}"
  end
end

# Depressing sounding name, but I'm naming it after the event itself.
# Control for joystick buttons.
class JoyDownControl < Control
  attr_accessor :stick, :button
  
  def initialize(name, stick, button)
    super(name)
    @stick = stick
    @button = button
  end
  
  def canceled_by?(event)
    return false unless event.class == Rubygame::JoyUpEvent
    return false unless event.joynum == @stick
    return event.button == @button
  end
  
  def to_s
    return "Joystick \##{@stick} button \##{@button} pressed"
  end
  
  def ===(event)
    if event.class == Rubygame::JoyDownEvent
      return false unless event.joynum == @stick
      return event.button == @button
    end
    return false
  end
end

# Control for joystick POV hats
class JoyHatControl < Control
  attr_accessor :stick, :hat, :direction
  
  # stick: The joystick
  # hat:   The hat #
  # direction: One of the constants from Rubygame::JoyHatEvent
  def initialize(name, stick, hat, direction)
    super(name)
    @stick = stick
    @hat = hat
    @direction = direction
  end
  
  # Returning to center is a cancelling event for all directions
  def canceled_by?(event)
    return false unless event.class == Rubygame::JoyHatEvent
    return false unless @stick == event.joynum
    return false unless @hat == event.hat
    return event.value == Rubygame::HAT_CENTERED
  end
  
  def ===(event)
    if event.class == Rubygame::JoyHatEvent
      return false unless @stick == event.joynum
      return false unless @hat == event.hat
      return @direction == event.value
    end
    return false
  end
  
  def hat_direction_to_s
    xdir = ''
    ydir = ''
    if @direction & Rubygame::HAT_UP
      ydir = 'up'
    elsif @direction & Rubygame::HAT_DOWN
      ydir = 'down'
    end
    
    if @direction & Rubygame::HAT_LEFT
      xdir = 'left'
    elsif @direction & Rubygame::HAT_RIGHT
      xdir = 'right'
    end
    
    return "#{ydir}#{xdir}"
  end
  
  def to_s
    dir = hat_direction_to_s
    return "Joystick \##{@stick} POV \##{@hat} #{dir}"
  end
end

# Control for the user clicking buttons or using
# the wheelmouse
class MouseDownControl < Control
  
  attr_accessor :button
  
  # The only thing we care about mouse clicks is which button
  def initialize(name, button)
    super(name)
    @button = button
  end
  
  def ===(event)
    if event.class == Rubygame::MouseDownEvent
      return event.button == @button
    end
    return false
  end
  
  def canceled_by?(event)
    return false unless event.class == Rubygame::MouseUpEvent
    return event.button == @button
  end
  
  def to_s
    return @button
  end
end

class MouseMotionControl < Control
  
  include RelativeMotion
  
  # All we care about is relative motion.  See JoyBallControl
  def initialize(name, dx, dy)
    super(name)
    @dx = dx
    @dy = dy
  end
  
  def canceled_by?(event)
    return false unless event.class == Rubygame::MouseMotionEvent
    return canceled_by_motion(event.rel)
  end
  
  def ===(event)
    if event.class == Rubygame::MouseMotionEvent
      return matches_motion(event.rel)
    end
    return false
  end
  
  def to_s
    return "Mouse moves #{direction_to_s}"
  end
end