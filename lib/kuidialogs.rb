
require 'dialogs'

include Opal

# Similar to PropertiesDialog only somewhat more general.
# Displays 'data' on the left (a ListBox of cargo, a planet description, etc)
# and 'actions' on the right (Buy, Sell, etc).
# (By default, this will be false, so subclases that don't care can mostly
#  ignore this)
class DataActionDialog < Opal::State
  
  include Waker
  
  def initialize(driver)
    @continue = nil
    super(driver)

    @rl = ResourceLocator.instance
    
    @insetX ||= 50
    @insetY ||= 100
    @spacing ||= 3
    setup_waker
    setup_gui
  end
  
  # The default reaction to the 'done' button
  def done
    @driver.pop
  end
  
  # Adds the given widget to the actions column
  def layout_action(widget)
    widget.rect.right = @actionX
    widget.rect.y = @actionY
    @actionY += widget.rect.h + @spacing
    self << widget
  end
  
  # Creates a button in the actions column for the given string and callback.
  def layout_action_item(label, &callback)
    button = Button.new(label)
    button.callback = callback
    
    layout_action(button)
    return button
  end
  
  # Subclasses should override this to put the items that go on the right
  def layout_actions
    
  end
  
  # Subclasses should override this to put the items that go on the left
  def layout_data
    
  end
  
  # Puts an individual component in the data column on the left. It increases
  # the current Y offset by the height of the component, so beware using things
  # like MultiLineLabel without its text set.
  def layout_data_item(component)
    component.translate_to(@dataX, @dataY)
    @dataY += component.rect.h + @spacing
    self << component
    return component
  end
  
  def setup_gui
    self.clear
    @mainRect = Rubygame::Rect.new( @insetX, @insetY,
      @rl.screen.w-@insetX*2, @rl.screen.h-@insetY*2)
    mainBox = Box.new
    mainBox.rect = @mainRect
    self << mainBox
    
    @dataX = @mainRect.x + @spacing
    @actionX = @mainRect.right - @spacing
    @dataY = @actionY = (@mainRect.top + @spacing *2)
    
    @done = Button.new("Done") { self.done }
    @done.rect.bottomright = [ @mainRect.right - @spacing,
      @mainRect.bottom - @spacing ]
    self << @done
    
    layout_data
    layout_actions
    
  end
  
end

