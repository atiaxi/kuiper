
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
  
  def add
    return unless sanity_check
    @sources = @source.chosen
    @destinations = @dest.chosen
    @accessors = @slots.chosen.dup
    
    @destinations.each do | dest |      
      @sources.each do | src |
        @accessors.each do | sym |
          dest.add_child(sym,src)
        end
      end
    end
    
  end
  
  def done
    @driver.pop
  end
  
  def populateCommonSlots
    if @dest.chosen
      common = OmniSet.new
      @dest.chosen.each do | obj |
        common = common & obj.class.children.to_set
      end
      if common.class != OmniSet
        @slots.items = common.to_a
      else
        @slots.items = []
      end
    else
      @slots.items = []
    end
  end
  
  def remove
    
  end
  
  # True if selections are set in all the choosers
  def sanity_check
    error = nil
    unless @source.chosen && @source.chosen.size > 0
      error = "No source selected!"
    end
    
    unless @dest.chosen && @dest.chosen.size > 0
      error ||= "No destination objects selected!"
    end
    
    unless @slots.chosen && @slots.chosen.size > 0
      error ||= "No slots selected!"
    end
    
    if error
      @results.text = error
      return false
    end
    
    return true
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
    
    # Destination
    @dest = OmniChooser.new(@driver, "Destination")
    @dest.rect.w = half
    @dest.rect.h = most
    layout_child(@dest)
    @dest.refresh
    @dest.onResultsChange do
      populateCommonSlots
    end
    
    # Everything else
    common = Label.new("Affect these slots")
    layout_field(common)
    
    @slots = ListBox.new()
    @slots.rect.w = half
    @slots.rect.h = 100
    @slots.items = []
    @slots.multi = true
    layout_field(@slots)
    
    addButton = Button.new("Add") { self.add }
    layout_field(addButton)
    removeButton = Button.new("Remove") { self.remove }
    remove.rect.x = addButton.rect.right + @spacing
    remove.rect.y = addButton.rect.y
    self << remove
    
    @results = MultiLineLabel.new
    @results.rect.w = half
    @results.rect.h = 100
    @results.text = "No actions performed"
    layout_child(@results)
    
    @done = Button.new("Done") { self.done }
    @done.rect.right = @mainRect.right - @spacing
    @done.rect.bottom = @mainRect.bottom - @spacing
    self << @done
  end
  
end