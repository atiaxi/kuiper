require 'engine'
require 'base'

include Opal

class MiniBuilder < CompositeSprite
  include Colorable
  include Waker
  
  attr_reader :items
  attr_reader :label
  
  # Provide an Adapter class to add/remove items
  def initialize(driver,adapt, title="")
    super()
    @driver = driver
    @bgcolor = [ 0, 0, 255 ]
    @border = [ 128,128,128 ]
    @adapter = adapt
    @spacing = 2
    @rl = ResourceLocator.instance
    self.label = title # Calls refresh
  end
  
  def add_item(item)
    @adapter.add_item(item)
    refresh
  end
  
  # Callback for the button
  def add_item_callback
    left = @adapter
    right = RepositoryAdapter.new(@adapter.constraint)
    builder = BuilderDialog.new(@driver, left, right)
    @driver << builder
  end
  
  def draw(screen)
    screen.fill( @bgcolor, @rect )
    screen.draw_box( @rect.topleft, @rect.bottomright, @border)
    super
  end
  
  def edit_item
    if @list.chosen
      object = @list.chosen
      editorClass = PropertiesDialog.editor_for(@adapter.constraint)
      editor = editorClass.new(object, @driver)
      callcc do | cont |
        @driver << editor
        @continue = cont
      end
      refresh
    end
  end
  
  def label=(text)
    @label = text
    refresh
  end
  
  def new_item
    object = @adapter.constraint.new
    editorClass = PropertiesDialog.editor_for(@adapter.constraint)
    editor = editorClass.new(object, @driver)
    callcc do | cont |
      @driver << editor
      @continue = cont
    end
    
    if editor.accepted && editor.object.playable?
      add_item(editor.object)
    else
      @rl.repository.delete(editor.object)
    end
    
  end
  
  def refresh
    self.clear
    y = @rect.top + @spacing
    x = @rect.left + @spacing
    right = @rect.right - @spacing
    
    @labelLabel = Label.new(@label)
    @labelLabel.rect.y = y
    @labelLabel.rect.right = right
    self << @labelLabel
    leftmost = @labelLabel.rect.x
    
    @addButton = Button.new('Add') { self.add_item_callback }
    @addButton.rect.y = @labelLabel.rect.bottom + @spacing
    @addButton.rect.right = right
    self << @addButton
    
    @newButton = Button.new('New') { self.new_item }
    @newButton.rect.y = @addButton.rect.y
    @newButton.rect.right = @addButton.rect.left - @spacing
    self << @newButton
    leftmost = @newButton.rect.x if @newButton.rect.x < leftmost
    
    @removeButton = Button.new('Remove') { self.remove_item }
    @removeButton.rect.y = @newButton.rect.bottom + @spacing
    @removeButton.rect.right = right
    self << @removeButton
    leftmost = @removeButton.rect.x if @removeButton.rect.x < leftmost
    
    @editButton = Button.new('Edit') { self.edit_item }
    @editButton.rect.y = @removeButton.rect.bottom + @spacing
    @editButton.rect.right = right
    self << @editButton
    leftmost = @editButton.rect.x if @editButton.rect.x < leftmost
  
    @list = ListBox.new

    buttonHeight = @editButton.rect.bottom - @labelLabel.rect.top + @spacing*2
    listHeight = @list.height(4)
    @rect.h = [buttonHeight,listHeight].max
    @list.rect.w = leftmost -@spacing - (@rect.x + @spacing)
    @list.rect.h = @rect.h - @spacing*2
    @list.displayBlock { |item| item.synopsis }
    @list.items = @adapter.items
    @list.translate_to(x,y)
    self << @list
  end
  
  def remove_item
    if @list.chosen
      @adapter.remove_item(@list.chosen) 
      refresh
    end
  end
  
  def setup_gui
    refresh
  end
  
end

class MiniChooser < CompositeSprite
  
  include Colorable
  include Waker
  
  attr_reader :symbol
  attr_accessor :num_chars
  
  def initialize(driver,obj,sym,constraint,title="")
    super()
    @driver = driver
    @symbol = sym
    @object = obj
    @bgcolor = [0, 0, 255]
    @border = [ 128, 128, 128 ]
    @spacing = 2
    @num_chars = 15
    @type = constraint
    @rl = ResourceLocator.instance
    self.label = title # Calls refresh
  end
  
  def draw(screen)
    screen.fill(@bgcolor, @rect)
    screen.draw_box(@rect.topleft, @rect.bottomright, @border)
    super
  end
  
  def label=(text)
    @label = text
    refresh
  end
  
  def object
    return 
  end
  
  def refresh
    self.clear
    y = @rect.top + @spacing
    right = @rect.right - @spacing
    
    @selectButton = Button.new('Choose') { self.select_item_callback }
    @selectButton.rect.y = y
    @selectButton.rect.right = right
    @selectButton.depth = -10
    right = @selectButton.rect.x
    
    @xButton = Button.new('X') { self.set_to(nil) }
    @xButton.rect.y = y
    @xButton.rect.right = right
    @xButton.depth = -10
    right = @xButton.rect.x
    
    @synopsLabel = Label.new(self.synopsis)
    synopsRect = @synopsLabel.rect
    synopsRect.w = @synopsLabel.length(@num_chars)
    synopsRect.centery = @xButton.rect.centery
    synopsRect.right = right - @spacing
    @synopsLabel.depth = -5
    
    @synopsBox = Box.new
    @synopsBox.bgcolor = [0, 0, 0]
    @synopsBox.border = [ 0, 0, 0]
    @synopsBox.rect = synopsRect.dup
    @synopsBox.rect.h = @xButton.rect.h
    @synopsBox.rect.y = y
    self << @synopsBox
    right = @synopsBox.rect.x - @spacing
    
    self << @synopsLabel
    
    @labelLabel = Label.new(@label)
    @labelLabel.rect.centery = @xButton.rect.centery
    @labelLabel.rect.right = right
    @labelLabel.depth = -10
    self << @labelLabel
    self << @selectButton
    self << @xButton
    
    @rect.h = @selectButton.rect.h + @spacing * 2
    @rect.w = @selectButton.rect.right - @labelLabel.rect.x + @spacing*2
  end

  def select_item_callback
    selector = KuiObjectSelector.new(@driver, @type)
    callcc do | cont |
      @driver << selector
      @continue = cont
    end
    
    if selector.chosen && selector.chosen.playable?
      set_to(selector.chosen)
    end
    
  end
  
  def set_to(value)
    mutator = ((@symbol.to_s) + "=").to_sym
    if @object
      @object.send(mutator, value)
    end
    refresh
  end
  
  def setup_gui
    refresh
  end
  
  def synopsis
    result = '<Nothing>'
    if @object
      child = @object.send(@symbol)
      result = child.synopsis if child
    end
    return result
  end
      