class BuilderDialog < Opal::State
  
  include Waker
  include Layout
  
  attr_reader :title
  
  def initialize(driver, leftAdapter, rightAdapter)

    @leftAdapter = leftAdapter
    @rightAdapter = rightAdapter
    @insetX ||= 25
    @insetY ||= 50
    @spacing ||= 3
    @title = "Building"
    @rl = ResourceLocator.instance
    setup_waker
    initial_layout
    super(driver)
    setup_gui
  end
  
  # Called when, in edit mode, the player presses 'add'
  def add_item
    callcc do | cont |
      @driver << @selector # Will re-set gui on activation
      @continue = cont
    end
    
    if @selector.chosen && @selector.chosen.playable?
      @right.add_item(@selector.chosen)
      setup_gui
    end
  end
  
  def done
    @driver.pop
  end
  
  # Called when, in edit mode, the player pressed 'edit'
  def edit_item
    if @rightList.chosen
      editorClass = PropertiesDialog.editor_for(@rightList.chosen.class)
      editor = editorClass.new(@rightList.chosen, @driver)
      callcc do | cont |
        @driver << editor
        @continue = cont
      end
      setup_gui
    end
  end
  
  def move_to_left(number=1)
    chosen = @rightList.chosen
    if chosen
      @leftAdapter.add_item(chosen,number)
      @rightAdapter.remove_item(chosen,number)
    end
    setup_gui
  end
  
  def move_to_right(number=1)
    chosen = @leftList.chosen
    if chosen
      @leftAdapter.remove_item(chosen,number)
      @rightAdapter.add_item(chosen,number)
    end
    setup_gui
  end
 
  def setup_gui
    self.clear
    @infoLabel = Label.new(@title)
    @infoLabel.rect.topleft = [ @insetX + @spacing, @insetY + @spacing ]
    self << @infoLabel
    
    setup_layout
    
    @mainBox = Box.new
    @mainBox.rect = @mainRect
    self << @mainBox
    
    @bottomPadding ||= 100
    @rectHeight ||= @mainRect.h - @bottomPadding
    
    oldLeftSelected = nil
    oldLeftSelected = @leftList.chosen if @leftList
    oldRightSelected = nil
    oldRightSelected = @rightList.chosen if @rightList
    
    @leftText ||= "Moving To"
    layout_field(Label.new(@leftText))
    
    @leftList = ListBox.new
    @leftList.rect.w = @mainRect.w / 3
    @leftList.rect.h = @rectHeight
    @leftList.displayBlock { |item| item.synopsis }
    @leftList.items = @leftAdapter.items
    @leftList.chosen = oldLeftSelected
    layout_field(@leftList)
    
    @rightText ||= "Moving From"
    layout_child(Label.new(@rightText))
    @rightList = ListBox.new
    @rightList.rect.w = @mainRect.w / 3
    @rightList.rect.h = @rectHeight
    @rightList.displayBlock { |item| item.synopsis }
    @rightList.items = @rightAdapter.items
    @rightList.chosen = oldRightSelected
    layout_child(@rightList)
    
    @moveToLeft = Button.new("<<") { self.move_to_left }
    @moveToLeft.rect.centerx = @mainRect.centerx
    @moveToLeft.rect.centery = @mainRect.centery - 15
    self << @moveToLeft
    
    @moveToRight = Button.new(">>") { self.move_to_right }
    @moveToRight.rect.centerx = @mainRect.centerx
    @moveToRight.rect.centery = @mainRect.centery + 15
    self << @moveToRight
    
    @done = Button.new("Done") { self.done }
    @done.rect.bottomright = [ @mainRect.right - @spacing,
      @mainRect.bottom - @spacing ]
    self << @done
      
    if $edit_mode
      @edit = Button.new("Edit") { self.edit_item }
      @edit.rect.right = @done.rect.left - @spacing
      @edit.rect.y = @done.rect.y
      self << @edit
    end
    
  end
  
  def title=(text)
    @title = text
    setup_gui
  end
  
end

class ImageSelectorDialog < ResourceDialog
  
  def initialize(driver,is_ship_preview = false)
    @ship = is_ship_preview
    super(driver)
    self.title = "Choose an image"
  end
  
  def action
    @driver.pop
  end
  
  def click_image
    if @file_list.chosen
      @chosen = @file_list.chosen
      
      @imageButton.image = @chosen
      @imageButton.max_size = [@width/2 - 6, @mainRect.height - 6]
    end
  end
  
  def setup_gui
    rl = ResourceLocator.instance
    
    scrRect = rl.screen_rect
    @width = scrRect.w - 50
    @half = scrRect.w / 2
    super
    
    @file_list.chooseCallback do
      click_image
    end
    
    left = @half + 3
    top = @mainRect.top + 3
    @imageButton = ImageButton.new
    @imageButton.rect.x = left
    @imageButton.rect.y = top
    self << @imageButton
  end
  
  def setup_files
    rl = ResourceLocator.instance
    # As of rubygame 2.2.0, these are the extensions it supported
    exts = [ '.bmp', '.gif','.jpg','.lbm','.pcx','.png','.pnm','.tga','.tif',
        '.xcf','.xpm' ]
    images = rl.visible_files.select do | filename |
      exts.index(File.extname(filename).downcase) != nil
    end
    @file_list.items = images.sort
  end
  
end

