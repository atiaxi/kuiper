#!/usr/bin/env ruby

# :title:Kuiper Documentation
# :main:kuiper.rb
# Kuiper is a top-down 2D space trading/shooting/RPG/adventure game
# full of suspense and/or intrigue.
# 
# Author:: Roger Ostrander
# License:: GPL

require 'optparse'

require 'base'
require 'editor'
require 'dialogs'
require 'kuidialogs'
require 'optionscreen'
require 'sector'
require 'overrides'
require 'setup_bootstrap'
require 'banner'

include Opal

# State which serves as the title screen.
class TitleScreen < State

  def activate
    $edit_mode = false
    @continue.call if @continue
  end

  def initialize(state)
    @continue = nil
    @resume = false
    super(state)
    @rl = ResourceLocator::instance()
    
    @background = @rl.image_for("kuiper.png")
    xScale = @rl.screen.w / @background.w.to_f
    yScale = @rl.screen.h / @background.h.to_f
    @background = @background.zoom([xScale,yScale],true)

    @input = MultiLineInput.new("Edit Cheese")
    @input.set_size(5,40)
    scroller = Scroller.new(@input)
    scroller.translate_to(50,40)
    #self << scroller

    @title = Label.new("KUIPER", 72)
    @title.rect.center = [ @rl.screen.w / 2, @rl.screen.h / 3 ]
    self << @title 
    
    # Game side
    @newgame = Button.new("New Game", 16) { self.newgame() }
    @newgame.rect.center = [ @rl.screen.w / 4, @rl.screen.h / 2 ]
    self << @newgame
    
    @loadgame = Button.new("Load Game", 16) {self.load_game}
    @loadgame.rect.midtop = [@newgame.rect.centerx, @newgame.rect.bottom + 3]
    self << @loadgame
    
    @savegame = Button.new("Save Game", 16) { save_game }
    @savegame.rect.midtop = [ @loadgame.rect.centerx, @loadgame.rect.bottom + 3]
    @savegame.visible = false
    self << @savegame
    
    @resumegame = Button.new("Resume Game", 16) {self.resume_game}
    @resumegame.rect.midtop = [ @savegame.rect.centerx,
      @savegame.rect.bottom + 3 ]
    @resumegame.visible = false
    self << @resumegame
    
    @opts = Button.new("Options", 12) { self.set_options }
    @opts.rect.midtop = [ @resumegame.rect.centerx + 10,
      @resumegame.rect.bottom + 3]
    self << @opts
    
    # Editor side
    @newuni = Button.new("New Universe", 16) { self.new_universe() }
    @newuni.rect.midtop = [ @rl.screen.w / 4 * 3, @newgame.rect.top]
    self << @newuni 
    
    @loaduni = Button.new("Load Universe", 16) { self.load_universe() }
    @loaduni.rect.midtop = [ @newuni.rect.centerx, @newuni.rect.bottom + 3]
    self << @loaduni
    
    @credits = Button.new("Credits",12) { self.show_credits }
    @credits.rect.midtop = [ @loaduni.rect.centerx, @opts.rect.y ]
    self << @credits
    
    @multitest = ListBox.new
    @multitest.rect.width = 200
    @multitest.rect.height = 300
    @multitest.items = [ 'asdf','b','c','d','werg','chomp' ]
    @multitest.translate_to(3,3)
    @multitest.multi = true
    @multitest.chooseCallback { puts @multitest.chosen.inspect }
    #self << @multitest
    
    @omnitest = OmniChooser.new(@driver,"omni")
    @omnitest.rect.w = 200
    @omnitest.rect.h = 300
    @omnitest.translate_to(3,3)
    @omnitest.refresh
    #self << @omnitest
    
 
    parse_args
  end
  
  def draw(screen)
    @background.blit(screen, [0,0])
    #screen.fill( [255,255,255] )
    super(screen)
  end
  
  def load_game
    dialog = ScenarioDialog.new(@driver, '.ksg')
    dialog.title = 'Choose game to load'
    callcc do | cont |
      @continue = cont
      @driver << dialog
    end
    
    if dialog.chosen
      start_game_with(dialog.chosen)
    end
  end

  def load_universe
    #dialog = FileDialog.new(@driver, nil,["*.kui"],[".kuiper"])
    dialog = ScenarioDialog.new(@driver)
    dialog.title = 'Choose universe to load'
    @sub = dialog
    callcc do |cont|
      @continue = cont
      @driver << dialog
    end
    
    if @sub.chosen
      start_edit_with(@sub.chosen)
    end
  end
  
  def newgame
    dialog = ScenarioDialog.new(@driver)
    dialog.title = "Choose a scenario"
    callcc do |cont|
      @continue = cont
      @driver << dialog
    end
    
    if dialog.chosen
      start_game_with(dialog.chosen)
    end
  end
  
  # Creates a new universe for editing, starting with 'bootstrap.xml' as
  # a basic template.
  def new_universe
    #start_edit_with(@rl.path_for("bootstrap.xml"))
    start_edit
  end
  
  def parse_args(args = ARGV)
    
    opts = OptionParser.new do | opt |
      opt.banner = "Usage: kuiper [options]"
      
      opt.on("-s", "--scenario [NAME]",
          "Start a new game of the given scenario") do |name|
            
        fullpath = @rl.path_for(name)
        if fullpath
          
        end
      end
    end
    
  end
  
  def resume_game
    # If there's a game to resume, it means we got control because the
    # SectorState did a yield; give it back.
    @driver.swap
  end
  
  def show_credits
    banner = BannerState.new(@driver,demo_banner)
    @driver << banner
  end
  
  def start_edit
    start_edit_with(nil)
  end
  
  def start_edit_with(fullpath = nil)
    $edit_mode = true
    @continue = nil
    @rl.storage[:repository] = Repository.new
    repository = @rl.repository
    if fullpath
      repository.add_from_file(fullpath)
    else
      repository.universe = Bootstrapper.new.universe
    end
    
    @rl.screen.title = "Kuiper - Editing \"#{repository.universe.name}\""
    
    unistate = UniverseEditor.new(repository.universe,@driver)
    @driver << unistate
  end
  
  def start_game_with(fullpath)
    $edit_mode = false
    @continue = nil
    @rl.storage[:repository] = Repository.new
    repository = @rl.repository
    repository.add_from_file(fullpath)
    
    @rl.screen.title = "Kuiper: #{repository.universe.name}"
    
    @rl.visual_log.clear
    @rl.visual_log << "Welcome to Kuiper!"

    start = repository.universe.player.start_sector
    @rl.logger.warn("Universe is null!") unless repository.universe
    @rl.logger.warn("Player is null!") unless repository.universe.player
    @rl.logger.fatal("Start sector is null!") unless repository.universe.player.start_sector

    secstate = SectorState.new(start,@driver)
    callcc do |cont|
      @continue = cont
      @driver << secstate
    end
    
    if @rl.repository.root
      @resumegame.visible = true
      @savegame.visible = true
    else
      @resumegame.visible = false
      @savegame.visible = false
    end
    return repository
  end
  
  def set_options
    @continue = nil
    opts = OptionsScreen.new(@rl.options, @driver)
    @driver << opts
  end
  
  def to_s
    return "TitleScreen state"
  end

end