end

class ShipImageButton < Opal::ImageButton

  attr_writer :animating
  attr_accessor :rotation # Degrees / sec
  
  def initialize(filename=nil, &callback)
    @angle = 0.0
    @rotation = 90.0
    @animating = true
    super(filename,&callback)
    self.border = nil
  end

  def animating?
    return @animating
  end

  def image=(filename)
    super
    @raw_image = @image
    if @raw_image.w > 1
      frame_width = @raw_image.w / 6
      frame_height = @raw_image.h / 6
      @images = []
      (0...36).each do |frame|
        frame_x = frame % 6 * frame_width
        frame_y = frame / 6 * frame_height
        tmpimage = Rubygame::Surface.new( [frame_width, frame_height ])
        # Offsets because of the border that ImageButton gave us
        source = [frame_x, frame_y, frame_width, frame_height]
        tmpimage.fill( [0,255,0] )
        @raw_image.blit(tmpimage, [0,0], source)
        tmpimage.set_colorkey( [255,255, 0])
        @images << tmpimage
      end
      @rect.w = frame_width
      @rect.h = frame_height
      update_image
    end
  end
  
  def update(delay)
    if @animating
      @angle += @rotation * delay
      @angle -= 360.0 if @angle >= 360.0
      update_image
    end
  end
  
  def update_image
    frame = (@angle / 10).to_i
    @image = @images[frame]    
  end
end

class OmniChooser < CompositeSprite
  
  def initialize(driver,title="")
    super()
    @driver = driver
    @rl = ResourceLocator.instance
    @spacing = 3
    @resultsCallback = nil
    self.label = title # Calls refresh
  end
  
  def chosen
    @results.chosen
  end
  
  def constrain
    passing = Set.new
    classes = @types.chosen
    if classes && classes.size > 0
      selected = @rl.repository.everything_of_types(classes)
      passing = passing | selected
    end
    labels = @labels.chosen
    if labels && labels.size > 0
      if passing.empty?
        passing = @rl.repository.everything
      end
      labelSet = @rl.repository.everything_with_labels(labels)
      passing = labelSet & passing
    end
    
    @results.items = passing.to_a
    @resultsCallback.call if @resultsCallback
  end
  
  def label=(text)
    @label = text
    refresh
  end
  
  def onResultsChange(&callback)
    @resultsCallback = callback
  end
  
  def refresh
    self.clear
    y = @rect.top + @spacing
    x = @rect.left + @spacing
    w = @rect.w
    right = @rect.right - @spacing
    
    @labelLabel = Label.new(@label)
    @labelLabel.rect.y = y
    @labelLabel.rect.right = right
    self << @labelLabel
    
    bottom = @labelLabel.rect.bottom + @spacing
    
    @types = setup_types
    @types.rect.w = (@rect.w - @spacing*2) / 2
    @types.rect.h = @types.height(5)
    @types.translate_to(x,bottom)
    @types.multi = true
    @types.refresh
    @types.chooseCallback { self.constrain }
    self << @types
    
    @labels = setup_labels
    @labels.rect.w = (@rect.w - @spacing * 2)/2
    @labels.rect.h = @labels.height(5)
    @labels.translate_to(@types.rect.right + @spacing*2,bottom)
    @labels.multi = true
    @labels.refresh
    @labels.chooseCallback { self.constrain }
    self << @labels
    bottom = @labels.rect.bottom + @spacing
    
    @select_all = Button.new("All") { self.select_all }
    @select_all.rect.x = x
    @select_all.rect.bottom = @rect.bottom - @spacing
    self << @select_all
    
    @select_none = Button.new("None") { self.select_none }
    @select_none.rect.right = @rect.right - @spacing
    @select_none.rect.bottom = @select_all.rect.bottom
    self << @select_none
    
    leftover_h = @select_all.rect.y - bottom - @spacing
    
    @results = ListBox.new
    @results.items = []
    @results.multi = true
    if leftover_h > 0
      @results.rect.w = @rect.w - @spacing * 2
      @results.rect.h = leftover_h
      @results.translate_to(x,bottom)
    end
    @results.displayBlock { |item| item.synopsis }
    @results.chooseCallback { @resultsCallback.call if @resultsCallback }
    @results.refresh
    self << @results
  end
  
  def select_all
    @results.select_all
    @resultsCallback.call if @resultsCallback
  end
  
  def select_none
    @results.select_none
    @resultsCallback.call if @resultsCallback
  end
  
  def setup_labels
    result = ListBox.new
    result.items = @rl.repository.all_labels
    return result
  end
  
  def setup_types
    result = ListBox.new
    result.items = KuiObject.subclasses
    return result
  end
  
end