class InfoDialog < DataActionDialog
  
  attr_reader :result
  
  def initialize(driver, message, choices = [ ['Ok', true] ])
    @insetX ||= 150
    @insetY ||= 150
    @message = message
    @choices = choices
    @result = nil
    super(driver)
  end
  
  def choices=(anArray)
    @choices = anArray
    setup_gui
  end
  
  def layout_actions
    initial_y = @actionY
    @choices.each do | label,result |
      layout_action_item(label) do 
        @result = result
        self.done
      end
    end
    @action_height = @actionY - initial_y
  end
  
  def layout_data
    initial_y = @dataY
    message = MultiLineLabel.new
    message.rect.w = @mainRect.w - (@spacing * 2)
    message.text = @message
    layout_data_item(message)
    @data_height = @dataY - initial_y
  end
  
  def setup_gui
    super
    @done.visible = false
    @mainRect.h = [@data_height, @action_height].max + @spacing*2
  end
  
end

# Allows the editor to pick a specific KuiObject stored in the repository.
class KuiObjectSelector < ResourceDialog
  
  attr_reader :editor
  
  # The type here is the type of KuiObject to show.
  # The editor will be automatically determined by this type
  def initialize(driver, type)
    @rl = ResourceLocator.instance
    @type = type
    @editor = editor
    super(driver)
    self.title = "Choose"
  end
  
  def action
    @driver.pop
  end
  
  def activate
    @continue.call if @continue
    setup_gui
    super
  end
  
  def click_object
    if @file_list.chosen
      @chosen = @tags_to_items[@file_list.chosen]
      preview(@chosen)
    end
  end
  
  def edit_object
    if @chosen
      editorClass = PropertiesDialog.editor_for(@type)
      editor = editorClass.new(@chosen, @driver)
      callcc do | cont |
        @driver << editor
        @continue = cont
      end
      setup_gui
    end
  end
  
  def new_object
    object = @type.new
    editorClass = PropertiesDialog.editor_for(@type)
    editor = editorClass.new(object, @driver)
    callcc do | cont |
      @driver << editor
      @continue = cont
    end
    
    unless editor.object.playable? && editor.accepted
      @rl.repository.everything.delete(editor.object)
    end
    setup_gui
  end

  def setup_files
    @matches = @rl.repository.everything_of_type(@type)

    @tags_to_items = {}
    @file_list.items = @matches.collect do | entry |
      @tags_to_items[entry.tag] = entry
      entry.tag
    end
  end
  
  def setup_gui
    @chosen = nil
    scrRect = @rl.screen_rect
    @width = scrRect.w - 100
    @half = scrRect.w / 2
    super
    
    @file_list.chooseCallback { click_object }
    
    @new_object = Button.new("New") { new_object }
    @new_object.rect.right = @mainRect.right - @spacing
    @new_object.rect.bottom = @mainRect.bottom - @spacing
    self << @new_object
      
    @edit_object = Button.new("Edit") { edit_object }
    @edit_object.rect.right = @new_object.rect.left - @spacing
    @edit_object.rect.bottom = @new_object.rect.bottom
    self << @edit_object
    
    setup_preview
    
  end
  
  # Subclasses should override this to create whatever widgets they need to
  # preview whatever's selected.
  def setup_preview
    
  end
  
  # Subclasses should override this to change the preview widgets to reflect
  # the given object
  def preview(object)
    
  end
 
end

class MarketDialog < BuilderDialog
  
  def initialize(driver, leftAdapter, rightAdapter)
    super(driver,leftAdapter,rightAdapter)
  end
  
  def move_to_left
    chosen = @rightList.chosen
    if chosen
      amount = @amount.text.to_i
      if @leftAdapter.can_fit_item?(chosen,amount) &&
        @leftAdapter.can_afford_item?(chosen,amount)
        @leftAdapter.buy(chosen,amount)
        super(amount)
      end
    end
  end
  
  def move_to_right
    chosen = @leftList.chosen
    if chosen
      amount = @amount.text.to_i
      selling = @rightAdapter.items.detect { |item|
      puts "Item: #{item}, chosen; #{chosen} ===? #{item === chosen}"
      puts "Item tag: #{item.tag}, chosen tag: #{chosen.tag}"
      item === chosen }
      if selling
        player = @rl.repository.universe.player
        player.credits += amount * selling.price
        super(amount)
      end
    end
  end
  
  def preview(chosen)
    if chosen
      @description.text = chosen.description
      @description.rect.centerx = @mainRect.centerx
      @description.rect.bottom = @moveToLeft.rect.top - @spacing
  
      req_chosen = chosen
