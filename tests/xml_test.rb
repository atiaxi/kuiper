#!/usr/bin/env ruby

require 'kuiobject'
require 'kuispaceworthy'
require 'repository'
require 'test/unit'
require 'stringio'
require 'tempfile'

require 'setup_bootstrap'

class TC_Xml_Export < Test::Unit::TestCase
  
  def setup
    @rl = Opal::ResourceLocator.instance
    @rl.storage[:repository] = Repository.new
    @rl.repository.universe = KuiUniverse.new
    
    @playerShip = KuiShip.new
    @playerShip.tag = 'player_ship'
    @rl.repository.universe.player.start_ship = @playerShip
    
    @default = KuiObject.new
    @default.tag = "default"
    
    @org = KuiOrg.new
    @org.tag = "org1"
    @org.name="Awesomesauce"
    
    @cargoBlueprint = KuiCargoBlueprint.new
    @cargoBlueprint.tag = "cargo_fruit"
    @cargoBlueprint.name = "fruit"
    
    @cargo = KuiCargo.new
    @cargo.tag = "cargo"
    @cargo.blueprint = @cargoBlueprint
    @cargo.markup = 10
    
    @planet = KuiPlanet.new
    @planet.tag = "planet"
    @planet.name = "New Mars"
    @planet.cargo_for_sale << @cargo
    @planet.owner = @org
    
    @sector = KuiSector.new
    @sector.tag = "sector"
    @sector.name = "Sectorland"
    @sector.planets << @planet
    
    @otherSector = KuiSector.new
    @otherSector.tag = "other sector"
    @otherSector.name = "Sectorville"
    
    @otherPlanet = KuiPlanet.new
    @otherPlanet.tag = "other_planet"
    @otherPlanet.name="New New Mars"
    @otherSector.planets << @otherPlanet 
    
    @thirdPlanet = KuiPlanet.new
    @thirdPlanet.tag = "third_planet"
    @thirdPlanet.name="New New New Mars"
    @otherSector.planets << @thirdPlanet
    
    @shipBlueprint = KuiShipBlueprint.new
    @shipBlueprint.tag = "scout_class"
    @shipBlueprint.name="Scout"
    @shipBlueprint.image_filename='shuttle.png'
    
    @ship = KuiShip.new
    @ship.blueprint = @shipBlueprint
    @ship.facing.angle = 45.0.to_radians
    @ship.velocity.x = 10
    @ship.velocity.y = 20
    
    @weaponBlueprint = KuiWeaponBlueprint.new
    @weaponBlueprint.tag = "laser"
    @weaponBlueprint.auto_accelerate = false
    
    @fleet = KuiFleet.new
    @fleet.tag = "fleet_test"
    @fleet.behavior = :patrol
    
  end
  
  def test_default_obj
    default_xml = "<object tag='default' labels=''/>"
    assert(@default.to_xml.to_s == default_xml)
  end
  
  # Tests cargos and cargo blueprints
  def test_cargo    
    e = @cargo.to_xml
    assert(e.attribute('tag').value == @cargo.tag)
    blueprint = e.get_elements("child[@name='blueprint']/ref")[0]
    assert_not_nil(blueprint)
    assert(blueprint.attribute('tag').value == @cargoBlueprint.tag)
  end
  
  # Mainly to test enums
  def test_fleet_roundtrip
    xml = @fleet.to_xml.to_s
    doc = REXML::Document.new(xml)
    fleet = KuiObject.from_xml(doc.root)
    #assert(fleet == @fleet)
    # Specifially test enums
    assert(fleet.behavior == @fleet.behavior)
  end
  
  # Title screen uses this technique to get text for scenarios
  def test_name_extraction
    repo = Repository.new
    @rl.storage[:repository] = repo
    uni = Bootstrapper.new().universe
    
    doc = repo.to_xml_document
    kuiper = doc.root
    
    name = kuiper.get_elements("universe")[0].attribute('name').value
    assert_not_nil(name)
    assert_equal(uni.name,name)
    desc = kuiper.get_elements("universe")[0].attribute('description').value
    assert_not_nil(desc)
    assert_equal(uni.description,desc)
  end
 
  def test_org
   e = @org.to_xml
   assert(e.attribute('neutral').value.to_i == 0)
   relations = e.get_elements("*/relation")
   relation = relations[0]
   assert(relation.attribute('feeling').value.to_i == KuiOrg::FANATIC_DEVOTION)
   refs = relation.get_elements("child/ref")
   ref = refs[0]
   assert(ref.attribute('tag').value == @org.tag)  
 end
 
 def test_planet
   e = @planet.to_xml
   assert(e.attribute('tag').value == @planet.tag)
   cargo = e.get_elements("child[@name='cargo_for_sale']/ref")[0]
   assert(cargo.attribute('tag').value == @cargo.tag)
   org = e.get_elements("child[@name='owner']/ref")[0]
   assert(org.attribute('tag').value == @org.tag)
 end
 
  def test_sector
    e = @sector.to_xml
    assert(e.attribute('tag').value == @sector.tag)
    planet = e.get_elements("child['planets']/ref")[0]
    assert(planet.attribute('tag').value == @planet.tag)
  end
  
  # Ship blueprint's image wasn't getting exported for some reason
  def test_ship_blueprint
    e = @shipBlueprint.to_xml
    assert(e.attribute('image_filename').value == @shipBlueprint.image_filename)
  end
  
  # If we see a ref before we see what it refers to, we need to make a note of
  # that.
  def test_placeholder
    xml = "<ship tag=\"foo\">"+
      "<child name=\"blueprint\">"+
      "<ref tag=\"shabarg\" name=\"werg\"/>"+
      "</child>"+
      "</ship>"
    doc = REXML::Document.new(xml)
    ship = KuiObject.from_xml(doc.root)
    xml = "<shipblueprint tag=\"shabarg\"></shipblueprint>"
    doc = REXML::Document.new(xml)
    blue = KuiObject.from_xml(doc.root)
    @rl.repository.resolve_placeholders
    assert(ship.blueprint == blue)
  end
  
  # Before I do the placeholder tests (and after it's implemented) I want to
  # make sure that plain vanilla references work as well
  def test_ref
    xml = "<shipblueprint tag=\"shabarg\"></shipblueprint>"
    doc = REXML::Document.new(xml)
    blue = KuiObject.from_xml(doc.root)
    xml = "<ship tag=\"foo\">" +
          "<child name=\"blueprint\">"+
          "<ref tag=\"shabarg\"/>"+
         "</child>"+
          "</ship>"
    doc = REXML::Document.new(xml)
    ship = KuiObject.from_xml(doc.root)
    assert(ship.blueprint == blue)
  end
  
  # Element names seemed to be overriding name attributes
  # That turned out to not be the case, but if the bug ever comes back, this
  # test will pass while test_full_circle will fail.
  # In that case, check Repository::add
  def test_restore_name
    xml = "<universe name='New Universe'/>"
    doc = REXML::Document.new(xml)
    uni = KuiObject.from_xml(doc.root)
    assert(uni.name == 'New Universe')
  end
  
  # This test case is in place because the from_xml wasn't working
  # on things which were not direct descendantds of KuiObject
  def test_restore_object_simple
    xml = "<ship tag='foo'/>"
    doc = REXML::Document.new(xml)
    ship = KuiObject.from_xml(doc.root)
    assert(ship.class == KuiShip)
  end
  
  def test_restore_simple_roundtrip
    xml = @cargoBlueprint.to_xml.to_s
    doc = REXML::Document.new(xml)
    cargoBlueprint = KuiObject.from_xml(doc.root)
    assert(cargoBlueprint.tag == @cargoBlueprint.tag)
  end
  
  def test_restore_embed_single
    xml = @cargo.to_xml.to_s
    doc = REXML::Document.new(xml)
    cargo = KuiObject.from_xml(doc.root)
    assert(cargo.blueprint.tag == @cargoBlueprint.tag)
  end
  
  def test_restore_embed_list
    xml = @otherSector.to_xml.to_s
    doc = REXML::Document.new(xml)
    sector = KuiObject.from_xml(doc.root)
    assert(sector.planets[0] == @otherPlanet)
    assert(sector.planets[1] == @thirdPlanet)
  end
  
  def test_restore_embed_ref
    xml = @org.to_xml.to_s
    doc = REXML::Document.new(xml)
    org = KuiObject.from_xml(doc.root)
    assert(org.feelings_for(org) == KuiOrg::FANATIC_DEVOTION)
  end
  
  # attributes that rely on ftors aren't getting saved.
  def test_restore_ftor
    xml = @ship.to_xml.to_s
    doc = REXML::Document.new(xml)
    ship= KuiObject.from_xml(doc.root)
    # == doesn't work, because they're actually a very very little bit
    # different.  But I don't care.
    assert(ship.facing.angle - @ship.facing.angle < 1e-10)
    assert(ship.velocity == @ship.velocity)
  end
  
  # Non-player ships aren't getting their weapons restored
  def test_restore_weapon
    @ship.add_weapon(@weaponBlueprint)
    xml = @ship.to_xml.to_s
    doc = REXML::Document.new(xml)
    ship = KuiObject.from_xml(doc.root)
    ship.setup_firing_order
    assert(ship.weapons.size > 0)
  end
  
  # Seemingly some problems with the loading routines giving null universes
  # if the universe tag is changed
  def test_filesystem_full_circle
    repo = Repository.new
    @rl.storage[:repository] = repo
    uni = Bootstrapper.new.universe
    uni.name="werg"
    uni.player.start_ship.name = 'fnord'
    assert_not_nil(uni.player.start_ship)
    repo.root = uni
    assert_equal('universe',repo.root.tag)
    
    temp_file = Tempfile.new('kuiper_xml_test')
    @rl.repository.to_xml(temp_file)
    original_sio = StringIO.new
    @rl.repository.to_xml(original_sio)
    temp_file.close
    
    loaded_repo = Repository.new
    loaded_repo.add_from_file(temp_file.path)
    
    assert_not_nil(loaded_repo.universe)
    assert_equal(repo.universe,loaded_repo.universe)
    assert_not_nil(loaded_repo.universe.player)
    assert_not_nil(loaded_repo.universe.player.start_ship)
    assert_equal(repo.universe.player.start_ship.name,
      loaded_repo.universe.player.start_ship.name)

    temp_file.unlink
  end
  
  def test_full_circle
    repo = Repository.new
    @rl.storage[:repository] = repo
    uni = Bootstrapper.new().universe
    assert_not_nil(uni.player.start_ship)
    repo.root = uni
    
    sio = StringIO.new
    repo.to_xml(sio)
    xml = sio.string
    
    #puts xml
    
    repo = Repository.new
    @rl.storage[:repository] = repo
    repo.add(xml)
    repo.resolve_placeholders
    assert_not_nil(repo.root)
    assert_not_nil(repo.universe.player)
    assert_not_nil(repo.universe.player.start_ship)
    assert(repo.root == uni)
  end
  
  # Mainly to test booleans
  def test_weapon_roundtrip
    xml = @weaponBlueprint.to_xml.to_s
    doc = REXML::Document.new(xml)
    blueprint = KuiObject.from_xml(doc.root)
    assert(blueprint == @weaponBlueprint)
    #Specifically testing boolean roundtrips
    assert(blueprint.auto_accelerate == @weaponBlueprint.auto_accelerate)
  end
  
  # Our parser is very sensitive to whitespace being anywhere.  In theory (glug)
  # this shouldn't matter, because you can jam up the XML into one line and it
  # works just fine.  However, it sucks for readability and editability.  Also,
  # I'd like to count scenario lines as lines of code and can't while it's just
  # one line.  It works when this passes.
  def test_whitespace
    xml = "<ship tag=\"foo\">"+
          "  <child name=\"blueprint\">"+
          "    <shipblueprint tag=\"shabarg\"/>"+
          "  </child>"+
          "</ship>"
    doc = REXML::Document.new(xml)
    assert_nothing_raised { KuiObject.from_xml(doc.root) }
  end
  
  # Not specifically an xml test, but a repository test instead
  def test_unique_tag
    test_size = 10001
    answers = Set.new
    test_size.times do
      chosen = @rl.repository.ensure_unique_tag("blarg")
      @rl.repository.register_tag_for("shabarg",chosen)
      answers << chosen
    end
    assert(answers.size == test_size)
  end
  
end