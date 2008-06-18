# Editor for planets and everything on them.
# This includes things like ships, weapons, etc, even
# though they're not planet specific

require 'editor'

class CargoEditor < PropertiesDialog
  def self.handles?(type)
    return type == KuiCargo
  end
  
  def initialize(cargo, driver)
    @cargo = cargo
    super
  end
  
  def layout_children
    if @cargo.blueprint && @cargo.blueprint.playable?
      @blueprintButton = Button.new(@cargo.blueprint.tag) { set_blueprint }
      @blueprintButton.rect.topright = [@mainRect.right - @spacing , @childY ]
      self << @blueprintButton
      
      @label = Label.new("Blueprint:")
      @label.rect.topright = [@blueprintButton.rect.x - @spacing, @childY]
      self << @label
      next_child(@blueprintButton)
    else
      @blueprintButton = Button.new("Set Blueprint") { set_blueprint }
      layout_child(@blueprintButton)
    end
  end
  
  def set_blueprint
    kos = CargoSelectorDialog.new(@driver, true)
    callcc do |cont|
      @driver << kos
      @continue = cont
    end
    
    if kos.chosen && kos.chosen.playable?
      @cargo.blueprint = kos.chosen
      setup_gui
    end
  end
end

class PlanetEditor < PropertiesDialog
  
  def self.handles?(type)
    return type == KuiPlanet
  end
  
  def initialize(planet, driver)
    @planet = planet
    super
  end
    
  def layout_children
    
    if @planet.image_filename
      @imageButton = ImageButton.new(@planet.image_filename) { self.set_image }
      @imageButton.max_size = [50,50]
    else
      @imageButton = Button.new("Set Image") { self.set_image }
    end
    layout_child(@imageButton)
    
    owned_text = @planet.owner ? @planet.owner.name : 'Nobody'
    @ownerButton = Button.new("Owned by #{owned_text}") { self.set_owner }
    layout_child(@ownerButton)
    
    @missionBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@planet.missions, KuiMission),"Missions")
    layout_minibuilder_field(@missionBuilder)
  
    @plotBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@planet.plot, KuiMission), "Plots")
    layout_minibuilder_field(@plotBuilder)
    
    @randomBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@planet.random_missions, KuiMissionGenerator), 
                     "Random Missions")
    layout_minibuilder_field(@randomBuilder)
    
    @cargoBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@planet.cargo_for_sale, KuiCargo), "Cargo")
    layout_minibuilder_child(@cargoBuilder)  
    
    @addonBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@planet.addons_for_sale, KuiAddon), "Addons")
    layout_minibuilder_child(@addonBuilder)
    
    @weaponBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@planet.weapons_for_sale, KuiWeaponBlueprint), "Weapons")
    layout_minibuilder_child(@weaponBuilder)
    
    @shipBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@planet.ships_for_sale, KuiShip), "Ships")
    layout_minibuilder_child(@shipBuilder)
    
  end
  
  def set_image
    isd = ImageSelectorDialog.new(@driver, false)
    callcc do | cont |
      @driver << isd
      @continue = cont
    end
    
    rl = ResourceLocator.instance
    if isd.chosen && rl.image_for(isd.chosen)
      @image_filename = isd.chosen
      setup_gui
    end
  end
  
  def set_owner
    kos = KuiObjectSelector.new(@driver, KuiOrg)
    callcc do | cont |
      @driver << kos
      @continue = cont
    end
    
    if kos.chosen && kos.chosen.playable?
      @planet.owner = kos.chosen
      setup_gui
    end
  end
end

class ShipBlueprintEditor < PropertiesDialog
  def self.handles?(type)
    return type == KuiShipBlueprint
  end
  
  def initialize(blueprint, driver)
    @blueprint = blueprint
    super
  end
  
  def layout_children
    layout_image_child("Image", @blueprint.image_filename) { self.set_image }
  end

  def set_image
    isd = ImageSelectorDialog.new(@driver,true)
    callcc do |cont|
      @driver << isd
      @continue = cont
    end
    
    rl = ResourceLocator.instance
    if isd.chosen && rl.image_for(isd.chosen)
      @blueprint.image_filename = isd.chosen
      setup_gui
    end
  end
end

class ShipEditor < PropertiesDialog
  
  def self.handles?(type)
    return type == KuiShip
  end
  
  def initialize(ship, driver)
    @ship = ship
    super
  end
  
  def layout_children
    x = @mainRect.right - @spacing
    if @ship.blueprint && @ship.blueprint.playable?
      @label = Label.new("Blueprint:")
      @label.rect.topright = [x, @childY ]
      self << @label
      next_child(@label)
      
      @blueprintButton = ShipImageButton.new(@ship.blueprint.image_filename) {
        self.set_blueprint }
      @blueprintButton.rect.topright = [x, @childY ]
      self << @blueprintButton
    else
      @blueprintButton = Button.new("Set Blueprint") { self.set_blueprint }
      @blueprintButton.rect.topright = [ x, @childY]
      self << @blueprintButton
    end
    next_child(@blueprintButton)
    
    @weaponBuilder = MiniBuilder.new(@driver,ShipWeaponAdapter.new(@ship),
      "Weapons")
    @weaponBuilder.rect.w = @mainRect.right - @fieldRight - (@spacing*2)
    @weaponBuilder.refresh
    layout_child(@weaponBuilder)
    @wakeup_widgets << @weaponBuilder
  end
  
  def set_blueprint
    kos = ShipSelectorDialog.new(@driver,true)
    callcc do | cont |
      @driver << kos
      @continue = cont
    end
    
    if kos.chosen && kos.chosen.playable?
      @ship.blueprint = kos.chosen
      setup_gui
    end
  end
end

class WeaponBlueprintEditor < PropertiesDialog
  def self.handles?(type)
    return type == KuiWeaponBlueprint
  end
  
  def initialize(weapon, driver)
    @weapon = weapon
    super
  end
  
  def layout_children
    layout_image_child("Image", @weapon.image_filename) { self.set_image }  
    
    @ammoBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@weapon.ammo, KuiWeaponBlueprint), "Ammo")
    layout_minibuilder_child(@ammoBuilder)
    
    @addonBuilder = MiniBuilder.new(@driver, 
      @weapon.anti_addons.as_adapter(KuiAddon), "Anti-addons")
    layout_minibuilder_child(@addonBuilder)    
  end
  
  def set_ammo
    kos = KuiObjectSelector.new(@driver, KuiWeaponBlueprint)
    builder = BuilderDialog.new(@driver, @weapon.ammo, kos)
    @driver << builder
  end
  
  def set_anti_addons
    kos = KuiObjectSelector.new(@driver, KuiAddon)
    builder = BuilderDialog.new(@driver, @weapon.anti_addons, kos)
    @driver << builder
  end
  
  def set_image
    isd = ImageSelectorDialog.new(@driver,true)
    callcc do |cont|
      @driver << isd
      @continue = cont
    end
    
    rl = ResourceLocator.instance
    if isd.chosen && rl.image_for(isd.chosen)
      @weapon.image_filename = isd.chosen
      setup_gui
    end
  end
end

