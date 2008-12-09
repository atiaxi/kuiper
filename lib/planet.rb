require 'kuidialogs'
require 'mission'
require 'ship'

# The landed state comes up when the player first lands on the planet.
class LandedState < DataActionDialog
  
  def initialize(driver, planet)
    @planet = planet
    @generated = []
    super(driver)
    @player = @rl.repository.universe.player 
  end
  
  def activate
    @player.on_planet = @planet
    ship =  @player.start_ship
    ship.stop
    ship.shields = ship.max_shields
    ship.armor = ship.max_armor
    if @generated.size == 0
      @planet.random_missions.each do | generator |
        genned = generator.generate(@planet)
        @generated += genned
      end   
    end
    super
    
    unless @checked_missions
      unless @eval
        @eval = MissionEvaluatorState.new(@driver, @player.missions, self)
        result = @eval.check
    
        if result
          @eval = MissionEvaluatorState.new(@driver, @planet.plot, self)
          result = @eval.award
          @checked_missions = true if result
        end
      end
    end
    
  end
  
  def do_addons
    saa = ShipAddonAdapter.new(@player.start_ship)
    planetAddons = ReadOnlyListAdapter.new(@planet.addons_for_sale, KuiAddon)
    addons = MarketDialog.new(@driver, saa, planetAddons)
    callcc do | cont |
      @driver << addons
      @continue = cont
    end
  end
  
  def do_cargo
    sca = ShipCargoAdapter.new(@player.start_ship)
    planetCargo = ReadOnlyListAdapter.new(@planet.cargo_for_sale, KuiCargo)
    cargo = MarketDialog.new(@driver, sca, planetCargo)
    callcc do | cont |
      @driver << cargo
      @continue = cont
    end
  end
  
  def do_missions
    missions = MissionState.new(@driver, @planet.missions + @generated)
    @driver << missions
  end
  
  def do_refuel
    player = @rl.repository.universe.player
    ship = player.start_ship
    to_refuel = ship.max_fuel - ship.fuel
    cost = @planet.fuel_cost
    total = cost * to_refuel
    ship.fuel = ship.max_fuel
    player.credits -= total
    @fuel.visible = false
  end
  
  def do_ships
    ships = ShipState.new(@driver, @planet.ships_for_sale)
    @driver << ships
  end

  def do_weapons
    swa = ShipWeaponAdapter.new(@player.start_ship)
    planetWeapons = ReadOnlyListAdapter.new(@planet.weapons_for_sale,
      KuiWeaponBlueprint)
    weapon = MarketDialog.new(@driver, swa, planetWeapons)
    callcc do | cont |
      @driver << weapon
      @continue = cont
    end
  end
  
  def done
    @player.on_planet = nil
    start = @player.start_sector
    secstate = SectorState.new(start,@driver)
    secstate.simulate_time_passage
    save_game(@player.name, $AUTOSAVE_SUFFIX)
    @driver.replace(secstate)
  end
  
  def layout_actions
    player = @rl.repository.universe.player 
    ship = player.start_ship
    to_refuel = ship.max_fuel - ship.fuel
    cost = @planet.fuel_cost
    total = cost * to_refuel
    fuelstr = "Refuel  (#{to_refuel} units X #{cost} credits = #{total})"
    @fuel = layout_action_item(fuelstr) { self.do_refuel }
    @fuel.visible = to_refuel > 0
    @fuel.enabled = player.credits >= total
    
    cargo = layout_action_item("Marketplace") { self.do_cargo }
    cargo.visible = @planet.cargo_for_sale.size > 0
    
    addons = layout_action_item("Addons") { self.do_addons }
    addons.visible = @planet.addons_for_sale.size > 0
    
    weapons = layout_action_item("Weapons") { self.do_weapons }
    weapons.visible = @planet.weapons_for_sale.size > 0
    
    missions = layout_action_item("Mission Computer") { self.do_missions }
    missions.visible = @planet.missions.size + @generated.size > 0
    
    ships = layout_action_item("Shipyard") { self.do_ships }
    ships.visible = @planet.ships_for_sale.size > 0
  end
  
  def layout_data
    planetLabel = Label.new(@planet.name)
    layout_data_item(planetLabel)
    
    @desc = MultiLineLabel.new
    @desc.rect.w = @mainRect.w / 2 - (@spacing*2)
    @desc.text = @planet.description
    layout_data_item(@desc)
  end
  
  def update(delay)
    
    super
  end
  
end