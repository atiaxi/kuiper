
class PausedState < Opal::State
  
  def initialize(driver, superstate) 
    @superstate = superstate
    @rl = ResourceLocator.instance
    super(driver)
    setup_gui
  end
  
  def draw(screen)
    @superstate.draw(screen)
    super
  end
  
  def setup_gui
    pauseButton = Button.new("Paused") { @driver.pop }
    pauseButton.rect.centerx = @rl.screen_rect.centerx
    pauseButton.rect.centery = @rl.screen_rect.centery
    self << pauseButton
  end
  
end