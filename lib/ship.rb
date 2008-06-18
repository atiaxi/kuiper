
class ShipState < DataActionDialog
  
  def initialize(driver, all_ships)
    @ships = all_ships
    super(driver)
    @player = @rl.repository.universe.player
  end
  
  def buy_ship
    chosen = @itemList.chosen
    if @player.can_buy_ship?(chosen)
      @player.buy_ship(chosen)
      done
    end
  end
  
  def layout_actions
    @acceptField = Button.new("Buy this ship") { self.buy_ship }
    layout_action(@acceptField)
  end
  
  def layout_data
    @title = Label.new("Ships for sale")
    layout_data_item(@title)
    
    w = @mainRect.w / 4 * 3
    @itemList = ListBox.new
    @itemList.rect.w = w
    @itemList.rect.h = @mainRect.h / 2
    @itemList.displayBlock { | ship | ship.name }
    @itemList.items = @ships
    @itemList.chooseCallback do
      preview(@itemList.chosen)
    end
    layout_data_item(@itemList)
    
    @description = MultiLineLabel.new
    @description.rect.w = @itemList.rect.w
    layout_data_item(@description)
  end
  
  def preview(chosen)
    @description.text = chosen.description if chosen
  end
  
end