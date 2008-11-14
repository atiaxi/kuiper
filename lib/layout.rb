
# Skeleton for a field/child based layout system
module Layout
  
  attr_accessor :mainRect, :fieldX, :fieldRight
  
  def initial_layout
    @insetX ||= 10
    @insetY ||= 10
    @spacing ||= 3
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
  # under the 'fields' child in the XML
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