#     if @rightList.chosen
#      req_chosen = @rightList.chosen
#     end
  
      requires = @leftAdapter.requires
      require_array = []
      free_array = []
      requires.each do | str |
        value = req_chosen.send((str+"_required").to_sym)
        if value > 0
          require_array << "#{value} #{str}"
          free = @leftAdapter.amount_free(str)
          free_array << "#{free} #{str}"
        end
      end
      player = @rl.repository.universe.player
      
      require_array << "#{req_chosen.price} credits"
      requirements = require_array.join(",")
      @require.text = "(#{requirements} required)"
      @require.rect.top = @moveToRight.rect.bottom + @spacing
      
      free_array << "#{player.credits} credits"
      freequirements = free_array.join(",")
      
      @cred.text = "(#{freequirements} available)"
      @cred.rect.top = @require.rect.bottom

    end
  end
  
  def setup_gui
    @leftText = "On Board"
    @rightText = "For Sale"
    super
    @leftList.chooseCallback { self.preview(@leftList.chosen) }
    @rightList.chooseCallback { self.preview(@rightList.chosen) }
    
    buy = Label.new("Buy/sell this many at a time:")
    buy.rect.left = @leftList.rect.right + @spacing
    buy.rect.top = @leftList.rect.top
    self << buy
    @amount ||= InputField.new(1, 5)
    @amount.rect.left = buy.rect.right + @spacing
    @amount.rect.centery = buy.rect.centery
    self << @amount
    
    width = @rightList.rect.left - @leftList.rect.right - @spacing *2
    @description = MultiLineLabel.new
    @description.rect.w = width
    self << @description
    
    player = @rl.repository.universe.player
    
    @require = MultiLineLabel.new(" ")
    @require.rect.w = width
    @require.rect.top = @moveToRight.rect.bottom + @spacing
    @require.rect.centerx = @mainRect.centerx
    self << @require
    
    @cred = MultiLineLabel.new("(#{player.credits} credits available)")
    @cred.rect.w = width
    @cred.rect.top = @require.rect.bottom
    @cred.rect.centerx = @mainRect.centerx
    @cred.refresh
    self << @cred
    
    if @leftList.chosen
      preview(@leftList.chosen)
    elsif @rightList.chosen
      preview(@rightList.chosen)
    end
  end  
end

class ScenarioDialog < ResourceDialog
  
  def initialize(driver, extension = '.kui')
    @extension = extension
    super(driver)
    self.title = "Choose a Scenario"
  end
  
  def action
    # @chosen should have been set by clickFile
    @driver.pop
  end
  
  def clickFile
    rl = ResourceLocator.instance
    if @file_list.chosen
      filename = "#{@file_list.chosen}#{@extension}"
      @chosen = rl.path_for(filename)
      
      tmpniverse = Repository.new
      tmpniverse.add_from_file(@chosen)
      
      @name.text = tmpniverse.universe.name
      @desc.text = tmpniverse.universe.description
    end
  end
  
  def setup_gui
    rl = ResourceLocator.instance
    
    scrRect = rl.screen_rect
    @width = scrRect.w - 100
    @half = scrRect.w / 2
    super
    
    @file_list.chooseCallback do
      clickFile
    end
    
    left = @half + 3
    top = @mainRect.top + 3
    @name = Label.new("Module Name")
    @name.rect.x = left
    @name.rect.y = top
    self << @name
    
    @desc = MultiLineLabel.new
    @desc.rect.x = left
    @desc.rect.y = @name.rect.bottom + 3
    @desc.rect.w = @width / 2 - 4
    self << @desc

  end
  
  def setup_files
    rl = ResourceLocator.instance
    modules = rl.visible_files.select do |filename|
      File.extname(filename) == @extension
    end
    @modnames = modules.collect do | mod |
      File.basename(mod,@extension)
    end
    @file_list.items = @modnames.sort
  end
  
