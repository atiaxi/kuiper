# This file specifically handles text editing.

module Opal

# Though theoretically useful for anything, I'm writing the scroller especially
# for MultiLineInput.  Right now, it's only a vertical scroller.
# If the client answers to :scroll_units, up/down will scroll that many pixels,
# otherwise it'll do just one.
class Scroller < CompositeSprite
  
  attr_reader :client
  
  def initialize(aWidget = nil,auto_expand=true)
    super()
    @border = [ 255, 255, 255 ]
    @bgcolor = [0,0,0]
    @scroll = 0
    @spacing = 1
    self.client = aWidget
    if @client
      @client.border = @bgcolor
      expand if auto_expand
    end
    
    setup_items
  end
  
  def client=(aWidget)
    if aWidget.respond_to?(:scroller=)
      aWidget.scroller=self
    end
    @client = aWidget
  end
  
  def down
    scroll(scroll_units)
  end
  
  def draw(screen)
    screen.fill(@bgcolor, @rect)
    oldClip = screen.clip
    screen.clip = @rect
    show_scroll = !@rect.contain?(@client.rect)
    @upbutton.visible= show_scroll
    @downbutton.visible = show_scroll
    super
    screen.clip = oldClip
    screen.draw_box( @rect.topleft, @rect.bottomright, @border)
  end
  
  # Sets our rectangle to that of our client's, plus spacing
  def expand
    if @client
      @rect.w = @client.rect.w + @spacing*2
      @rect.h = @client.rect.h + @spacing*2
    end
    @scroll = 0
  end
  
  # Scroll such that the given area is visible
  def make_area_visible(rect)
    return if @rect.contain?(rect)
    if rect.top < @rect.top
      diff = @rect.top - rect.top
      @scroll -= diff - @spacing
    elsif rect.bottom > @rect.bottom
      diff = rect.bottom - @rect.bottom
      @scroll += diff + @spacing
    end
    setup_scroll
  end
  
  def scroll(amount)
    @scroll += amount
    if @scroll < 0
      @scroll = 0
    else
      if @client
        bound = @client.rect.h - (@rect.h - @spacing*2)
        @scroll = bound if @scroll > bound
      end
    end
    setup_scroll
  end
  
  # Gets the client's scroll units
  def scroll_units
    if @client
      if @client.respond_to?(:scroll_units)
        return @client.scroll_units
      end
    end
    return 1
  end
  
  def setup_items
    clear
    self << @client if @client
    
    @upbutton = Button.new('^') { self.up }
    @upbutton.rect.top = @rect.top
    @upbutton.rect.right = @rect.right
    self << @upbutton
    
    @downbutton = Button.new('v') { self.down }
    @downbutton.rect.bottom = @rect.bottom
    @downbutton.rect.right = @rect.right
    self << @downbutton
    
    setup_scroll
  end
  
  def setup_scroll
    if @client
      @client.rect.x = @rect.x + @spacing
      @client.rect.y = @rect.y + @spacing - @scroll
    end
  end
  
  def up
    scroll(-scroll_units)
  end
  
end

