#!/usr/bin/env ruby

require "test/unit"
require 'kuiobject'
require 'repository'

require 'set'

class KuiMissionTests < Test::Unit::TestCase
  
  def setup
    @rl = Opal::ResourceLocator.instance
    repo = Repository.new
    @rl.storage[:repository] = repo
    repo.root = Bootstrapper.new.universe
    
    @player = @rl.repository.universe.player
    @ship = @rl.repository.universe.player.start_ship
    
    @cargoBlueprint = KuiCargoBlueprint.new
    @cargoBlueprint.tag = "cargo_fruit"
    @cargoBlueprint.name = "fruit"
    
    @cargo = KuiCargo.new
    @cargo.tag = "cargo"
    @cargo.blueprint = @cargoBlueprint
    @cargo.markup = 10

    @cargoCond = KuiCargoFreeCondition.new(10)
    @giveth = KuiAwardRemoveCargoAction.new(@cargo,5)
    @taketh = KuiAwardRemoveCargoAction.new(@cargo,5,false)
    
    @start = @player.start_sector
    
    @startCond = KuiAtCondition.new
    @startCond.locations << @start
    
    @greenHalo = KuiHalo.new
    @giveHalo = KuiHaloAction.new
    @giveHalo.halo = @greenHalo
    @giveHalo.sectors << @start
    
    @endAction = KuiEndAction.new(1)
    
  end
  
  def test_at_start
    assert(@startCond.value)
    
    new_sector = KuiSector.new
    @player.start_sector = new_sector
    assert(!@startCond.value)
    
    planet = KuiPlanet.new
    @player.on_planet = planet
    @startCond.locations << planet
    assert(@startCond.value)
  end
  
  def test_cargo
    
    assert(@cargoCond.value)
    @cargo.mission_related = true
    @giveth.perform
    
    stored = @ship.cargo
    assert_equal(1,stored.size)
    assert_equal(@cargo.blueprint,stored[0].blueprint)
    
    assert_equal(5, @ship.available_cargo)
    assert(!@cargoCond.value)
    
    @taketh.perform
    
    assert(stored.size == 0)
    
    @cargo.mission_related = false
    @giveth.perform
    assert(@ship.cargo[0])
    @giveth.perform
    assert(@ship.cargo[0].amount == 10)
    
    assert(!@cargoCond.value)
  end
  
  def test_description
    original_desc = "Original Description"
    new_desc = "New Description"
    @mission = KuiMission.new
    @mission.tag = 'fixture_mission'
    @mission.description = original_desc
    
    kda = KuiDescriptionAction.new(new_desc)
    kda.target = @mission
    kda.perform
    
    assert_equal(new_desc,@mission.description)
  end
  
  def test_flags
    @fixtureFlag = KuiFlag.new
    @fixtureFlag.tag = 'fixture'
    @fixtureFlag.value = 500
    
    @notSet = KuiFlagCondition.new('fixture')
    @notSet.is_not_set = true
    assert(@notSet.value)
    
    @isSet = KuiFlagCondition.new('fixture')
    @isSet.is_set = true
    @isSet.number_is=321
    assert(!@isSet.value)
    
    @isTen = KuiFlagCondition.new('fixture')
    @isTen.number_is = 10
    assert(!@isTen.value)
    
    @reset = KuiFlagAction.new('fixture')
    @reset.new_number = 10
    @reset.perform
    
    assert(@isTen.value)
    assert(@isSet.value)
    assert(!@notSet.value)
    
    @remove = KuiFlagAction.new('fixture')
    @remove.unset = true
    @remove.perform
    
    assert(@notSet.value)
    
  end

  # This test doesn't just test adding/removing halos via the action, it's also
  # a fairly comprehensive test of the halos themselves.
  def test_halo
    @otherGreenHalo = KuiHalo.new
    
    @blueHalo = KuiHalo.new
    @blueHalo.b = 255
    @blueHalo.g = 0
    
    assert_equal(@start.halos.size, 0)
    
    @giveHalo.perform
    assert_equal(1, @start.halos.size)
    assert_equal(@start.halos[0], @greenHalo)
    
    @giveHalo.halo = @blueHalo
    @giveHalo.perform
    assert_equal(@start.halos.size, 2)
    
    @removeHalo = KuiUnhaloAction.new(@giveHalo)
    
    @removeHalo.perform
    assert_equal(1,@start.halos.size)
    
  end
  
  def test_mission_cargo
    
    @cargo2 = KuiCargo.new
    @cargo2.tag = "cargo2"
    @cargo2.blueprint = @cargoBlueprint
    @cargo2.mission_related = true
    
    @giveth.perform
    @giveth2 = KuiAwardRemoveCargoAction.new(@cargo2,5)

    @giveth2.perform
    assert_equal(0, @ship.available_cargo)
    assert_equal(2, @ship.cargo.size)
    assert_equal(@cargo.mission_related, @ship.cargo[0].mission_related)
    assert_equal(@cargo2.mission_related, @ship.cargo[1].mission_related)

  end
  
  def test_mission_cycle
    @mission = KuiMission.new
    @mission.tag = 'fixture_mission'
    @mission.worthy = [ @cargoCond ]
    @mission.setup = [ @giveth, @giveHalo ]
    
    @dropoff = KuiIfThen.new
    @dropoff.ifs << @startCond
    @dropoff.thens << @endAction
    
    @mission.checks << @dropoff
    
    results = @mission.awardable?
    assert(results == true)
    
    @mission.award
    assert(@player.missions[0] == @mission)
    
    # setup wasn't actually happening before; check to see that it is now
    assert_equal(1,@start.halos.size)
    
    @completed0 = KuiCompletedCondition.new(0)
    @completed0.completed = @mission
    assert(!@completed0.value)
    
    @mission.check
    assert(@player.missions.size == 0)
    assert(@player.completed_missions[0] == @mission)
    assert(@player.completed_missions[0].exit_code == 1)
    assert(@completed0.value)

    @completed1 = KuiCompletedCondition.new(1)
    @completed1.completed = @mission
    assert(@completed1.value)
    
    @completed2 = KuiCompletedCondition.new(2)
    @completed2.completed = @mission
    assert(!@completed2.value)
  end
  
  def test_money
    before = @player.credits
    
    moMoney = KuiMoneyAction.new(100)
    moMoney.perform
    
    assert(@player.credits == 100+before)
    
    stiffFine = KuiMoneyAction.new(-600)
    stiffFine.perform
    
    assert(@player.credits == before-500)
    
  end
  
  def test_popups
    @mission = KuiMission.new
    @mission.tag = 'fixture_popup'

    @sayHi = KuiInfoAction.new('Hello, world!')
    @ask = KuiYesNoCondition.new('Do that thing?')
    @mission.setup = [ @sayHi ]
    @mission.worthy = [@ask]
    
    @askIfThen = KuiIfThen.new
    @askIfThen.ifs = [ @ask ]
    @askIfThen.thens = [ @sayHi ]
    @mission.checks << @askIfThen
    
    cond, cont = @mission.awardable?
    
    if cont
      assert_equal(@ask, cond)
      cond.resolve(true) # User replies as expected
      cont.call 
    else
      assert(cond)
    end
    
    didOne = didTwo = false
    complete, cont = @mission.award
    if cont
      assert_equal(@sayHi,complete)
      complete.resolve(true)
      didOne = true
      cont.call
    else
      didTwo = true
      assert(complete)
    end
    assert(didOne && didTwo)
    
    didOne = didTwo = false
    check, cont = @mission.check
    if cont
      # This is either because of the yes/no question on the condition,
      # or the 'ok' info on the action.
      if check.respond_to?(:perform)
        assert_equal(@sayHi, check)
        check.resolve(true)
        didOne = true
        cont.call
      else
        assert_equal(@ask,check)
        check.resolve(true)
        didTwo = true
        cont.call
      end
    else
      assert(check)
    end
    assert(didOne && didTwo)
  end
  
  def test_sell_items
    @earth = KuiPlanet.new
    @earth.cargo_for_sale << @cargo
    
    @venus = KuiPlanet.new
    @venus.tag = "venus"
    
    @cargo2 = @cargo.dup
    @cargo2.tag = "cargo2"
    
    @weapon = KuiWeapon.new
    
    ksia = KuiSellItemsAction.new
    ksia.locations << @earth
    ksia.cargo << @cargo
    ksia.cargo << @cargo2
    ksia.weapons << @weapon
    
    ksia.perform
    assert_equal(2, @earth.cargo_for_sale.size)
    assert_equal(@cargo2, @earth.cargo_for_sale[1])
    assert_equal(@weapon, @earth.weapons_for_sale[0])
    
    assert_equal(0, @venus.cargo_for_sale.size)
    assert_equal(0, @venus.weapons_for_sale.size)
    
    @martians = KuiOrg.new
    @martians.tag = "martians"
    
    @mars = KuiPlanet.new
    @mars.tag = "Mars"
    @mars.owner = @martians
    ksia.orgs << @martians
    ksia.perform
    assert_equal(2, @earth.cargo_for_sale.size)
    assert_equal(1, @earth.weapons_for_sale.size)
    assert_equal(@cargo, @mars.cargo_for_sale[0])
    assert_equal(@weapon, @mars.weapons_for_sale[0])
  end
  
  def test_spawn
    @earth = @start
    
    @defeat_martian_invasion = KuiMission.new
    @player.missions << @defeat_martian_invasion
    
    @martianShip = @ship.dup # Martians look just like us
    @martianShips = KuiFleet.new
    @martianShips.tag = 'fixture_martian_fleet'
    @martianShips.ships << @martianShip
    @martianShips.ships << @martianShip
    @martianShips.ships << @martianShip
    
    # Martians invade earth
    @spawnMartians = KuiSpawnAction.new
    @spawnMartians.mission = @defeat_martian_invasion
    @spawnMartians.locations << @earth
    @spawnMartians.fleets << @martianShips
    @spawnMartians.watch_for_destruction = true
    @spawnMartians.perform
    assert_equal(@martianShips,@earth.potential_fleets[0])
    assert_equal(1, @earth.potential_fleets.size)
    assert_equal(@martianShips,@defeat_martian_invasion.fleets_to_die[0])
    
    # Put a bounty on their head
    @killMartians = KuiDestroyedCondition.new
    @killMartians.mission = @defeat_martian_invasion
    @killMartians.spawner = @spawnMartians
    assert(!@killMartians.value)
    
    # Word it differently for propaganda value
    @protectEarthicans = KuiDestroyedCondition.new
    @protectEarthicans.mission = @defeat_martian_invasion
    @protectEarthicans.fleets << @martianShips
    assert(!@protectEarthicans.value)
    
    # We beat them back
    @martianShips.kill_fleet(@start)
    assert(@killMartians.value)
    assert(@protectEarthicans.value)
    
    @despawnMartians = KuiDespawnAction.new
    @despawnMartians.locations << @earth
    @despawnMartians.fleets << @martianShips
    @despawnMartians.perform
    assert_equal(0, @earth.potential_fleets.size)
    
    # They are unsatisfied with this outcome
    @spawnMartians.perform
    
    # But it sucks to be them.
    @otherKillMartians = KuiDespawnAction.new
    @otherKillMartians.spawner = @spawnMartians
    @otherKillMartians.perform
    assert_equal(0, @earth.potential_fleets.size)
  end
  
  def test_unique
    @mission = KuiMission.new
    @mission.tag = 'fixture_mission'
    @mission.worthy = [ @cargoCond ]
    # Currently, this is the default, but I want to make it explicit if that
    # ever changes
    @mission.unique = true
    
    @mission.award
    assert(@player.has_mission?(@mission))
    assert(!@mission.awardable?)
    
    @player.remove_mission(@mission)
    assert(!@player.has_mission?(@mission))
    assert(@mission.awardable?)
  end
  
  def test_globally_unique
    @mission = KuiMission.new
    @mission.tag = 'fixture_mission'
    @mission.worthy = [ @cargoCond ]
    @mission.globally_unique = true
    
    @mission.award
    assert(@player.has_mission?(@mission))
    assert(!@mission.awardable?)
    
    @player.remove_mission(@mission)
    assert(!@player.has_mission?(@mission))
    assert(!@mission.awardable?)
  end
  