end

# Editor-specific ship choosing dialog; the one you get while playing the game
# will be a little different.
class ShipSelectorDialog < KuiObjectSelector
  def initialize(driver,blueprints=false)
    @rl = ResourceLocator.instance
    @blueprints = blueprints
    if blueprints
      type = KuiShipBlueprint
      editor = ShipBlueprintEditor
    else
      type = KuiShip
      editor = ShipEditor
    end
    super(driver, type)
    self.title = @blueprints ? "Choose a Blueprint" : "Choose a Ship"
  end
  
  def preview(object)
    if @blueprints
      file = @chosen.image_filename
    else
      print = @chosen.blueprint
      if print
        file = print.image_filename
      end
    end
    if file
      @imageButton.image = file
      h = @mainRect.h - @spacing * 3 - @action_button.rect.h
      w = @width / 2 - @spacing * 2
      @imageButton.max_size = [w,h]
    end
  end
  
  def setup_preview
    left = @half + @spacing
    top = @mainRect.top + @spacing
    @imageButton = ImageButton.new
    @imageButton.rect.x = left
    @imageButton.rect.y = top
    self << @imageButton
  end
  
end

class ShipPartViewer < DataActionDialog
  
  attr_reader :title_text
  attr_reader :allow_jettison
  
  def initialize(driver, adapter)
    @adapter = adapter
    @title_text = "Boring default"
    @allow_jettison = true
    super(driver)
  end
  
  def allow_jettison=(aBoolean)
    @allow_jettison = aBoolean
    setup_gui
  end
  
  def do_preview
    if @itemList.chosen
      item = @itemList.chosen
      @description.text = item.description
    end
  end

  # Subclasses are the ones that know how to do this
  def eject
    if @itemList.chosen
      @adapter.remove_item(@itemList.chosen)
    end
    setup_gui
  end

  def layout_actions
    if @allow_jettison
      @eject = layout_action_item("Jettison") { self.eject }
    end
  end
  
  def layout_data
    @title = Label.new(@title_text)
    layout_data_item(@title)
    
    full = @mainRect.w - (@spacing * 2)
    
    @itemList = ListBox.new
    @itemList.rect.w = full
    @itemList.rect.h = @mainRect.h / 2
    @itemList.displayBlock { | cargo | cargo.synopsis }
    @itemList.items = @adapter.items
    @itemList.chooseCallback { do_preview }
    @dataY += @done.rect.h # Should be the same as the 'jettison' button
    layout_data_item(@itemList)
    
    @description = MultiLineLabel.new
    @description.rect.w = full
    
    layout_data_item(@description)
  end
  
  def title_text=(string)
    @title_text = string
    @title.text = string
    setup_gui
  end

end

# Editor-specific Cargo choosing dialog, much like the ship one up there
class CargoSelectorDialog < KuiObjectSelector
  def initialize(driver, blueprints = false)
    @rl = ResourceLocator.instance
    @blueprints = blueprints
    if blueprints
      type = KuiCargoBlueprint
    else
      type = KuiCargo
    end
    super(driver, type)
    self.title = @blueprints ? "Choose a Blueprint" : "Choose Cargo"
    
  end
  
  def preview(object)
    object = object.blueprint unless @blueprints
    if object
      @price.text = "#{object.name}, #{object.base_price} each."
      @desc.text = object.description
    end
  end
  
  def setup_preview
    left = @half + @spacing
    top = @mainRect.top + @spacing
    
    @price = Label.new(' ')
    @price.rect.x = left
    @price.rect.y = top
    self << @price
    
    @desc = MultiLineLabel.new
    @desc.rect.x = left
    @desc.rect.y = @price.rect.bottom + @spacing
    @desc.rect.w = @width / 2 - (@spacing * 2)
    self << @desc
  end
