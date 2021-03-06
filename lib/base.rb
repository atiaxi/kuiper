 require 'engine'

module Opal

module Colorable
  attr_reader :bgcolor, :fgcolor, :border
  attr_reader :disabled_color, :selected_color
  
  def apply_to(colorable)
    colorable.bgcolor = @bgcolor if @bgcolor
    colorable.fgcolor = @fgcolor if @fgcolor
    colorable.border  = @border if @border
    colorable.disabled_color = @disabled_color if @disabled_color
    colorable.selected_color = @selected_color if @selected_color
    colorable.refresh
  end
  
  def bgcolor=(bgcolor)
    @bgcolor=bgcolor
    refresh
  end
  
  def border=(border)
    @border = border
    refresh
  end
  
  def disabled_color=(disabled_color)
    @disabled_color = disabled_color
    refresh
  end
  
  def fgcolor=(fgcolor)
    @fgcolor = fgcolor
    refresh
  end
  
  def selected_color=(selected)
    @selected_color = selected
    refresh
  end
  
  def refresh
    # Override this to re-paint
  end
end

module Fontable
  attr_reader :font
  
  def size=(size)
    @size = size
    refresh
  end
  
  def font=(name)
    @font = ResourceLocator.instance.font_for(name, @size)
    refresh
  end

  def refresh
    # Override this to re-paint
  end

end

# Utility for anything that wants to keep track of its focus.
# depends on there being a self.rect
module Focusable
  def mouseMove(loc)
    @focus = self.rect.collide_point?( *loc )
  end
end

class OpalSprite

  attr_accessor :rect
  attr_accessor :visible
  attr_accessor :depth
  attr_accessor :alive
  attr_accessor :click_stops_here
  
  def initialize()
    super
    @@blank ||= Rubygame::Surface.new([1,1])
    @rect = Rubygame::Rect.new(0,0,0,0)
    @visible = true
    @alive = true
    @depth = 0
    @image = nil
    @click_stops_here = false
  end
  
  def <=>(other)
    return @depth <=> other.depth
  end
  
  def draw(surface)
    self.image.blit(surface, self.rect)
  end
  
  def image
    return @image if @visible && @image
    return @@blank
  end
  
  def kill
    @alive = false
  end
  
  def translate_by(dx, dy)
    self.rect.move!(dx,dy)
  end
  
  def translate_to(new_x, new_y)
    dx = new_x - @rect.x
    dy = new_y - @rect.y
    self.translate_by(dx, dy)
  end
  
  # Some sprites may change their internal state; elapsed is the amount of
  # time that's gone by (in seconds) since the last frame
  def update(elapsed)
    
  end
end

# A sprite that doesn't need an update()
class StaticSprite < OpalSprite

  def update(delay)
  end
  
end

# Fakes a container, but behaves like every other widget;
# if you want this to look right, add this before the items
# that it should appear under.
# By default, blocks clicks to everything under it.
class Box < StaticSprite

  include Colorable
  
  BOX_DEPTH = 10
  
  def initialize()
    super
    @bgcolor = [0,0,255]
    @border = [255,255,255]
    @depth = BOX_DEPTH
    @click_stops_here = true
  end
  
  def draw(screen)
    screen.fill( @bgcolor, @rect )
    rect = Rubygame::Rect.new(@rect)
    screen.draw_box( rect.topleft,rect.bottomright, @border)
  end
  
end

# Simple label.
class Label < StaticSprite

  include Fontable
  include Colorable

  def initialize(txt='', size=12, font=$FONT)
    @image = false
    super()
    @rl = ResourceLocator.instance()
    self.size = size
    @fgcolor = [255,255,255]
    self.font = font
    self.text = txt
  end
  
  # Like height on MultiLineLabel, this returns the pixel width of a line of the
  # given number of characters.  Uses 'M' as the baseline.
  def length(chars)
    return @font.size_text("M"*chars)[0]
  end
  
  # Re-renders the underlying image
  def refresh
    self.text = @text_string if @image
  end
  
  def text
    return @text_string
  end
  
  # Changes the text of the image.
  def text=(string)
    string = string.to_s
    @text_string = string
    display_string = string.length == 0 ? ' ' : string
    @image = @font.render(display_string, true, @fgcolor)
    @rect = Rubygame::Rect.new unless @rect
    @rect.size = [@image.w,@image.h]
  end
  
  def update(delay)
  end
end

