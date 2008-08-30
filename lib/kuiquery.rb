
include Opal

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


class OneLineInputDialog < DataActionDialog
  
  # We need to know whether this was actually displayed;
  # :resolved will be true when it has.
  attr_reader :resolved
  
  attr_reader :result
  
  def initialize(driver, message, default='')
    
    @rl = ResourceLocator.instance
    @insetX ||= 150
    @insetY ||= 250
    @spacing ||= 3
    @message = message
    @default = default
    @result = nil
    @resolved = false
    super(driver)
  end
  
  def done
    @resolved = true
    @driver.pop
  end
  
  def layout_actions
    layout_action_item("Ok") do
      @result = @input.text
      done
    end
    @done.text = "Cancel"
    @done.rect.right = @mainRect.right-@spacing
  end
  
  def layout_data
    @msgLabel = Label.new(@message)
    layout_data_item(@msgLabel)
    @input = InputField.new(@default, 40)
    layout_data_item(@input)
  end
  
end