end

# Dialog specifically to display our feelings toward other orgs
class FeelingsDialog < Opal::State
  
  def initialize(org, driver)
    @org = org
    
    @insetX = 10
    @insetY = 10
    @spacing = 3
    @rl = ResourceLocator.instance
    
    @feelings = @org.feelings.dup
    @orgs_to_widgets = {}
    
    super(driver)
    
  end
  
  def activate
    if @continue
      cont = @continue
      @continue = nil
      cont.call
    end
    setup_gui
  end
  
  def add_feelings
    kos = KuiObjectSelector.new(@driver, KuiOrg)
    callcc do | cont |
      @driver << kos
      @continue = cont
    end
    
    if kos.chosen && kos.chosen.playable?
      index = @feelings.index(kos.chosen)
      unless index # No dupes
        @feelings << KuiRelation.new(kos.chosen, @org.neutral)
      end
    end
    setup_gui
  end
  
  def apply
    @orgs_to_widgets.each do | org, widgets |
      input = widgets[0]
      relation = @feelings.detect { |rel| rel.target_org == org }
      if relation
        relation.feeling = input.text.to_i
      end
    end
    @org.feelings = @feelings
    self.cancel
  end
  
  def cancel
    @driver.pop
  end
  
  def layout_feeling(org, feeling)
    label = Label.new(org.tag)
    label.rect.topleft = [ @fieldX, @fieldY ]
    input = InputField.new(feeling, 10)
    input.rect.topleft = [ label.rect.right + @spacing, @fieldY ]
    
    column = input.rect.right + @spacing
    KuiOrg::LEVEL_NAMES.each_with_index do | name,index |
      setButton = Button.new(name) do
        sym = name.gsub(" ","_").downcase.to_sym
        value = @org.send(sym)
        input.text = value.to_s
      end
      setButton.rect.x = column
      setButton.rect.y = @fieldY
      column = setButton.rect.right + @spacing
      self << setButton
    end
    
    @fieldY = input.rect.bottom + @spacing
    self << label
    self << input
    @orgs_to_widgets[org] = [ input ]
  end
  
  def setup_gui
    self.clear
    
    @mainBox = Box.new
    @mainRect = Rubygame::Rect.new( @insetX, @insetY, 
      @rl.screen.w-@insetX*2, @rl.screen.h-@insetY*2)
    @mainBox.rect = @mainRect
    
    self << @mainBox
    
    infoLabel = Label.new("The following are the non-default feelings of "+
      "#{@org.name}:")
    infoLabel.rect.topleft = [ @insetX + @spacing, @insetY + @spacing ]
    self << infoLabel
    
    @fieldX = @insetX + @spacing
    @fieldY = infoLabel.rect.bottom + @spacing*2
    
    # This tests for > 1 because all orgs have fanatic devotion towards
    # themselves
    if @feelings.size > 1
      @feelings.each do | relation |
        org = relation.target_org
        feeling = relation.feeling
        layout_feeling(org,feeling) unless org == @org
      end
    else
      noDetailsLabel = Label.new("  (all feelings are defaults )  ")
      noDetailsLabel.rect.topleft = [ @fieldX, @fieldY ]
      @fieldY = noDetailsLabel.rect.bottom + @spacing
      self << noDetailsLabel
    end
    
    @fieldY += @spacing
    @moreFeelings = Button.new("Add new feelings") { self.add_feelings }
    
    @moreFeelings.rect.topleft = [ @fieldX, @fieldY ]
    self << @moreFeelings
    
    @apply = Button.new("Apply") { self.apply }
    @cancel = Button.new("Cancel") { self.cancel }
    
    w,h = @mainRect.bottomright
    @cancel.rect.bottomright = [ w - 3, h - 3 ]
    @apply.rect.bottomright = [ @cancel.rect.x - 3, @cancel.rect.bottom ]  
    
    self << @apply
    self << @cancel
  end
  
end