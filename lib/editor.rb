require 'engine'
require 'kuiobject'
require 'map'
require 'kuiwidgets'
require 'adapters'

module Layout
  
  attr_accessor :mainRect, :fieldX, :fieldRight
  
  def initial_layout
    @insetX = 10
    @insetY = 10
    @spacing = 3
    @fieldRight = @insetX + @spacing
    @rl = ResourceLocator.instance
  end
  
  def layout_child(sprite)
    x = @mainRect.right - @spacing - sprite.rect.w
    sprite.translate_to(x, @childY)
    self << sprite
    next_child(sprite)
  end
  
  # "Children" are any object this one contains.
  # Because we have no idea what type they are,
  # there's no way to automatically put editors here.
  # So subclasses should override this and put in
  # appropriate buttons/pictures.
  def layout_children
    
  end
  
  def layout_field(label,input=nil)
    label.translate_to(@fieldX, @fieldY)
    if input
      input.translate_to(label.rect.right + @spacing, @fieldY)
    
      w = input.rect.right - @fieldX
      @fieldY = input.rect.bottom + @spacing
    else
      w = label.rect.right - @fieldX
      @fieldY = label.rect.bottom + @spacing
    end
    
    if w > @fieldW
      @fieldW = w
      @fieldRight = @fieldX + w
    end
    
    self << label
    self << input if input
  end
  
  def layout_field_button(label,input,buttonText,&callback)
    label.translate_to(@fieldX, @fieldY)
    input.translate_to(label.rect.right + @spacing, @fieldY)
    button = Button.new(buttonText) { callback.call }
    button.translate_to(input.rect.right + @spacing, @fieldY)
    w = button.rect.right
    if w > @fieldW
      @fieldW = w
      @fieldRight = @fieldX + w
    end
    self << label
    self << input
    self << button
  end
  
  # "Fields" are things like integers, strings, booleans - things which end up
  # as attributes in the XML, rather than full-fledged children
  def layout_fields
    
  end
  
  def layout_image_child(text,filename,sizes=nil,kind=ImageButton,&callback)
    if filename
      @label = Label.new(text)
      layout_child(@label)
      
      @imageButton = kind.new(filename,&callback)
      if sizes
        @imageButton.max_size = sizes
      end
    else
      @imageButton = Button.new("Set Image",&callback)
    end  
    layout_child(@imageButton)
  end
  
  def layout_ship_image_child(text, filename, sizes=nil,&callback)
    layout_image_child(text,filename,sizes,ShipImageButton,&callback)
  end
  
   def layout_minibuilder_child(mb)
    mb.rect.w = @mainRect.right - @fieldRight - (@spacing * 2)
    mb.refresh
    layout_child(mb)
    @wakeup_widgets << mb if @wakeup_widgets
  end
  
  def layout_minibuilder_field(mb)
    mb.rect.w = @fieldW
    mb.rect.x = @mainRect.x + @spacing
    mb.rect.y = @fieldY
    mb.refresh
    @fieldY = mb.rect.bottom + @spacing
    self << mb
    @wakeup_widgets << mb if @wakeup_widgets
  end
  
  # Lays out this minibuilder as though it were a field, and taking up the
  # width of the editor.
  def layout_minibuilder_field_wide(mb)
    mb.rect.w = @mainRect.w - (@spacing * 2)
    mb.rect.x = @mainRect.x + @spacing
    mb.rect.y = @fieldY
    mb.refresh
    @fieldY = mb.rect.bottom + @spacing
    self << mb
    @wakeup_widgets << mb if @wakeup_widgets
  end
  
  def layout_minichooser_child(mc)
    mc.refresh
    layout_child(mc)
    @wakeup_widgets << mc if @wakeup_widgets
  end
  
  # Utility function to move the @childY
  def next_child(last_child)
    @childY =last_child.rect.bottom + @spacing
  end
  
  def setup_layout
    
    unless @mainRect
      @mainRect = Rubygame::Rect.new( @insetX, @insetY,
        @rl.screen.w-@insetX*2, @rl.screen.h-@insetY*2)
    end 
    
    @fieldX = @mainRect.x + @spacing unless @fieldX
    @fieldW = 0
    @childX = @mainRect.right
    if @infoLabel
      @fieldY = @childY = @topY = @infoLabel.rect.bottom + @spacing *2
    else
      @fieldY = @childY = @topY = @mainRect.y + @spacing
    end
    
  end
end

