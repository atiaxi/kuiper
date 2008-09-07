#!/usr/bin/env ruby

require 'kuiobject'
require 'kuispaceworthy'
require 'repository'
require 'test/unit'

class TC_Player < Test::Unit::TestCase
  
  def setup
    @rl = Opal::ResourceLocator.instance
    @rl.storage[:repository] = Repository.new
    @rl.repository.universe = KuiUniverse.new
    @player = @rl.repository.universe.player
  end
  
  def test_unnamed
    assert(@player.unnamed?)
    # Empty names should count as un-named
    @player.name = ''
    assert(@player.unnamed?)
  end
  
  def test_labels
    assert_equal(0, @player.label_array.size)
    assert_equal("", @player.labels)
    
    @player.labels = "foo,bar,,bAz, quux"
    assert_equal(4, @player.label_array.size)
    assert_equal("bar", @player.label_array[1])
    
    # test space reduction
    assert_equal("quux", @player.label_array[3])
    # test case insensitivity
    assert_equal("baz", @player.label_array[2])
  end
  
  def test_label_persist
    @player.labels = "abcd,hijk"
    xml = @player.to_xml.to_s
    doc = REXML::Document.new(xml)
    player = KuiObject.from_xml(doc.root)
    assert_equal(@player.labels,player.labels)
  end
  
end

class TC_Org < Test::Unit::TestCase
  
  def setup
    @rl = Opal::ResourceLocator.instance
    @rl.storage[:repository] = Repository.new
    
    @martians = KuiOrg.new
    @martians.tag = "martians"
    
    @venusians = KuiOrg.new
    @venusians.tag = "venusians"
    
    @earthicans = KuiOrg.new
    @earthicans.tag = "earthicans"
    
    @mars2venus = KuiRelation.new
    @mars2venus.target_org = @venusians
    @mars2venus.feeling = @martians.kill_on_sight
    @martians.feelings << @mars2venus
    
    # And the feeling's mutual
    @venus2mars = KuiRelation.new
    @venus2mars.target_org = @martians
    @venus2mars.feeling = @venusians.kill_on_sight
    @venusians.feelings << @venus2mars
  end
  
  def test_blueprint_delegation
    @shipBlueprint = KuiShipBlueprint.new
    @shipBlueprint.tag = "scout_class"
    @shipBlueprint.name="Scout"
    @shipBlueprint.image_filename='shuttle.png'
    @shipBlueprint.max_speed = 4000
    
    @ship = KuiShip.new
    @ship.tag = 'fixture_ship'
    @ship.blueprint = @shipBlueprint
    assert_equal(4000,@ship.max_speed)

    @cargoBlueprint = KuiCargoBlueprint.new
    @cargoBlueprint.description = "Lengthy!"
    @cargo = KuiCargo.new
    @cargo.blueprint = @cargoBlueprint
    assert_equal("Lengthy!", @cargo.description)
    
  end
  
  def test_labels
    relation = @martians.relation_for(@earthicans)
    assert(@martians.symbol_for_attitude(@earthicans) == :neutral)
    
    # Steal a few Martian ships
    relation.feeling = -750
    assert(@martians.symbol_for_attitude(@earthicans) == :unfriendly)
    
    # Abduct a Martian Princess
    relation.feeling = -1250
    assert(@martians.symbol_for_attitude(@earthicans) == :kill_on_sight)
    
    # Return princess, spend a lot of money, big PR campaign
    relation.feeling = 510
    assert(@martians.symbol_for_attitude(@earthicans) == :friendly)
    
    # Blow up venus
    relation.feeling = 10000
    assert(@martians.symbol_for_attitude(@earthicans) == :devoted)
  end
  
  def test_new_relation
    relation = @martians.relation_for(@earthicans)
    second_relation = @martians.relation_for(@earthicans)
    assert(relation.equal?(second_relation))
  end
  
  def test_random_shooting
    # Earth declares war on mars
    before_mars = @martians.feelings_for(@earthicans)
    before_venus = @venusians.feelings_for(@earthicans)
    @martians.org_shot_me(@earthicans)
    after_mars = @martians.feelings_for(@earthicans)
    after_venus = @venusians.feelings_for(@earthicans)
    diff_mars = before_mars - after_mars
    
    # Martians should dislike us
    assert(diff_mars == -@martians.shooting_mod)
    
    # Venusians should approve
    diff_venus = before_venus - after_venus
    adjusted_mod = @martians.shooting_mod * @venusians.gullibility
    assert(diff_venus == adjusted_mod)
  end
  
  def test_killing
    # War.  War never changes.
    before_mars = @martians.feelings_for(@earthicans)
    @martians.org_killed_me(@earthicans)
    after_mars = @martians.feelings_for(@earthicans)
    diff_mars = before_mars - after_mars
    
    assert(diff_mars == -@martians.killing_mod)
  end
  
  def test_friendly_fire
    # rescue a martian princess
    @martians.receive_feeling_change(@martians, @earthicans, 1000000)
    
    # Give them a parting shot
    before_mars = @martians.feelings_for(@earthicans)
    assert_equal(1000000, before_mars)
    @martians.org_shot_me(@earthicans)
    after_mars = @martians.feelings_for(@earthicans)
    
    diff_mars = before_mars - after_mars
    # Are we still pals?
    assert_equal(diff_mars,-(@martians.shooting_mod *
      @martians.friendly_multiplier))
  end
  
  def test_apathy
    # The martians and the venusians continue their bloody conflict
    before = @earthicans.feelings_for(@venusians)
    @martians.org_shot_me(@venusians)
    after = @earthicans.feelings_for(@venusians)
    
    # Ensure we still don't care
    assert(before == after)
    
  end
  
