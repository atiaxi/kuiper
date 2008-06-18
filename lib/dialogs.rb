require 'engine'
require 'fileutils'

module Opal

class FileDialog < Opal::State
  
  attr_reader :title, :action_text, :dir, :chosen
  
  def initialize(driver, startdir = nil, show=["*"], dotdirsInclude=[])
    super(driver)
    @title = 'File Dialog'
    @action_text = 'Choose'
    if startdir == nil
      @dir = FileUtils.pwd      
    else
      @dir = startdir
    end

    @original_dir = @dir
    @chosen = nil
    @show = show
    
    @dotdirsInclude = dotdirsInclude
    # To make life easier on me and others who might use this, I'm adding in
    # "." and ".." to the includes here, if not already present
    @dotdirsInclude << "." unless @dotdirsInclude.index(".") != nil
    @dotdirsInclude << ".." unless @dotdirsInclude.index("..") != nil
    
    setup_gui
  end
  
  def action
    @chosen = @dir_field.text
    @driver.pop
  end
  
  def cancel
    @chosen = nil
    @driver.pop
  end
  
  def clickFile
    file = @file_list.chosen
    @chosen = File.expand_path(file,@dir)
    @dir_field.text = @chosen
  end
  
  def doubleClickDir
    newDir = @dir_list.chosen
    @dir = File.expand_path(newDir,@dir)
    setup_files
  end
  
  def setup_gui
    rl = ResourceLocator.instance
    
    scrRect = rl.screen_rect
    mainBox = Box.new
    width = scrRect.w - 100
    @mainRect = Rubygame::Rect.new( scrRect.w/2 - width / 2, scrRect.h / 4, 
                                    width , scrRect.h / 2 )
    mainBox.rect = @mainRect
    self << mainBox
    
    left = @mainRect.left + 3
    top = @mainRect.top + 3
    width = @mainRect.width - 6
    half = left + (width/2)
    bottom = @mainRect.bottom - 3
    @title_label = Label.new(@title)
    self.title = @title  # Sets location
    self << @title_label
    
    @action_button = Button.new(@action_text) { self.action }
    @action_button.rect.left = left
    @action_button.rect.bottom = bottom
    self << @action_button
    
    @cancel_button = Button.new('Cancel') { self.cancel }
    @cancel_button.rect.left = @action_button.rect.right + 3
    @cancel_button.rect.bottom = bottom
    self << @cancel_button
    
    @dir_field = InputField.new(@dir)
    @dir_field.rect.left = left
    @dir_field.rect.bottom = @action_button.rect.top - 3
    @dir_field.minimum_size = width
    self << @dir_field
    
    inner_height = @dir_field.rect.top - 3 - 
      top
    @dir_list = ListBox.new
    @dir_list.rect.width = width / 2 - 2
    @dir_list.rect.height = inner_height
    @dir_list.items = []
    @dir_list.translate_to(left, top)
    @dir_list.doubleChooseCallback do 
      doubleClickDir
    end
    self << @dir_list
    
    @file_list = ListBox.new
    @file_list.rect.width = width / 2 - 2
    @file_list.rect.height = inner_height
    @file_list.items = []
    @file_list.translate_to(half + 2, top)
    @file_list.chooseCallback do
      clickFile
    end
    self << @file_list
    
    setup_files
  end
  
  def setup_files
    allFiles = Dir.entries(@dir)
    dirs = allFiles.select { |file| 
      File.directory?(File.join(@dir,file)) &&
      (@dotdirsInclude.index(file) != nil ||
       file[0] != ?.
      )
    }
    files = []
    @show.each do | pattern |
      files = files + Dir.glob(File.join(@dir,pattern))
    end
    files = files.collect { |file| File.basename(file) }
    
    @dir_list.items = dirs.sort
    @file_list.items = files.sort
    @dir_field.text = @dir
  end
  
  def title=(text)
    rl = ResourceLocator.instance
    @title_label.text = text
    @title_label.rect.midbottom = [ rl.screen_rect.w / 2 ,@mainRect.top - 3 ]
  end 
end

# Unlike the FileDialog, above, the ResourceDialog will only show files that
# the engine can locate via the ResourceLocator.
class ResourceDialog < Opal::State
  attr_reader :title, :chosen, :action_text
  
  def initialize(driver)
    @continue = nil
    super
    @action_text = 'Choose'
    @title = 'Resource Dialog'
    @chosen = nil
    @spacing = 3
    
    setup_gui
  end
  
  def action
    rl = ResourceLocator.instance
    @chosen = rl.path_for(@file_list.chosen)
    @driver.pop
  end
  
  def cancel
    @chosen = nil
    @driver.pop
  end
  
  def setup_gui
    rl = ResourceLocator.instance
    self.clear
    
    scrRect = rl.screen_rect
    mainBox = Box.new
    width = @width ? @width : scrRect.w - 200
    @mainRect = Rubygame::Rect.new( scrRect.w/2 - width /2, scrRect.h / 4,
      width, scrRect.h / 2)
    mainBox.rect = @mainRect
    self << mainBox
    
    left = @mainRect.left + 3
    top = @mainRect.top + 3
    width = @mainRect.width - 6
    bottom = @mainRect.bottom - 3
    half = @half ? @half : left + width
    
    @title_label = Label.new(@title)
    self.title = @title
    self << @title_label
    
    @action_button = Button.new(@action_text) { self.action }
    @action_button.rect.left = left
    @action_button.rect.bottom = bottom
    self << @action_button
    
    @cancel_button = Button.new('Cancel') { self.cancel }
    @cancel_button.rect.left = @action_button.rect.right + 3
    @cancel_button.rect.bottom = bottom
    self << @cancel_button
    
    inner_height = @action_button.rect.top - 3- top
    @file_list = ListBox.new
    @file_list.rect.width = half - left
    @file_list.rect.height = inner_height
    @file_list.items = []
    @file_list.translate_to(left, top)
    self << @file_list
    
    setup_files
  end
  
  def setup_files
    rl = ResourceLocator.instance
    @file_list.items = rl.visible_files.sort
  end
  
  def title=(text)
    rl = ResourceLocator.instance
    @title_label.text = text
    @title_label.rect.midbottom = [ rl.screen_rect.w / 2, @mainRect.top - 3]
  end
  
end

end