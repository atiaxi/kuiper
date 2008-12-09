# Generic Banner/Credits state

require 'engine'
require 'base'

class BannerState < Opal::State
  def initialize(driver,data=nil,spd=10)
    super(driver)
    @data = data
    @spacing = 4
    @vSpacing = 30
    @speed = spd
  end
  
  def activate
    setup_gui
  end
  
  def scroll(pixels)
    @sprites.each do | sprite |
      sprite.translate_by(0,-pixels)
    end
  end
  
  def setup_gui
    clear
    screct = ResourceLocator.instance.screen_rect
    y = screct.h / 2
    if @data && @data.size > 0
      y -= @data[0].rect.h / 2
      @data.each do | datum |
        datum.rect.w = screct.w - @spacing unless datum.rect.w > 0
        datum.refresh
        x = screct.w/2 - datum.rect.w/2 
        datum.translate_to(x,y)
        y += datum.rect.h + @vSpacing
        self << datum
      end
    end
  end
  
  def update(delay)
    int_delay = (delay * @speed).to_i
    int_delay = 1 if int_delay <= 0
    scroll(int_delay)
  end
end

class Title < Opal::Label
  
  def initialize(txt='',size=96,font=$FONT)
    super
  end
  
end

class SubTitle < Opal::Label
  
  def initialize(txt='',size=36,font=$FONT)
    super
  end
  
end

class MultiText < Opal::MultiLineLabel

  def initialize(txt='',size=24,font=$FONT)
    @width = Opal::ResourceLocator.instance.screen_rect.w
    super(txt,size,font)
  end
  
end

class Table < Opal::CompositeSprite
  
  # Rows are of the form:
  # [[ 'col1', 'col2',...], ['col1','col2',...] ...]
  # Failure to keep a consistant number of columns
  # in the array will lead to ANNOYANCE and also crashes.
  def initialize(rows,size=18)
    @data = rows
    @size = size
    @spacing = 10
    super()
    setup_gui
  end
  
  def refresh
    setup_gui
  end
  
  def setup_gui
    clear
  
    tableLabels = @data.collect do | row |
      row.collect do | col |
        Label.new(col,@size)
      end
    end
    
    colWidths = (0...@data[0].size).collect do | col_index |
      tableLabels.inject(0) do | maximum,current |
        current[col_index].rect.w > maximum ?
          current[col_index].rect.w : maximum
      end
    end
    
    tableLabels.each_with_index do | array,rowIndex |
      right = 0
      array.each_with_index do | label, colIndex |
        label.rect.x = right
        label.rect.y = rowIndex * label.rect.h
        right += colWidths[colIndex] + @spacing
        self << label
      end
    end
    
    self.rect.w = colWidths.inject { | sum,n| sum+n+@spacing*colWidths.size }
    self.rect.h = tableLabels[0][0].rect.h * tableLabels.size
  end
  
end

def demo_banner
  result = []
  title = Title.new("Credits")
  result << title
  
  me = Title.new("by Roger Ostrander",36)
  result << me
  
  twoTable = []
  twoTable << [ 'Produced By', 'Bymer Klairich' ]
  twoTable << [ 'Sandwiches compliments of',
                'Greenbelt Sandwiches, inc.' ]
  twoTable << [ '','SandwichCraftCo' ]
  twoTable << [ '','']
  twoTable << [ 'Space Test Done by','the line above']
  
  result << Table.new(twoTable)
  
  threeTable = []
  threeTable << [ '1','Roger is Awesome','True']
  threeTable << [ '2','Cheese is Great','False']
  threeTable << [ '3','3 is three','True']
  result << Table.new(threeTable)
  
  return result  
end