end

class TC_WeaponsAndShips < Test::Unit::TestCase
  
  def setup
    @rl = Opal::ResourceLocator.instance
    @rl.storage[:repository] = Repository.new
    @rl.repository.universe = KuiUniverse.new

    @blueprint = KuiShipBlueprint.new
    @blueprint.hardpoints = 10
    @blueprint.expansion_space = 50

    @playerShip = KuiShip.new
    @playerShip.blueprint = @blueprint
    @playerShip.tag = 'player_ship'
    @rl.repository.universe.player.start_ship = @playerShip
    
    @otherShip = KuiShip.new
    @otherShip.tag = "other_ship"
    
    @primary = KuiWeaponBlueprint.new
    @primary.tag = 'primary'
    @primary.hardpoints_required = 1
    
    @secondary = KuiWeaponBlueprint.new
    @secondary.tag = 'secondary'
    @secondary.secondary_weapon = true
    
    @ammo = KuiWeaponBlueprint.new
    @ammo.tag = 'ammo'
    @ammo.is_ammo = true
    @ammo.expansion_required = 1
    
  end
  
  # While editing, if I add a weapon to a ship, then add that same weapon, the
  # original one I'm adding from also displays x2.  test_primary there seems
  # to indicate that they're two different objects, but it doesn't test the
  # adapters
  def test_adapters
    # This was to test building, specifically, so edit mode is on
    $edit_mode = true
    left = ShipWeaponAdapter.new(@playerShip)
    right = RepositoryAdapter.new(KuiWeaponBlueprint)
    
    assert_equal(3, right.items.size)
    
    primary = right.items[0]
    assert_equal(primary, @primary)
    
    # Repository adapter is supposedly read-only
    right.remove_item(primary)
    assert_equal(3, right.items.size)
    
    # Test moving primary over
    left.add_item(primary)
    right.remove_item(primary)
    
    # Weapon should have been duped
    assert_not_equal(left.items[0], primary)
    assert_equal(left.items[0].base_tag, primary.base_tag)
    assert_not_equal(left.items[0].tag, primary.tag)
    
    assert_not_nil(@rl.repository.everything[left.items[0].tag])
    assert_equal(3, right.items.size)
    $edit_mode = false
  end
  
  def test_primary
    @playerShip.add_weapon(@primary)

    # Make sure we can find it
    found = @playerShip.find_weapon(@primary)
    assert(found)
    # Make sure it's been duped
    assert_not_equal(found,@primary)
    # But that it's fundamentally the same
    assert(found.base_tag == @primary.base_tag)
    
    # Make sure it registered as a primary
    assert(@playerShip.weapons.index(found))
    assert_nil(@playerShip.secondaries.index(found))
    
    # Add another one
    @playerShip.add_weapon(@primary)
    
    found = @playerShip.find_weapon(@primary)
    assert(found.amount == 2)
    assert_equal(0, @primary.amount)
    
    # Remove one
    @playerShip.remove_weapon(@primary)
    found = @playerShip.find_weapon(@primary)
    assert(found.amount == 1)
    
    @playerShip.remove_weapon(@primary)
    found = @playerShip.find_weapon(@primary)
    assert_nil(found)
    
    # Should be the same for non-player ships
    # This used to not be the case, keeping these tests in to make sure all is
    # well.
    @otherShip.add_weapon(@primary)
    found = @otherShip.find_weapon(@primary)
    assert(found != @primary)
    assert(found.base_tag == @primary.base_tag)
  end
  
  def test_secondary
    @playerShip.add_weapon(@secondary)
    
    # Make sure we can find it
    found = @playerShip.find_weapon(@secondary)
    assert_not_nil(found)
    # Make sure it's been duped
    assert_not_equal(found,@secondary)
    # But that it's fundamentally the same
    assert(found.base_tag == @secondary.base_tag)
    
    # Make sure it registered as a secondary
    assert_nil(@playerShip.weapons.index(found))
    assert_not_nil(@playerShip.secondaries.index(found))
    
    # Add another one
    @playerShip.add_weapon(@secondary)
    
    found = @playerShip.find_weapon(@secondary)
    assert(found.amount == 2)
    
    @playerShip.remove_weapon(@secondary)
    found = @playerShip.find_weapon(@secondary)
    assert(found.amount == 1)
    
    @playerShip.remove_weapon(@secondary)
    found = @playerShip.find_weapon(@secondary)
    assert_nil(found)
    
  end
  
  def test_ammo
    # Technically, I should be telling it not to set up the firing order here.
    # But there was a bug where it would re-set the ammo list, so the test stays
    # as is.
    @playerShip.add_weapon(@ammo)
    
    # Make sure we can find it
    found = @playerShip.find_weapon(@ammo)
    assert_not_nil(found)
    # Make sure it's been duped
    assert_not_equal(found,@ammo)
    # But that it's fundamentally the same
    assert(found.base_tag == @ammo.base_tag)
    
    # Make sure it registered as a ammo
    assert_nil(@playerShip.weapons.index(found))
    assert_nil(@playerShip.secondaries.index(found))
    assert_not_nil(@playerShip.ammo.index(found))
    
    # Add another one
    @playerShip.add_weapon(@ammo)
    
    found = @playerShip.find_weapon(@ammo)
    assert(found.amount == 2)
  end
  
  def test_secondary_with_ammo
    @secondary.ammo << @ammo
    @playerShip.add_weapon(@secondary)
    
    @playerShip.add_weapon(@ammo)
    
    weapon = @playerShip.find_weapon(@secondary)
    assert_not_nil(weapon)
    
    new_ammo = @playerShip.find_weapon(@ammo)
    assert_not_nil(new_ammo)
    assert_not_equal(new_ammo, @ammo)
    
    assert_not_equal(weapon.ammo[0], @ammo)
    assert_equal(weapon.ammo[0], new_ammo)
    
  end
  
  def test_ammo_with_secondary
    @secondary.ammo << @ammo
    @playerShip.add_weapon(@ammo)
    @playerShip.add_weapon(@secondary)
    
    weapon = @playerShip.find_weapon(@secondary)
    assert_not_nil(weapon)
    
    new_ammo = @playerShip.find_weapon(@ammo)
    assert_not_nil(new_ammo)
    assert_not_equal(new_ammo, @ammo)
    
    assert_not_equal(weapon.ammo[0], @ammo)
    
  end

  # For a while, each weapon only counted as 1 hardpoint, regardless of how many
  # of the weapons you had.
  def test_hardpoints
    hp = @playerShip.available_hardpoints
    
    @playerShip.add_weapon(@primary)
    assert_equal(hp-1, @playerShip.available_hardpoints)

    @playerShip.add_weapon(@primary)
    assert_equal(hp-2, @playerShip.available_hardpoints)
    
  end
  
  # I suspect expansion has the same problem that hardpoints had.
  def test_expansion
    hp = @playerShip.available_expansion
    
    @playerShip.add_weapon(@ammo)
    assert_equal(hp-1, @playerShip.available_expansion)

    @playerShip.add_weapon(@ammo)
    assert_equal(hp-2, @playerShip.available_expansion)
    
  end
  
