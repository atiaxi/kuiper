
module Opal

# Like a button, but with less overhead.
# Specifically for ListBoxes
class ListItem < Label
  attr_reader :selected

  # The parents will usually be a ListBox, but for the sake of future
  # implementing of radio buttons or something, the parent object just
  # has to support :choose
  def initialize(text, parent, min_width=0, size=12, font="freesansbold.ttf")
    @bgcolor = [0, 0, 0]
    @selected_color = [128,128,128]
    @parent = parent
    @min_width = min_width
    @selected = false
    super(text,size,font)
  end
  
  def click(x,y)
    @parent.choose(self)
  end
  
  def selected=(status)
    @selected = status
    refresh
  end
  
  def text=(string)
    string = string.to_s
    rendered_string = string
    @text_string = string
    rendered_string = ' ' if string.nil? || string.size == 0
    @txt_image = @font.render(rendered_string, true, @fgcolor)
    width = [ @min_width, @txt_image.w ].max
    @image = Rubygame::Surface.new( [width, @txt_image.h])
    @image.fill(@bgcolor) unless @selected
    @image.fill(@selected_color) if @selected
    @txt_image.blit(image, [0,0])
    @rect ||= Rubygame::Rect.new([0,0,0,0])
    @rect.size = [@image.w,@image.h]
  end
end

# Your typical single-select listbox
class ListBox < CompositeSprite
  include Colorable
  include Focusable

  attr_reader :items
  attr_reader :scroll
  attr_accessor :enabled
  
  attr_reader :multi

  WIDGET_DEPTH = -10

  def initialize()
    super
    @displayBlock = proc { |item| item.to_s }
    @bgcolor = [ 0, 0, 0]
    @border = [ 255, 255, 255]
    @items = []
    @scroll = 0
    @chosen = []
    @chooseCallback = nil
    @doubleChooseCallback = nil
    @spacing = 2
    @chosenAt = 0
    @lku = 0
    @enabled = true
    @multi = false
    
    # Because we fake double-clicking in listboxes, we need to know when the
    # last known update happened; this keeps track in a semi-coherent sort of
    # way.
    @lku = 0
  end

  # Set the callback for when an item on the list is selected.  Will call the
  # associated block with no arguments (use :chosen to get the currently 
  # selected item)
  def chooseCallback(&callback)
    @chooseCallback = callback
  end
  
  def chosen
    if @multi
      return @chosen
    else
      return @chosen
    end
  end
  
  def displayBlock(&display)
    @displayBlock = display
  end

  def doubleChooseCallback(&callback)
    @doubleChooseCallback = callback
  end

  def down
    self.scroll = @scroll + 1 unless @scroll == @items.size-1
  end
 
  def draw(screen)
    assert {@items != nil}
    screen.fill( @bgcolor, @rect )
    screen.draw_box( @rect.topleft, @rect.bottomright, @border)
    super
  end
  
  # Called when an item is actually clicked
  def choose(item)
    if @enabled
      oldChosen = self.chosen
      picked = @widgets_to_items[item]
      # If it's not in the widgets dict, it's an actual item
      picked = item unless picked
      
      if oldChosen == picked
        if @lku - @chosenAt < 1 # Double click time is 1 sec.
          @doubleChooseCallback.call if @doubleChooseCallback
        else
          @chosenAt = @lku # Reset the timer
        end
      else
        
        if @multi
         multi_select(picked)
       else
         self.chosen = picked
       end
        
        @chosenAt = @lku
        @chooseCallback.call if @chooseCallback
      end
    end
  end
  
  # Call this to programatically choose an item
  # Will de-select everything else.
  def chosen=(item)
    widget = @widgets_to_items.invert[item]
    if widget
      @chosen = item
      everyone = @children.select { |child| child.respond_to?('selected=') }
      everyone.each do | child |
        child.selected = (child == widget)
      end
    else
      @chosen = nil
    end
  end
  
  # Returns the height in pixels this widget would be if it were the
  # given number of lines high
  def height(lines=1)
    @proto = ListItem.new(' ', self)
    return (@proto.rect.h + @spacing) * lines
  end
  
  def items=(array)
    @items = array.flatten

    refresh  
  end
  
  def multi=(new_multi)
    @multi = new_multi
    if @multi
      if @chosen
        @chosen = [@chosen]
      else
        @chosen = []
      end
    else
      if @chosen
        @chosen = @chosen[0]
      else
        @chosen = nil
      end
    end
  end

  def keyTyped(event)
    if @focus && @chosen
      index = @items.index(@chosen)
      if index
        new_index = nil
        if event.key == :up
          new_index = index - 1
          new_index = 0 if new_index < 0
        elsif event.key == :down
          new_index = index + 1
          new_index = @items.size-1 if new_index >= @items.size
        end
        choose(@items[new_index]) if new_index
      end
      
    end
  end
  
  def multi_select(picked)
    widget = @widgets_to_items.invert[picked]
    if widget
      widget.selected = !widget.selected
      if widget.selected
        @chosen ||= []
        @chosen << picked
      else
        @chosen.delete(picked)
      end
    end
  end
  
  def refresh
    setup_items
    setup_scroll
    
    @lku = 0
    @chosen = nil
  end
  
  def scroll=(skipItems)
    @scroll = skipItems
    setup_items
    setup_scroll
  end
  
  def setup_items
    clear
    @items ||= []
    @widgets_to_items = {}
    y = @rect.top + @spacing
    if not @items.empty? 
      @items[@scroll...@items.size].each do | item |
        break if y >= @rect.bottom
        continue if item.nil?
        text = @displayBlock.call(item)
        label = ListItem.new(text,self, @rect.width - 2)
        label.rect.x = @rect.x + @spacing
        label.rect.y = y
        self << label
        @widgets_to_items[label] = item
        if @chosen && chosen == item
          label.selected = true
        end
        y += label.rect.h
      end
    end
  end
  
  def setup_scroll

    upbutton = Button.new('^') { self.up }
    upbutton.rect.top = @rect.top
    upbutton.rect.right = @rect.right
    upbutton.depth = WIDGET_DEPTH
    upbutton.click_stops_here = true
    self << upbutton
    
    downbutton = Button.new('v') { self.down }
    downbutton.rect.bottom = @rect.bottom
    downbutton.rect.right = @rect.right
    downbutton.depth = WIDGET_DEPTH
    downbutton.click_stops_here= true
    self << downbutton
      
  end

  def up
    self.scroll = @scroll-1 unless @scroll == 0
  end

  def update(delay)
    super
    @lku += delay
  end
  
  def wheel(going_up,x,y)
    if going_up
      up
    else
      down
    end
  end

end

end