class MultiLineInput < MultiLineLabel
  
  attr_accessor :scroller
  
  def initialize(text, size=12, font="freesansbold.ttf")
    @bgcolor = [ 0, 0, 0 ]
    @border = [ 255, 255, 255 ]
    @focus = false
    @caret = 0
    @scroller = nil
    @spacing = 2
    super(text,size,font)
    caret_to_end
  end
  
  def add_newline
    add_text("\n")
  end
  
  def add_text(str)
    #self.text = self.text + str
    @text_string ||= ""
    self.text = @text_string.insert(@caret,str)
    @caret += 1
    focus_caret
  end
  
  def caret_move_down
    current = caret_rect
    current.centery += @font.height
    self.click(*current.center)
    focus_caret
  end
  
  # Move the caret up one line - note that this is different than moving it up
  # one row and keeping the column the same; this will actually attempt to put
  # it one row up exactly.
  def caret_move_up
    current = caret_rect
    current.centery -= @font.height
    
    self.click(*current.center)
    focus_caret
  end
  
  # Returns a [row,col] pair indicating which lines of @lines the carat is in,
  # as well as how many characters into that line.
  def caret_pos
    prev = @mangled[0...@caret]
    #prev_orig = @text_string[0...@caret]
    #puts "prev: #{prev.inspect}, text: #{prev_orig.inspect}"
    row = prev.count("\n")
    last_newline = prev.rindex("\n") || 0
    last_break = last_newline
    last_break += 1 unless last_break == 0 # Off by ones in
    col = @caret - last_break
    #puts "Everything so far: #{prev}, count: #{row}"    
    return [row, col]
  end
  
  # Sets the caret's position, as best as it can, to the given row and column.
  # If row is too high, will set to the last row, if col is too high, will set
  # to the end of line in the given row
  def caret_pos=(loc)
    row,col = loc
    offset = 0
    if @lines && row < @lines.size
      (0...row).each { |r| offset += @lines[r].size+1}
      if col > @lines[row].size
        @caret = offset+1
        caret_to_end_of_line
      else
        @caret = offset + col
      end    
    else
      caret_to_end
    end
  end
  
  # Rectangle representing where, on-screen, the caret is
  def caret_rect
    line_index, char_offset = caret_pos
    top = @font.height * line_index
    bottom = @font.height * (line_index + 1)
    line = 0
    line = @lines[line_index] if @lines
    x_offset = 1
    if line
      until_caret = line[0...char_offset]
      x_offset = @font.size_text(until_caret)[0] + 1
    end
    return Rubygame::Rect.new(@rect.x + x_offset, @rect.y + top,1,bottom-top)
  end

  def caret_to_start_of_line
    prev = @mangled[0...@caret]
    last_newline = prev.rindex("\n") || 0
    last_newline += 1 unless last_newline == 0
    @caret = last_newline
  end
  
  # Positions the caret at the end of the text
  def caret_to_end
    @caret = 0
    @caret = @text_string.size if @text_string
    focus_caret
  end
  
  def caret_to_end_of_line
    prev = @mangled[0...@caret]
    last_newline = prev.rindex("\n") || 0
    next_newline = @mangled.index("\n",last_newline+1)
    if next_newline
      @caret = next_newline
    else
      @caret = @mangled.size
    end
  end
  
  def draw(screen)
    super
    
    if @focus
      r = caret_rect
      screen.draw_line( r.topleft, r.bottomleft, [255,0,0])
    end
  end
  
  def focus_caret
    if @scroller
      @scroller.make_area_visible(caret_rect)
    end
  end
  
  def mouseMove(loc)
    @focus = self.rect.collide_point?( *loc )
  end
  
  def click(x,y)
    x -= @rect.x
    y -= @rect.y
    row = y / @font.height
    col = -1
    width = 0
    if @lines && @lines[row]
      (0...@lines[row].size).each do |index|
        break if width > x
        width += @font.size_text(@lines[row][index..index])[0]
        col += 1
      end
      col = 0 if col == -1
      self.caret_pos = [row,col]
    else
      caret_to_end
    end
    
  end
  
  def keyTyped(event)
    str = event.string 
    if @focus
      if event.key == Rubygame::K_BACKSPACE
        if @text_string && !@text_string.empty?
          remove_text
        end
      elsif event.key == Rubygame::K_RETURN
        add_newline
      elsif event.key == Rubygame::K_END
        caret_to_end_of_line
      elsif event.key == Rubygame::K_HOME
        caret_to_start_of_line
      elsif event.key == Rubygame::K_LEFT
        #puts "At: #{@caret} going #{@caret-1}, max: #{@text_string.size}"
        @caret -= 1 unless @caret == 0
        focus_caret
      elsif event.key == Rubygame::K_RIGHT
        #puts "At: #{@caret} going #{@caret+1}, max: #{@text_string.size}"
        if @text_string
          @caret += 1 unless @caret == @text_string.size
          focus_caret
        end
      elsif event.key == Rubygame::K_UP
        caret_move_up
      elsif event.key == Rubygame::K_DOWN
        caret_move_down
      elsif !str.is_null?
        add_text(str)
      end
    end
  end
  
  # Programatic backspace
  def remove_text
    unless @caret == 0
      @text_string[@caret-1]=""
      self.text = @text_string
      @caret -= 1
    end
    @caret = 0 if @caret < 0
    focus_caret
  end
  
  def scroll_units
    return @font.height
  end
  
  def set_size(rows,cols)
    @rect.w = @font.size_text("M"*cols)[0]
    @height = rows * @font.height
    refresh
  end
  
  def text=(string)
    @text_string = string
    if @rect.w > 0
      @width ||= @rect.w - @spacing*2
      super(string)
      @txt_image = @image
      @image = Rubygame::Surface.new( [@rect.w, @height + @spacing*2] )
      @image.fill(@bgcolor)
      @image.draw_box( [0,0], [@image.w - @spacing, @image.h - @spacing],
        @border)
      @txt_image.blit(@image, [@spacing,@spacing])
      @rect.h = @height + @spacing*2
    else
      @image ||= Rubygame::Surface.new( [1, 1] )
    end
  end
  
end

# Basic inputfield.  Focus is strictly under the mouse for these.
class InputField < MultiLineInput
  
  attr_reader :minimum_size
  
  def initialize(text, minChars = nil, size=12, font="freesansbold.ttf")
    @minimum_size = 0
    super(text,size,font)
    self.minimum_chars = minChars
  end
  
  def add_newline
    return
  end
  
  def caret_move_down
    return
  end
  
  def caret_move_up
    return
  end  
  
  def minimum_chars=(charsize)
    if charsize && charsize > 0
      @minChars = charsize
      self.minimum_size=self.length(charsize)
    end
  end

  def minimum_size=(size)    
    @minimum_size = size
    refresh
    @scroller.expand if @scroller
  end
  
  def mouseMove(loc)
    @focus = self.rect.collide_point?( *loc )
  end
  
  # Changes the text of the image.
  def text=(string)
    string = string.to_s
    @text_string = string
    @mangled = string
    @lines = [ string ]
    display_string = string.length == 0 ? ' ' : string
    @txt_image = @font.render(display_string, true, @fgcolor)

    @rect.w = [@txt_image.w, @minimum_size].max + @spacing*2

    @image = Rubygame::Surface.new( [@rect.w, @txt_image.h + @spacing*2] )
    @image.fill(@bgcolor)
    @image.draw_box( [0,0], [@image.w - @spacing, @image.h - @spacing],
      @border)
    @txt_image.blit(@image, [@spacing,@spacing])
    
    @rect.size = [@image.w,@image.h]
  end
end

end