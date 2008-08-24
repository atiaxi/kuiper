#!/usr/bin/env ruby

require 'singleton'
require 'logger'

require 'base'
require 'utility'

# Attempt to load rubygame as a gem
begin
  require 'rubygems'
  gem 'rubygame', '>=2.4.0'
rescue LoadError
  # Nope, either no gems or no rubygame
end

begin
  require 'rubygame'
  require 'rubygame/ftor'
  # In case we didn't get this from a gem, verify version
  unless version_check(:rubygame, [2,4,0])
    puts "This requires Rubygame >= 2.4.0"
    exit
  end
rescue LoadError
  puts "Unable to load Rubygame!"
  exit
end

# Just a message to indicate that assert() down there failed
class AssertionError < StandardError
end

def assert(message=nil, &toAssert)
  unless(toAssert.call)
    message ||= "Assertion failed!" 
     raise AssertionError, message
   end
end

module Opal

module Waker
  
  # There are some items which register themselves as continuations
  attr_accessor :continue
  
  def activate
    if @continue
      cont = @continue
      @continue = nil
      cont.call
    end
    @wakeup_widgets.each { |w| w.activate } if @wakeup_widgets
    setup_gui
  end
  
  # Almost every one will override this; it's here in case there's a wakee that
  # doesn't have it.
  def setup_gui
    
  end
  
  def setup_waker
    @wakeup_widgets = Set.new
  end
  
end

class Engine

  attr_reader :hooks
  attr_accessor :running
  
  def initialize()
    @stack = []
    @hooks = {}
    @running = false
  end
  
  # Alias for Engine::push
  def <<(state)
    self.push(state)
  end
  
  def hook(key, &callback)
    @hooks[key] = callback
  end
  
  # The current state is the one on top of the stack
  def current
    return @stack[-1]
  end
  
  # Removes the topmost state from the stack, calling State#deactivate on it
  # and then State#activate on the newly-current state.
  def pop(deactivate = true, activate = true)
    popped = nil
    if current
      current.deactivate if deactivate
      popped = @stack.pop
    end
    current.activate if current && activate
    return popped
  end
  
  # Puts a new state on top of the stack.  Calls #deactivate on the
  # current state if any, then State#activate on the new one.
  def push(state, deactivate = true, activate = true)
    current.deactivate if current && deactivate
    @stack << state
    state.activate if activate
    return self
  end
  
  def replace(state)
    popped = nil
    if current
      current.deactivate
      popped = @stack.pop
    end
    @stack << state
    state.activate if current
    return popped
  end

  # The entry point of the engine, call once you've set a state
  def run
    @running = true
    clock = Rubygame::Clock.new()
    queue = Rubygame::EventQueue.new()
    rl = ResourceLocator.instance
    
    clock.tick
    while @running and self.current
      pre_transition = self.current # All events in the queue are applied to the
                                    # current state
      mouseUps = []
      queue.each do |event|
        pre_transition.raw(event) if pre_transition.respond_to?(:raw)
        case(event)
        when Rubygame::QuitEvent
          @running = false
        when Rubygame::KeyDownEvent
          result = @hooks[event.key]
          result.call(self) if result
          #puts event.key
          pre_transition.keyEvent(event,true)
        when Rubygame::KeyUpEvent
          pre_transition.keyEvent(event, false)
        when Rubygame::MouseMotionEvent
          pre_transition.mouseMove(event)
        when Rubygame::MouseDownEvent
          pre_transition.mouseDown(event)
        when Rubygame::MouseUpEvent
          mouseUps << event
        end
      end
    
      # This is done outside of the event-handling loop, because otherwise
      # the when the continuations it causes (i.e. pressing the 'done' button)
      # return, they bring back the old state of the event queue with them,
      # and the mouse events are re-played.
      mouseUps.each do | event |
        pre_transition.mouseUp(event)
      end
    
      rl.screen.fill([0,0,0])
      current.draw(rl.screen) if current
      rl.screen.flip
      elapsed = clock.tick / 1000.0
      current.update(elapsed) if current

      Rubygame::Clock.wait(50)
    
    end
    Rubygame::quit
  end
  
  # Temporarily yield the current state's primacy to the state below it.
  def swap
    us = self.pop(true,false)
    them = self.pop(false,false)
    self.push(us,false,false)
    self.push(them,false,true)
  end

end