# A multi-line label.  Like the ListBox, this must have its rect set.  Because
# it's likely to have an initial text (like a Label would), a refresh call is
# necessary after the rect has been set to the desired height and width.  This
# label will wrap words accordingly, and will respect embedded newlines.
class MultiLineLabel < Label
  def initialize(txt='',size=12,font=$FONT)
    @width = nil
    @height = nil
    super(txt,size,font)
  end
  
  # Returns the height in pixels this widget would be if it were the
  # given number of lines high
  def height(lines=1)
    return @font.height * lines + 4 # Where's this magic '4' come from?
  end
  
  def text=(string)
    string = string.to_s
    string = ' ' if string.length == 0
    @text_string = string
    if (@rect.w > 0 or @width)
      @width ||= @rect.w
      @lines = []
      # Normally, split
      @sublines = @text_string.split("\n",-1)
      @sublines.each do | line |
        remainder = line
        @lines << '' if remainder.length == 0
        while remainder.length > 0
          w = @font.size_text(remainder)[0]
          index = remainder.length - 1
          while w > @width
            index = remainder.rindex(' ',index-1)
            break unless index # Give up if no spaces to break on
            w = @font.size_text(remainder[0...index])[0]
          end
          if index && index < remainder.length - 1
            # Using ASCII Record Separator as soft linebreak
            #@lines << remainder[0...index] +"\x1E" 
            #@lines << remainder[0...index] +"\n"
            @lines << remainder[0...index]
            remainder = remainder[index+1...remainder.size]
          else
            @lines << remainder #+ "\n"  unless remainder == "\n"
            remainder = ''
          end
        end
      end # Sublines are split on built-in newlines
      
      @mangled = @lines.join("\n")
      #@mangled.chop!
      
      @height = 0 unless @height
      @height = [@lines.size * @font.height,@height].max
      @image = Rubygame::Surface.new( [@width, @height ])
      @image.set_colorkey( Rubygame::Color[:magenta] )
      @image.fill( Rubygame::Color[:magenta] )
      y = 0
      
      # For caret location purposes, we need to keep the '\n' in the lines
      # :split doesn't give us the option to do that, however.
      #@lines = [@lines[0]] + @lines[1..@lines.size].collect { |l| "\n"+ l }
      #@lines.collect! { |l| l+"\n" }
      #@lines[-1] = @lines[-1].chomp
      #@lines[0] = first[1...first.size]
      
      @lines.each do |line|
        #line = line[1...line.size] if line.starts_with?(?\n)
        #line.chop!
        if line.size > 0
          txt_image = @font.render(line,false,@fgcolor)
          txt_image.blit(@image,[0,y])
        end
        y += @font.height
      end
      @rect.height = @height
      @rect.width = @width
    else # Quick dummy image so blits don't fail
      @image = Rubygame::Surface.new( [1, 1] )
    end
  end
  
end

class ImageButton < StaticSprite
  
  attr :enabled
  attr_reader :max_size
  
  include Colorable
  
  def initialize(filename=nil, &callback)
    super()
    @enabled = true
    @callback = callback
    @disabled_color = [255, 0, 0]
    @border = [ 255, 255, 255 ]
    @max_size = nil
    self.image = filename
  end

  def click(x,y)
    @callback.call(self) if @enabled
  end

  def enabled=(status)
    @enabled = status
    refresh
  end

  def image=(filename)
    img = ResourceLocator.instance.image_for(filename)
    if img
      @image_filename = filename
      self.raw_image=img
    else
      img = Rubygame::Surface.new( [ 1, 1] )
      self.raw_image=img
    end
  end

  def raw_image=(img)
    if @max_size
      if img.w > @max_size[0] || img.h > @max_size[1]
        xscale = @max_size[0] / img.w.to_f
        yscale = @max_size[1] / img.h.to_f
        if version_check(:sdl_gfx,[2,0,13])
          img = img.rotozoom(0, [xscale,yscale])
        else
          scale = [xscale,yscale].min
          img = img.rotozoom(0, scale)
        end
      end
    end 
      
    width = img.w
    height = img.h
      
    width = width + 2 if @border
    height = height + 2 if @border
      
    @image = Rubygame::Surface.new( [width, height])
    @image.fill(@disabled_color) unless @enabled
    if @border
      border_color = @enabled ? @border : @disabled_color
      @image.draw_box([0,0], [@image.w-1, @image.h-1], border_color)
      offset = [ 1, 1 ]
    else
      offset = [ 0, 0 ]
    end
    img.blit(@image, offset)
      
    @rect.w = @image.w
    @rect.h = @image.h
  end
  
  def max_size=( aspect )
    @max_size = aspect
    refresh
  end
  
  def refresh
    if @image_filename
      self.image = @image_filename
    end
  end
  
end

