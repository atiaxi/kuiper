

require 'options'
require 'editor'
require 'engine'

include Opal

# Screen for displaying all the options available, and letting the user
# change them
class OptionsScreen < PropertiesDialog
  
  def self.handles?(kuiobject)
    return false
  end
  
  def initialize(options, driver)
    super(options,driver)
    @options = options
  end
  
  def activate
    @continue.call if @continue
    super
  end

  def capture_event(control)
    ecd = EventCaptureDialog.new(control, @driver)
    old_control = control
    callcc do |cont|
      @driver << ecd
      @continue = cont
    end
    
    if (old_control != ecd.chosen) && ecd.chosen
      dex = @options.controls.index(old_control)
      @options.controls[dex] = ecd.chosen
      @options.save
    end
    setup_gui
  end
  
  # Because this isn't a proper KuiObject dialog, we have to get fancier.
  # Fields are now the individual ship controls.
  def layout_fields
    @options.controls.each do | control |
      label = Label.new(control.name)
      label.rect.topleft = [@fieldX, @fieldY]
      
      button = Button.new(control.to_s) { self.capture_event(control) }
      button.rect.topleft = [ label.rect.right + @spacing, @fieldY ]
      
      # TODO: Like in the original, there's no column creation
      @fieldY = label.rect.bottom + @spacing
      
      self << label
      self << button
    end
  end
end

class EventCaptureDialog < Opal::State
  
  attr_accessor :ctrl, :chosen
  
  def initialize(control, driver)
    super(driver)
    @ctrl = control
    
    setup_gui
  end
  
  def raw(event)
    control = Control.from_event(event)
    if control
      if control.respond_to?(:dx)
        vec = Rubygame::Ftor.new(control.dx, control.dy)
        if vec.magnitude > 5
          vec.magnitude = 5
          control.dx = vec.x
          control.dy = vec.y
        elsif vec.magnitude < 5
          # So we don't accidentally register minor movements
          return
        end
      end
      if control.respond_to?(:sym)
        if control.sym == :escape
          @chosen = @ctrl
          @driver.pop
        end
      end
      control.name = @ctrl.name
      @chosen = control
      @driver.pop
    end
  end
  
  def setup_gui
    rl = ResourceLocator.instance
    
    scrRect = rl.screen_rect
    mainBox = Box.new
    
    nameLabel = Label.new(@ctrl.name)
    
    iscurrently = Label.new("is currently activated by: #{@ctrl.to_s}")
    explainLabel = Label.new("Perform the action you'd like to be associated " +
      "with this action")
    explainLabel2 = Label.new("(i.e. press the button, move the joystick, etc)")
    escape = Label.new("Or press escape to cancel")
    
    iscurrently.rect.center = scrRect.center
    nameLabel.rect.centerx = scrRect.centerx
    nameLabel.rect.bottom = iscurrently.rect.top - 3
    
    explainLabel.rect.centerx = scrRect.centerx
    explainLabel.rect.top = iscurrently.rect.bottom + 3
    
    explainLabel2.rect.centerx = scrRect.centerx
    explainLabel2.rect.top = explainLabel.rect.bottom + 3

    escape.rect.centerx = scrRect.centerx
    escape.rect.top = explainLabel2.rect.bottom + 3
    
    mainRect = Rubygame::Rect.new(explainLabel.rect.x - 3,
      nameLabel.rect.top - 3,
      explainLabel.rect.w + 6,
      escape.rect.bottom - nameLabel.rect.top + 6)
    mainBox.rect = mainRect
    
    self << mainBox
    self << explainLabel2
    self << explainLabel
    self << nameLabel
    self << iscurrently
    self << escape
  end
  
end