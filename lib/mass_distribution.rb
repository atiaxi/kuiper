
require 'layout'

# The "mass distribution" system exists so that a scenario creator can rapidly
# put a number of standard items in a number of systems.  This makes it possible
# to, for instance, create a 'standard' defensive fleet for a faction and then
# make that fleet appear in every sector labeled with that faction.
class MassDistributor < Opal::State
  
  include Waker
  include Layout
  
  def initialize(driver)
    super(driver)
    @insetX ||= 25
    @insetY ||= 50
    @spacing ||= 3
    @rl = ResourceLocator.instance
    setup_waker
    initial_layout
    super(driver)
    setup_gui
  end
  
  def done
    @driver.pop
  end
  
  def setup_gui
    self.clear
    
    setup_layout
    
    half = (@mainRect.w - @spacing * 4) / 2
    most = 300
    
    @mainBox = Box.new
    @mainBox.rect = @mainRect
    self << @mainBox
    
    # Source 
    @source = OmniChooser.new(@driver,"Source")
    @source.rect.w = half
    @source.rect.h = most
    layout_field(@source)
    @source.refresh
    
    @done = Button.new("Done") { self.done }
    @done.rect.right = @mainRect.right - @spacing
    @done.rect.bottom = @mainRect.bottom - @spacing
    self << @done
  end
  
end