class State

  include Colorable

  attr_accessor :auto_apply_theme
  attr_reader :driver
  
  attr_reader :sprites

  def initialize(driver)
    super()
    @sprites = []
    @keyStatus = {}
    @driver = driver
    @auto_apply_theme = false
  end
  
  def <<(sprite)
    if @auto_apply_theme
      apply_to(sprite) if sprite.respond_to?(:apply_to)
    end
    @sprites << sprite
    @sprites.sort! { |x,y| -(x.depth <=> y.depth) }
  end
  
  # Called whenever we're made the current state
  def activate()
  end
  
  def apply_theme
    self.each do | sprite |
      apply_to(sprite) if sprite.respond_to?(:apply_to)
    end
  end
  
  def clear
    @sprites.clear
  end
  
  # Returns a list of sprites that collide with this point
  def collide_point(x,y)
    return @sprites.select do | sprite |
      sprite.rect.collide_point?(x,y)
    end
  end
  
  # Called whenever we're about to be made not the current state
  def deactivate()
  end
    
  # Draws all the sprites of this state onto the screen
  def draw(screen)
    @sprites.each do | sprite |
      sprite.draw(screen)
    end
  end
   
  # Passes down keyTyped to all sprites in the current state
  def keyEvent(event, pressed)
    @keyStatus ||= {}
    #oldStatus = @keyStatus[event.key]
    @keyStatus[event.key] = pressed
    if pressed
      self.sprites.each do | sprite |
        sprite.keyTyped(event) if sprite.respond_to?(:keyTyped)
      end
    end
  end
  
  def mouseDown(event)
    @downAt = event.pos
  end
  
  # mouseMove events are passed along regardless of whether the target's
  # actually anywhere
  def mouseMove(event)
    self.sprites.each do | sprite |
      sprite.mouseMove(event.pos) if sprite.respond_to?(:mouseMove)
    end
  end
  
  # Passes down :click to affected sprites. Returns a list of them, too.
  def mouseUp(event)
    x,y = event.pos

    ups = collide_point(x,y)
    for sprite in ups
      if event.button == Rubygame::MOUSE_LEFT ||
         event.button == Rubygame::MOUSE_RIGHT ||
         event.button == Rubygame::MOUSE_MIDDLE
        sprite.click(x,y) if sprite.respond_to?(:click)
      else
        if sprite.respond_to?(:wheel)
          sprite.wheel(event.button == Rubygame::MOUSE_WHEELUP)
        end
      end
    end
    return ups
  end
  
  def update(delay)
    @sprites.each { |sprite| sprite.update(delay) }
  end
  
end