# Button which responds to clicks
class Button < Label

  attr :enabled
  attr_accessor :callback
  attr_reader :border_thickness

  def initialize(text='', size=12, font=$FONT, &callback)
    @bgcolor = [ 0, 0, 255 ]
    @border = [ 255, 255, 255 ]
    @disabled_color = [ 64, 64, 64 ]
    @enabled = true
    @border_thickness = 1
    super(text,size,font)
    
    @callback = callback

  end
  
  def border_thickness=(thickness)
    @border_thickness = thickness
    refresh
  end
  
  def click(x,y)
    @callback.call(self) if @enabled && @visible
  end
  
  def enabled=(status)
    @enabled = status
    refresh
  end
  
  # Sets the text of the underlying image.
  def text=(string)
    string = string.to_s
    if(string.size <= 0)
      string = 'X'
    end
    @text_string = string
    @txt_image = @font.render(string, true, @fgcolor)
    full_width = @txt_image.w + @border_thickness * 2 + 2
    full_height = @txt_image.h + @border_thickness * 2 + 2
    @image = Rubygame::Surface.new( [full_width, full_height])
    @image.fill(@bgcolor) if @enabled
    @image.fill(@disabled_color) unless @enabled
    (1..@border_thickness).each do |offset|
      @image.draw_box([offset-1,offset-1], 
        [@image.w-offset, @image.h-offset], @border)
    end
    @txt_image.blit(image, [@border_thickness+1, @border_thickness+1])
    if @rect
      @rect.size = [@image.w, @image.h]
    else
      @rect = Rubygame::Rect.new([0, 0, @image.w, @image.h])
    end
  end
end

class CheckBox < Label
  
  attr_accessor :checked
  
  def initialize(text='',initial_value=false,size=12,font=$FONT)
    @bgcolor = [ 0, 0, 0 ,255]
    @border = [255,255,255,255]
    @fgcolor = [ 255, 255, 255,255 ]
    @checked = initial_value
    @spacing = 3
    @clickCallback = nil
    super(text, size, font)
  end
  
  def click(*args)
    @checked = !@checked
    @clickCallback.call if @clickCallback
    refresh
  end
  
  def draw(screen)
    checkbox_h = @txt_image.h
    checkbox_w = checkbox_h
  
    screen.draw_box( [@rect.x, @rect.y],
      [@rect.x + checkbox_w, @rect.y + checkbox_h], @border)
    if @checked
      screen.draw_line( [ @rect.x+2, @rect.y+2],
        [@rect.x+checkbox_w-2, @rect.y+checkbox_h-2], @fgcolor)
      screen.draw_line( [ @rect.x+checkbox_w-2, @rect.y+2],
        [@rect.x+2, @rect.y+checkbox_h-2], @fgcolor)
    end
    @txt_image.blit(screen, [@rect.x+checkbox_w + @spacing, @rect.y+2])
    #@image.set_alpha(255)
  end
  
  def onClicked(&callback)
    @clickCallback = callback
  end
  
  def text=(string)
    string = string.to_s
    if(string.size <= 0)
      string = 'X'
    end
    @text_string = string
    @txt_image = @font.render(string, true, @fgcolor)
    @rect.h = @txt_image.h + 1
    @rect.w = @txt_image.w + @spacing + @rect.h
  end
  
end

# A sprite made of others, that passes on its
# click, key, update() and draw() commands. Its
# depth is always higher than its children
class CompositeSprite < OpalSprite
  
  def initialize()
    #@children = []
    super
    clear
  end
  
  # This automatically moves sprites' depths to be
  # in front of our depth.
  def <<(sprite)
    @children << sprite
    if sprite.depth >= @depth
      adjust_sprite_depth(sprite)
    end
  end

  def adjust_sprite_depth(sprite,ddepth=-1)
    sprite.depth = @depth + ddepth
  end
  
  def clear
    @children = []
  end
  
  def click(x,y)
    clicked = @children.select do | child |
      child.rect.collide_point?(x,y)
    end
    clicked.sort.each do | clickee |
      clickee.click(x,y) if clickee.respond_to?(:click)
      break if clickee.click_stops_here
    end
  end
  
  def depth=(new_depth)
    @depth = new_depth
    @children.each { |c| adjust_sprite_depth(c) }
  end
  
  def draw(screen)
#    assert { @rect.w > 0 && @rect.h > 0 }
    @children.each do | child |
      child.draw(screen)
    end
  end
  
  def keyTyped(event)
    @children.each do |child|
       child.keyTyped(event) if child.respond_to?(:keyTyped)
    end
  end
  
  def mouseMove(loc)
    @children.each do |child|
      child.mouseMove(loc) if child.respond_to?(:mouseMove)
    end
  end
  
  def translate_by(dx,dy)
    translate_to(@rect.x + dx, @rect.y+dy)
  end
  
  def translate_to(new_x, new_y)
    dx = new_x - @rect.x
    dy = new_y - @rect.y
    @children.each do | child |
      child.translate_by(dx,dy)
    end
    self.rect.move!(dx,dy)
  end
  
  def update(delay)
    @children.each { | child | child.update(delay) }
  end
  
  def wheel(going_up,x,y)
    clicked = @children.select do | child |
      child.rect.collide_point?(x,y)
    end
    clicked.each do | clickee |
      clickee.wheel(going_up,x,y) if clickee.respond_to?(:wheel)
    end    
  end
  
end


end

require 'text'
require 'listbox'