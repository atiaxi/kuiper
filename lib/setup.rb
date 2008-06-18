require 'set'

require 'engine'
require 'repository'
require 'options'
require 'titlescreen'

include Opal


def start_kuiper  
  $edit_mode = false
  screen = setup_screen
  unless screen == nil
    engine = Engine.new()
    title = TitleScreen.new(engine)
    engine << title
    
    Rubygame.enable_key_repeat(Rubygame::DEFAULT_KEY_REPEAT_DELAY,
      Rubygame::DEFAULT_KEY_REPEAT_INTERVAL);
    
    engine.hook(:backslash) { |driver| driver.running = false }
    engine.hook(:f5) do | driver |
      rl = ResourceLocator.instance
      if $edit_mode
        save_universe(rl.repository.universe)
      end
    end
    engine.run
  end
end

def setup_joystick
  num = Rubygame::Joystick.num_joysticks
  # We're not actually using this variable, but
  # if we don't keep the joystick around somewhere,
  # Ruby will garbage collect it and Rubygame will close the device.
  $joysticks = []
  (0...num).each do |stick|
    $joysticks << Rubygame::Joystick.new(stick)
  end
end

# Sets up things other than the screen, but that's the main event.
def setup_screen
  rl = ResourceLocator.instance
  if rl.is_gem?('kuiper')
    rl.dirs << Gem.loaded_specs['kuiper'].full_gem_path
  end
  rl.dotfile=".kuiper"
  repository = Repository.new()
  rl.storage[:repository] = repository
  rl.storage[:visual_log] = [] # Distinct from the rl.logger; this is on-screen
  optpath = rl.dotpath_for("options.yml")
  if File.exists?(optpath)
    options = Options.from_file(optpath)
  else
    options = Options.new(optpath)
    options.save
  end
  rl.storage[:options] = options
  w,h = options.screen_size
  screen = rl.screen( w, h, options.fullscreen )
  icon = rl.image_for("kuicon.png",false,false)
  screen.icon = icon
  screen.title = "Kuiper"
  setup_joystick
  return screen
end