require 'adapters'

class TC_Adapter < Test::Unit::TestCase
  def setup
    @rl = Opal::ResourceLocator.instance
    @rl.storage[:repository] = Repository.new
    @rl.repository.universe = KuiUniverse.new
    @rl.repository.universe.player.credits = 1000
    @shipPrint = KuiShipBlueprint.new
    @shipPrint.max_cargo = 10

    @playerShip = KuiShip.new
    @playerShip.blueprint = @shipPrint
    @playerShip.tag = 'player_ship'
    @rl.repository.universe.player.start_ship = @playerShip
    
    @cargoBlueprint = KuiCargoBlueprint.new
    @cargoBlueprint.tag = "cargo_fruit"
    @cargoBlueprint.name = "fruit"
    
    @cargo = KuiCargo.new
    @cargo.tag = "cargo"
    @cargo.blueprint = @cargoBlueprint
    @cargo.markup = 10
  end
  
  def test_buyable_cargo
    sca = ShipCargoAdapter.new(@playerShip)
    (@shipPrint.max_cargo-1).to_i.times do
      sca.add_item(@cargo)
    end
    assert(sca.can_fit_item?(@cargo, 1))
    sca.add_item(@cargo)
    assert(!sca.can_fit_item?(@cargo, 1))
    assert_equal(0, sca.amount_free("cargo"))
    
  end
  
end