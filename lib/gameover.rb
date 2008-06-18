# Game over man, Game over!

require 'engine'

class GameOverState < Opal::State
  
  ALPHA_PER_SECOND = 255
  
  def initialize(sector_state)
    super(sector_state.driver)
    @sector_state = sector_state
    @alpha = 0
    @total = 0
  end
  
  def draw(screen)
    @sector_state.draw(screen)
    w = screen.w
    h = screen.h
    screen.draw_box_s( [0,0], [w,h], [255,255,255,@alpha.to_i])
  end
  
  def update(delay)
    @alpha += ALPHA_PER_SECOND * delay
    @alpha = 255 if @alpha > 255
    @total += delay
    if @total > 2.0
      Opal::ResourceLocator.instance.repository.reset
      @driver.pop
    end
  end
  
end