end

class RandomMissionGenerationTest < Test::Unit::TestCase
  def setup
    @rl = Opal::ResourceLocator.instance
    repo = Repository.new
    @rl.storage[:repository] = repo
    repo.root = Bootstrapper.new.universe
    
    @player = @rl.repository.universe.player
    @ship = @rl.repository.universe.player.start_ship
    
    @cargoBlueprint = KuiCargoBlueprint.new
    @cargoBlueprint.tag = "cargo_fruit"
    @cargoBlueprint.name = "Fruit"
    
    @cargo = KuiCargo.new
    @cargo.tag = "cargo"
    @cargo.blueprint = @cargoBlueprint
    
    @otherCargoPrint = KuiCargoBlueprint.new
    @otherCargoPrint.tag = "cargo_metal"
    @otherCargoPrint.name = "Metal"
    
    @otherCargo = KuiCargo.new
    @otherCargo.tag = "metal"
    @otherCargo.blueprint = @otherCargoPrint
    
    @earth = KuiPlanet.new
    @earth.tag = "planet_earth"
    @earth.name = "Earth"
    
    @mars = KuiPlanet.new
    @mars.tag = "planet_mars"
  end
  
  def test_simple_cargo
    
    template = KuiMission.new
    template.name="Send %AMOUNT% of %CARGO% to %DESTINATION%"
    
    onMars = KuiAtCondition.new
    onMars.locations << @mars
    template.worthy << onMars
    
    congratulate = KuiInfoAction.new('Thanks!')
    template.setup << congratulate
    
    reminderCheck = KuiIfThen.new
    reminder=KuiInfoAction.new("Don't deliver this here!")
    reminderCheck.ifs << onMars
    reminderCheck.thens << reminder
    template.checks << reminderCheck
    
    cargoGen = KuiRandomCargo.new
    cargoGen.template = template
    cargoGen.min_amount = 5
    cargoGen.max_amount = 5
    cargoGen.cargo << @cargo
    cargoGen.destinations << @earth
    
    generated = cargoGen.generate
    assert_equal(1, generated.size)
    cargo_mission = generated[0]
    
    # Check name templating
    assert_equal("Send 5 of Fruit to Earth",cargo_mission.name)
    
    # Check 'worthy' condition
    assert_equal(2,cargo_mission.worthy.size)
    assert_equal(onMars,cargo_mission.worthy[0])
    
    free = cargo_mission.worthy[1]
    assert_equal(5,free.minimum)

    # Check 'setup'
    assert_equal(2,cargo_mission.setup.size)
    assert_equal(congratulate,cargo_mission.setup[0])
    
    award = cargo_mission.setup[1]
    assert_equal(5,award.amount)
    assert_equal(@cargo.blueprint,award.cargo.blueprint)
    
    # Check end conditions
    assert_equal(2,cargo_mission.checks.size)
    ifthen = cargo_mission.checks[0]
    assert_equal(reminderCheck,ifthen)
    
    ifthen = cargo_mission.checks[1]
    assert_equal(1,ifthen.ifs.size)
    # At earth
    assert_equal(1,ifthen.ifs[0].locations.size)
    assert_equal(@earth,ifthen.ifs[0].locations[0])
    
    # Check reward
    assert_equal(3,ifthen.thens.size)
    assert_equal(1000,ifthen.thens[1].amount)
    
  end
  
  def test_simple_fetch
    
    template = KuiMission.new
    template.name="Go to %DESTINATION%, get %AMOUNT% %CARGO%, and bring it back"
    
    cargoGen = KuiRandomFetch.new
    cargoGen.template = template
    cargoGen.min_amount = 5
    cargoGen.max_amount = 5
    cargoGen.cargo << @cargo
    cargoGen.destinations << @earth
    
    generated = cargoGen.generate(@mars)
    assert_equal(1, generated.size)
    cargo_mission = generated[0]
    
    assert_equal("Go to Earth, get 5 Fruit, and bring it back",cargo_mission.name)
    
    assert_equal(2,cargo_mission.checks.size)
    # Test phase I: mars to earth
    ifthen = cargo_mission.checks[0]
    assert_equal(2, ifthen.ifs.size)
    assert_equal(@earth, ifthen.ifs[0].locations[0]) # At earth
    assert_equal(2, ifthen.thens.size)
    flag = ifthen.thens[1]
    flag_tag = flag.flag_tag
    
    # Test phase II: earth back to mars
    ifthen = cargo_mission.checks[1]
    assert_equal(2, ifthen.ifs.size)
    assert_equal(flag_tag,ifthen.ifs[1].flag_tag)
    
  end
  
  def test_simple_scout
    
    template = KuiMission.new
    template.name = "Scout the planet %DESTINATION%"
    
    scoutGen = KuiRandomScout.new
    scoutGen.template = template
    scoutGen.destinations << @earth
    
    generated = scoutGen.generate
    assert_equal(KuiMission, generated[0].class)
    scout_mission = generated[0]
    
    assert_equal("Scout the planet Earth", scout_mission.name)
    
    # check end condition
    assert_equal(1, scout_mission.checks.size)
    ifthen = scout_mission.checks[0]
    assert_equal(1, ifthen.ifs.size)
    # At earth
    assert_equal(1, ifthen.ifs[0].locations.size)
    assert_equal(@earth, ifthen.ifs[0].locations[0])
    
  end
  
  def test_simple_bounty

    @martianShip = @ship.dup # Martians look just like us
    @martianShip.name = "Martians"
    @martianShips = KuiFleet.new
    @martianShips.tag = 'fixture_martian_fleet'
    @martianShips.ships << @martianShip
    @martianShips.ships << @martianShip
    @martianShips.ships << @martianShip
    
    @venusianShips = @martianShips.dup # They all look alike to us
    @venusianShips.name = "Venusians"
    
    template = KuiMission.new
    template.name = "Go to %DESTINATION% and drive off %FLEET%"
    
    bountyGen = KuiRandomBounty.new
    bountyGen.template = template
    bountyGen.fleets << @martianShips
    bountyGen.destinations << @earth # They're invading.  Yes, again.
    
    generated = bountyGen.generate
    assert_equal(1,generated.size)
    bounty_mission = generated[0]
    
    assert_equal("Go to Earth and drive off Martians", bounty_mission.name)
    
    assert_equal(1,bounty_mission.setup.size)
    spawn = bounty_mission.setup[0]
    assert_equal(1,spawn.fleets.size)
    fleet = spawn.fleets[0]
    assert_equal(@martianShips, fleet)
    
  end
  
  # Not, strictly speaking, a test of the random mission system - but it relies
  # heavily on this override working, so I test it here.
  # It is not an exhaustive test - there is a 1.75e-44 percent chance it will
  # give a false negative.
  def test_randomness
    samples = Set.new
    1000.times do 
      samples << (1..10).random
    end
    (1..10).each do | i |
      assert(samples.include?(i), "Samples does not include #{i}")
    end
    samples.each do |i|
      assert(i >= 1 && i <= 10, "Sample out of bounds: #{i}")
    end
  end
end