# Generic property editor.  Subclasses should
# override :layout_* to provide extra
# functionality
class PropertiesDialog < Opal::State

  include Layout
  include Waker

  attr_reader :accepted
  attr_reader :object

  def self.editor_for(kuiobj)
    result = self.subclasses(true).detect do |editor|
      editor.handles?(kuiobj)
    end
    return result || self
  end
  
  # Courtesy ruby-talk post 11740
  def self.inherited(subclass)
    if @subclasses
      @subclasses << subclass
    else
      @subclasses = [subclass]
    end
  end
  
  # All the direct subclases of this class.
  # if expand is true, all their subclasses (and so on)
  def self.subclasses(expand = false)
    @subclasses ||= []
    subs = []
    if expand
      subs = @subclasses.collect { |sub| sub.subclasses(true) }
      subs.flatten!
    end
    return @subclasses + subs
  end
  
  def initialize(kuiobj, driver)
    @continue = nil
    super(driver)
    @object = kuiobj
    initial_layout
    @stored_values = {}
    @accepted = false
    setup_waker
    #setup_gui
  end
  
  def apply
    @attr_to_field.each do | attr, field |
      setter = (attr.to_s + '=').to_sym
      @object.send(setter,field.text)
    end
    @enum_to_field.each do | enum, field |
      setter = (enum.to_s + '=').to_sym
      if field.chosen
        @object.send(setter, field.chosen)
      end
    end
    @bool_to_field.each do |attr, field |
      setter = (attr.to_s + '=').to_sym
      @object.send(setter,field.checked)
    end
    @accepted = true
    
    cancel
  end
  
  def cancel
    @driver.pop
  end
  
  def deactivate
    @attr_to_field.each do | attr, field |
      @stored_values[attr] = field.text
    end
   
    @enum_to_field.each do | enum, field |
      @stored_values[enum] = field.chosen
    end
    
    @bool_to_field.each do | bool, field |
      @stored_values[bool] = field.checked
    end
  end
  
  # Fields go in a column on the left, in
  # alphabetical order. Subclasses override this
  # if they need to do anything fancy.
  def layout_fields
    # Everything has a tag - or it BETTER!
    # Probably should refactor this or something.
    value = @stored_values[:tag] || @object.tag
    label = Label.new("Tag")
    tagInput = InputField.new(value,30)
    @attr_to_field[:tag] = tagInput
    layout_field_button(label,tagInput,"Auto") do
      tagInput.text = @rl.repository.generate_tag_for(@object)
    end
    @fieldY = tagInput.rect.bottom + @spacing    
    @object.class.attrs.sort.each do | attr |
      next if attr == :tag # We did tags ourselves
      display = true
      value = @stored_values[attr] || @object.send(attr)
      label = Label.new(attr.to_s)
      rows,cols = [0,0]
      size= @object.class.size_for(attr)
      if size
        rows,cols = size
        if rows > 1
          input = MultiLineInput.new(value)
          input.set_size(rows,cols)
        elsif rows == 0 || cols == 0
          display = false
        else
          input = InputField.new(value, cols)
        end
      else
        input = InputField.new(value,20)
      end
      
      # TODO: There's no next column creation.  Fix it if it becomes an issue.
      if display
        if rows > 1
          scroller = Scroller.new(input)
          scroller.translate_to(*input.rect.topleft)
          layout_field(label,scroller)
        else
          layout_field(label,input)
        end      
        @attr_to_field[attr] = input
      end
    end
    
    # Booleans
    @object.class.booleans.each do | attr |
      value = @stored_values[attr] || @object.send(attr)
      checkbox = CheckBox.new(attr.to_s,value)
      checkbox.rect.topleft = [ @fieldX, @fieldY ] 
      
      @fieldY = checkbox.rect.bottom + @spacing
      
      self << checkbox
      @bool_to_field[attr] = checkbox
    end
    
    # And now for the enums!
    @object.class.enumerations.each do | attr, valid |
      value = @stored_values[attr] || @object.send(attr)
      label = Label.new(attr.to_s)
      
      size = @object.class.size_for(attr)
      label.rect.topleft = [@fieldX, @fieldY]
      rows = size || valid.size
      
      input = ListBox.new
      input.rect.w = @mainRect.w / 2 - label.rect.w - @spacing * 3
      input.rect.h = input.height(rows)
      input.items = valid
      input.chosen = value
      
      input.translate_to(label.rect.right + @spacing, @fieldY)
      
      @fieldY = input.rect.bottom + @spacing
      self << label
      self << input
      @enum_to_field[attr] = input
      
    end
  end
    
  def setup_gui
    self.clear
    
    @infoLabel = Label.new("Inspecting")
    @infoLabel.rect.topleft = [ @insetX + @spacing, @insetY + @spacing ]
    self << @infoLabel
    
    setup_layout

    @mainBox = Box.new
    @mainBox.rect = @mainRect
    self << @mainBox
    
    @attr_to_field = {}
    @bool_to_field = {}
    @enum_to_field = {}
    
    layout_fields
    layout_children
    
    @apply = Button.new("Apply") { self.apply }
    @cancel = Button.new("Cancel") { self.cancel }
    
    w,h = @mainRect.bottomright
    @cancel.rect.bottomright = [ w - 3, h - 3 ]
    @apply.rect.bottomright = [ @cancel.rect.x - 3, @cancel.rect.bottom ]  
    
    self << @apply
    self << @cancel
  end