class ResourceLocator
  include Singleton
  
  IMAGES_DIR = "./images"
  DATA_DIR = "./data"
  SCENARIOS_DIR = "./scenarios"
  
  attr_reader :dotfile
  
  def initialize
    @dirs = [ IMAGES_DIR, DATA_DIR, SCENARIOS_DIR ]
    @screen = nil
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @storage = {}
    @fonts = {}
    @images = {}
    @dotfile = nil
  end
  
  def base_dir
    return FileUtils.pwd
  end
  
  def dotfile=(name)
    if name[0] != ?.
      name = '.' + name
    end
    homedir = ENV['HOME']
    homedir = ENV['USERPROFILE'] unless homedir # Windows equivalent
    @dotdir=File.join(homedir,name)
    @dirs << @dotdir
    return @dotdir
  end
  
  def dotpath_for(name)
    unless File.exists?(@dotdir)
      Dir.mkdir(@dotdir)
    end
    file = File.join(@dotdir,name)
    return file
  end
  
  def dirs
    return @dirs
  end
  
  # Loads the given font at the given size.  The result is cached because fonts
  # aren't likely to take up a whole lot of space.
  def font_for(filename,size=16)
    tuple = [filename, size]
    if @fonts.has_key?(tuple)
      return @fonts[tuple]
    else
      fullpath = path_for(filename)
      return nil unless fullpath
      ext = File.extname(filename)
      result = nil
      case(ext.downcase)
      when ".ttf"
        result = Rubygame::TTF.new(fullpath,size)
      when ".png"
        result = Rubygame::SFont.new(fullpath)
      end
      @fonts[tuple] = result
    end
    return result
  end
  
  # Loads the given image; note that there's no conversion or
  # done here. Images are cached here as well, but if this becomes 
  # too memory-intensive, we may change it.
  # If auto_colorkey is set, the image will have its colorkey set to its upper-
  # leftmost pixel.
  def image_for(filename, auto_colorkey=true, auto_convert=true)
    return nil unless filename
    unless @images.has_key?(filename)
      begin
        fullpath = path_for(filename)
        img = Rubygame::Surface.load_image(fullpath)
      rescue Rubygame::SDLError
        @logger.fatal("Error loading '#{filename}': #{$!}")
      end
      img = img.convert if auto_convert
      @images[filename] = img
      if auto_colorkey
        img.set_colorkey( img.get_at( [0,0] ))
      end
    end
    return @images[filename]
  end
  
  # Are we running this program via rubygems?
  # name is the name of the gem we'd be if we were a gem.
  def is_gem?(name)
    return @is_gem if @is_gem
    begin
      # First, do we even have gems?
      require 'rubygems'
      # Ported over from porttown
      # Apparently Gem.activate changed from 2 args to 1 at some point, and I
      # can't find rdocs anywhere that tell me why, so this is a workaround
      begin
        Gem.activate(name)
      rescue ArgumentError
        Gem.activate(name, false)
      end
      #If we made it here, then we're a gem.
      @is_gem = true
    rescue LoadError
      @is_gem = false
    end
    return @is_gem
  end
  
  def logger
    return @logger
  end
  
  # The repository can be used to store global objects in a slightly less 
  # horrible way than actually using global variables.
  # To set, use repository.storage[:foo] = var, and you can
  # retrieve with repository.foo.
  def method_missing(name, attrs=[])
    if self.storage.has_key?(name)
      return self.storage[name]
    else
      super(name,attrs)
    end
  end
  
  # Given the name of a directory to look in and a file to find, this will 
  # recursively search it for the file.  Returns a full path or nil
  def path_from_dir_for(dir,filename)
    # Can we do this the easy way?
    file = File.join(dir,filename)
    return file if File.exist?(file)
    
    # Didn't think so
    if File.exist?(dir)
      allFiles = Dir.entries(dir)
      foundDirs = allFiles.select { |f| 
        fullPath = File.join(dir,f)
        File.exist?(fullPath) &&
        File.directory?(fullPath) &&
        f != '.' && f != '..' }
      foundDirs.each do | subdir |
        subdir_path = File.join(dir,subdir)
        result = path_from_dir_for( subdir_path, filename)
        return result if result
      end
    end
    return nil
  end
  
  # Given the name of the file to find, this will generate a full
  # path for it.  It will look in all of the directories listed in
  # @dirs, and all their subdirectories, and return the first it finds.
  def path_for(filename)
    return nil unless filename
    for dir in @dirs
      result = path_from_dir_for(dir,filename)
      return result if result
    end
    return nil
  end
  
  def respond_to?(item)
    if not super(item)
      return self.storage.has_key(item)
    end
  end
  
  def scenarios_dir
    return File.join(base_dir, SCENARIOS_DIR)
  end
  
  # If the screen has not been set up yet, this will do so.  If it has,
  # this returns a reference to that screen.
  def screen(width=800, height=600, fullscreen=false)
    return @screen if @screen
    Rubygame.init
    Rubygame::TTF.setup()
    modes = Rubygame::DOUBLEBUF | Rubygame::HWSURFACE
    if fullscreen
      modes |= Rubygame::FULLSCREEN
    end
    @screen =  Rubygame::Screen.set_mode([width,height],0, modes)
    return @screen
  end
  
  # Returns a Rubygame::Rect of the screen's dimensions.
  # (Calls :screen, and so sets it up if not already done)
  def screen_rect
    s = self.screen
    return Rubygame::Rect.new(0,0,s.w,s.h)
  end
  
  def storage
    return @storage
  end
  
  # Returns a list of all files visible to the locator: i.e., all
  # filenames under the @@dirs directories, and all directories under them.
  def visible_files
    result = []
    for dir in @dirs
      result += visible_files_under(dir)
    end
    return result
  end
  
  # Returns a list of all files in the given directory that are not
  # themselves directories, and all files under the ones that are.
  def visible_files_under(directory)
    result = []
    if File.exists?(directory)
      allFiles = Dir.entries(directory)
      dirs = allFiles.select{ |f| File.directory?(File.join(directory,f)) &&
        f != '.' && f != '..' }
      files = allFiles.reject{ |f| File.directory?(File.join(directory,f)) }
      result += files
      dirs.each do |subdir|
        result += visible_files_under(File.join(directory,subdir))
      end
    end
    return result
  end
end

end