end

class TC_Cargo < Test::Unit::TestCase

  def setup
    @rl = Opal::ResourceLocator.instance
    @rl.storage[:repository] = Repository.new
    @rl.repository.universe = KuiUniverse.new

    @shipPrint = KuiShipBlueprint.new
    @shipPrint.max_cargo = 10

    @player = @rl.repository.universe.player

    @playerShip = KuiShip.new
    @playerShip.blueprint = @shipPrint
    @playerShip.tag = 'player_ship'
    @player.start_ship = @playerShip
    
    @cargoBlueprint = KuiCargoBlueprint.new
    @cargoBlueprint.tag = "cargo_fruit"
    @cargoBlueprint.name = "fruit"
    
    @cargo = KuiCargo.new
    @cargo.tag = "cargo"
    @cargo.blueprint = @cargoBlueprint
    @cargo.markup = 10
  end
 
  def test_dupes
    # Give the player some fruit
    @playerShip.add_cargo(@cargo, 10)
    assert_equal(0, @cargo.amount) # Original should be unchanged
    assert_not_equal(@cargo.tag, @playerShip.cargo[0].tag)
    
    assert_equal(0, @playerShip.available_cargo)
  end
  
  def test_buy_new_ship
    @otherShip = KuiShip.new
    @otherShip.blueprint = @playerShip.blueprint
    
    # No cargo on board, this should work
    assert(@playerShip.can_transfer_to?(@otherShip))
    
    @cargo.mission_related = true
    @playerShip.add_cargo(@cargo, 10)
    assert(@playerShip.can_transfer_to?(@otherShip))
    @player.credits = -1000
    assert(!@player.can_buy_ship?(@otherShip))
    @player.credits = 1000
    assert(@player.can_buy_ship?(@otherShip))
    
    @playerShip.add_cargo(@cargo, 1)
    assert(!@playerShip.can_transfer_to?(@otherShip))
    
    @player.buy_ship(@otherShip)
    assert_equal(@otherShip, @player.start_ship)
  end
  
end