end


class FleetEditor < PropertiesDialog
  
  def self.handles?(type)
    return type == KuiFleet
  end
  
  def initialize(fleet, driver)
    @fleet = fleet
    super
  end
  
  def layout_children
    
    #@shipsButton = Button.new("Add/Remove Ships") { self.edit_ships }
    #layout_child(@shipsButton)
    
    @shipsBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@fleet.ships, KuiShip), "Ships")
    layout_minibuilder_child(@shipsBuilder)
    
    owned_text = @fleet.owner ? @fleet.owner.name : 'Nobody'
    @ownerButton = Button.new("Owned by #{owned_text}") { self.set_owner }
    layout_child(@ownerButton)
    
  end
  
  def set_owner
    kos = KuiObjectSelector.new(@driver, KuiOrg)
    callcc do | cont |
      @driver << kos
      @continue = cont
    end
    
    if kos.chosen && kos.chosen.playable?
      @fleet.owner = kos.chosen
      setup_gui
    end
  end
  
end


class OrgEditor < PropertiesDialog
  
  def self.handles?(type)
    return type == KuiOrg
  end
  
  def change_feelings
    fd = FeelingsDialog.new(@object, @driver)
    callcc do | cont |
      @driver << fd
      @continue = cont
    end
  end
  
  def layout_children
    
    @feelingsButton = Button.new("Change our feelings toward others") { 
      self.change_feelings 
    }
    layout_child(@feelingsButton)
    
  end
  
end

class PlayerEditor < PropertiesDialog
  def self.handles?(type)
    return type == KuiPlayer
  end
  
  def initialize(player, driver)
    @player = player
    super
  end
  
  def layout_children
    x = @mainRect.right - @spacing
    
    if @player.start_ship
      layout_ship_image_child("Start Ship",
        @player.start_ship.blueprint.image_filename) { self.set_start_ship }
        
    else
      layout_ship_image_child("Set Starting Ship", nil) { self.set_start_ship }
    end
    
    mc = MiniChooser.new(@driver, @player, :start_sector, KuiSector,
    'Start Sector:')
    layout_minichooser_child(mc)
  end
    
  def set_start_ship
    kos = ShipSelectorDialog.new(@driver)
    callcc do |cont| 
      @driver << kos
      @continue = cont
    end
    
    if kos.chosen
      @player.start_ship = kos.chosen
      setup_gui
    end
  end
  
end

class SectorEditor < PropertiesDialog
  
  def self.handles?(type)
    return type == KuiSector
  end
  
  def initialize(sector, driver)
    @sector = sector
    super
  end
  
  def layout_children
    x = @mainRect.right - @spacing
    @sectorButton = Button.new("Enter Sector") { self.enter_sector }
    @sectorButton.rect.topright = [ x, @childY ]
    
    self << @sectorButton
    next_child(@sectorButton)
    
    @fleetBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@sector.potential_fleets, KuiFleet), "Fleets")
    layout_minibuilder_child(@fleetBuilder)
    
    @missionBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@sector.plot, KuiMission),"Plot")
    layout_minibuilder_child(@missionBuilder)
  end
  
  def enter_sector
     @sector_state = SectorState.new(@sector, @driver)
     callcc do | cont | 
       @driver << @sector_state
       @continue = cont
     end
  end
end



class UniverseEditor < PropertiesDialog
  def self.handles?(type)
    return type == KuiUniverse
  end
  
  def initialize(universe, driver)
    @universe = universe
    super
  end
  
  def apply
    super
    
    # TODO: Check for empty names
    save_universe(@universe)
  end
  
  # Apply calls this to pop out of state; we'll
  # want to prompt with save first.
  def cancel
    # TODO: That thing I'm claiming to do in the comments
    super
  end
  
  def layout_children
    
    @playerButton = Button.new("Setup Player") { setup_player }
    layout_child(@playerButton)
    
    x = @mainRect.right - @spacing
    @mapButton = Button.new("Enter Map") { self.map }
    @mapButton.rect.topright = [ x, @childY ]
    
    self << @mapButton
    next_child(@mapButton)
     
  end
  
  def map
    mapstate = MapState.new(@driver)
    @driver << mapstate
  end

  def setup_gui
    super
    @apply.text = "Save"
    @cancel.text = "Quit"
  end
  
  def setup_player
    editor = PlayerEditor.new(@universe.player, @driver)
    @driver << editor
  end
    
end

require 'missioneditor'
require 'planeteditor'