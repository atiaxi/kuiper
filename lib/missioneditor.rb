require 'editor'

# If-then statements
class IfThenEditor < PropertiesDialog
  def self.handles?(type)
    return type == KuiIfThen
  end
  
  def initialize(ifthen, driver)
    @ifthen = ifthen
    super
  end
  
  def layout_children
    @ifs = MiniBuilder.new(@driver,
      ListAdapter.new(@ifthen.ifs, KuiCondition), "If")
    layout_minibuilder_field_wide(@ifs)
    
    @thens = MiniBuilder.new(@driver,
      ListAdapter.new(@ifthen.thens, KuiAction), "Then")
    layout_minibuilder_field_wide(@thens)
    
  end
end

# For ordinary missions
class MissionEditor < PropertiesDialog
  
  def initialize(mission, driver)
    @mission = mission 
    super
  end
  
  def self.handles?(type)
    return type == KuiMission
  end
  
  def layout_children
    
    @worthy = MiniBuilder.new(@driver,
      ListAdapter.new(@mission.worthy,KuiCondition), "Worthy" )
    layout_minibuilder_field_wide(@worthy)
    
    @setup = MiniBuilder.new(@driver,
      ListAdapter.new(@mission.setup, KuiAction), "Setup")
    layout_minibuilder_field_wide(@setup)
    
    @checks = MiniBuilder.new(@driver,
      ListAdapter.new(@mission.checks, KuiIfThen), "Checks")
    layout_minibuilder_field_wide(@checks) 
    
  end
  
end

# The MultiClassEditor uses these to draw child elements where appropriate
class MultiChildHandler < CompositeSprite
  
  include Layout
  include Waker
  
  def self.handler_for(kuiobj)
    result = self.subclasses(true).detect do |editor|
      editor.handles?(kuiobj)
    end
    return result || self
  end
  
    # Courtesy ruby-talk post 11740
  def self.inherited(subclass)
    if @subclasses
      @subclasses << subclass
    else
      @subclasses = [subclass]
    end
  end
  
  # All the direct subclases of this class.
  # if expand is true, all their subclasses (and so on)
  def self.subclasses(expand = false)
    @subclasses ||= []
    subs = []
    if expand
      subs = @subclasses.collect { |sub| sub.subclasses(true) }
      subs.flatten!
    end
    return @subclasses + subs
  end
  
  def initialize(obj, driver)
    super()
    @object = obj
    @driver = driver
    initial_layout
    setup_waker
  end
  
  def layout_children
  end
  
  # We don't act like other CompositeSprites; we're more
  # like a layout manager, and as such, need a main rect
  def mainRect=(rect)
    @mainRect = rect
    @rect = rect
  end
  
  def rect=(r)
    self.mainRect = r
  end

  def refresh
    setup_gui
  end
  
  def setup_gui
    setup_layout
    
    layout_children
  end
  
end

# For use with KuiAction and KuiConditions, has a class selector on the left
class MultiClassEditor < PropertiesDialog
  
  def self.handles?(type)
    return false # We're abstract
  end
  
  def initialize(object, driver, superclass)
    super(object, driver)
    @edits_on = superclass
    @allow_changes = !self.specialized
  end
  
  def layout_children
    @wakeup_widgets.delete(@mch) if @mch
    @mch = (MultiChildHandler.handler_for(@object.class)).new(@object,@driver)
    @mch.mainRect = @mainRect
    @mch.fieldRight = @fieldRight
    self << @mch
    @wakeup_widgets << @mch
    @mch.refresh
  end
  
  def setup_class
    if self.specialized
      # TODO: Dialog warning of the change
    end
    if @classes.chosen
      @object = @condition = @classes.chosen.new
      setup_gui
    end
  end
  
  def setup_gui
    @classes = ListBox.new
    listHeight = @classes.height(10)
    @classes.rect.w = 200
    @classes.rect.h = listHeight
    @classes.displayBlock { |item| item.to_s }
    @classes.items = @edits_on.subclasses(true)
    @classes.chosen = self.specialized
    x = @insetX + @spacing
    y = @insetY + @spacing + 50
    @classes.translate_to(x,y)
    @fieldX = @classes.rect.right + @spacing
    
    @classes.enabled = @allow_changes
    
    @classes.chooseCallback { self.setup_class }
    super
    self << @classes
  end
  
  # Whether or not this dialog is working on a subclass
  # Returns the class it's working on or nil
  def specialized
    result = @edits_on.subclasses(true).detect do |c|
      @object.class == c
    end
    return result
  end
  
end

class ActionEditor < MultiClassEditor
  
  def self.handles?(type)
    return true if type == KuiAction
    return KuiAction.subclasses(true).include?(type)
  end
  
  def initialize(action, driver)
    super(action, driver, KuiAction)
  end
end

class ConditionEditor < MultiClassEditor
  
  def self.handles?(type)
    return true if type == KuiCondition
    return KuiCondition.subclasses(true).include?(type)
  end
  
  def initialize(condition, driver)
    super(condition, driver, KuiCondition)
  end
end

class MissionGeneratorEditor < MultiClassEditor

  def self.handles?(type)
    return true if type == KuiMissionGenerator
    return KuiMissionGenerator.subclasses(true).include?(type)
  end
  
  def initialize(generator, driver)
    super(generator,driver,KuiMissionGenerator)
  end
  
end

# The various MultiChildHandlers
class AtHandler < MultiChildHandler
  
  def self.handles?(type)
    return type == KuiAtCondition
  end
  
  def layout_children
    @sectors = MiniBuilder.new(@driver,
      ListAdapter.new(@object.locations, KuiSector), "Sectors")
    layout_minibuilder_child(@sectors)
    
    @planets = MiniBuilder.new(@driver,
      ListAdapter.new(@object.locations, KuiPlanet), "Planets")
    layout_minibuilder_child(@planets)
    
    @orgs = MiniBuilder.new(@driver,
      ListAdapter.new(@object.locations, KuiOrg), "Owned by")
    layout_minibuilder_child(@orgs)
  end
  
end

class AwardCargoHandler < MultiChildHandler
  
  def self.handles?(type)
    return type == KuiAwardRemoveCargoAction
  end
  
  def layout_children
    @cargo = MiniChooser.new(@driver, @object, :cargo, KuiCargo, "Award this:")  
    layout_minichooser_child(@cargo)
  end
  
end

class CompletedHandler < MultiChildHandler
  
  def self.handles?(type)
    return type == KuiCompletedCondition
  end
  
  def layout_children
    @mission = MiniChooser.new(@driver, @object, :completed, KuiMission,
      "Mission")
    layout_minichooser_child(@mission)
  end
end

class DescriptionHandler < MultiChildHandler
  
  def self.handles?(type)
    return type == KuiDescriptionAction
  end
  
  def layout_children
    @target = MiniChooser.new(@driver, @object, :target, KuiMission, "Target")
    layout_minichooser_child(@target)
  end
end

class HaloHandler < MultiChildHandler
  def self.handles?(type)
    return type == KuiHaloAction
  end
  
  def layout_children
    @halo = MiniChooser.new(@driver, @object, :halo, KuiHalo, "Use this halo:")
    layout_minichooser_child(@halo)
    
    @sectors = MiniBuilder.new(@driver,
      ListAdapter.new(@object.sectors, KuiSector), "On these sectors:")
    layout_minibuilder_child(@sectors)
  end
end

class SellItemsHandler < MultiChildHandler
  
  def self.handles?(type)
    return type == KuiSellItemsAction
  end
  
  def layout_children
    @planets = MiniBuilder.new(@driver,
      ListAdapter.new(@object.locations, KuiPlanet), "Planets")
    layout_minibuilder_child(@planets)
    
    @orgs = MiniBuilder.new(@driver,
      ListAdapter.new(@object.orgs, KuiOrg), "Owned by")
    layout_minibuilder_child(@orgs)
    
    @cargoBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@object.cargo, KuiCargo), "Cargo")
    layout_minibuilder_child(@cargoBuilder)  
    
    @addonBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@object.addons, KuiAddon), "Addons")
    layout_minibuilder_child(@addonBuilder)
    
    @weaponBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@object.weapons, KuiWeaponBlueprint), "Weapons")
    layout_minibuilder_child(@weaponBuilder)
    
    @shipBuilder = MiniBuilder.new(@driver,
      ListAdapter.new(@object.ships, KuiShip), "Ships")
    layout_minibuilder_child(@shipBuilder)
  end
  
end

class UnhaloHandler < MultiChildHandler
  
  def self.handles?(type)
    return type == KuiUnhaloAction
  end
  
  def layout_children
    @unhalo = MiniChooser.new(@driver, @object, :haloer, KuiHaloAction,
      "Undo this haloer:")
    layout_minichooser_child(@halo)
  end
  
end

class SpawnHandler < MultiChildHandler
  
  def self.handles?(type)
    return (type == KuiSpawnAction ||
            type == KuiDespawnAction ||
            type == KuiDestroyedCondition)
  end
  
  def layout_children
    @fleets = MiniBuilder.new(@driver,
      ListAdapter.new(@object.fleets, KuiFleet),"Fleets")
    layout_minibuilder_child(@fleets)
    
    unless @object.is_a?(KuiDestroyedCondition)
      @locations = MiniBuilder.new(@driver,
        ListAdapter.new(@object.locations,KuiSector),"Sectors")
      layout_minibuilder_child(@locations)
    end
    
    unless @object.is_a?(KuiSpawnAction)
      @spawner = MiniChooser.new(@driver, @object, :spawner, KuiSpawnAction, 
        "Spawner")
      layout_minichooser_child(@spawner)
    end
  end
  
end

# Randomness
module RandomMissionEditor
  
  def layout_random_mission
    @cleanup = MiniBuilder.new(@driver,
      ListAdapter.new(@object.cleanup, KuiAction), "Cleanup")
    layout_minibuilder_child(@cleanup)
    
    @template = MiniChooser.new(@driver, @object, :template, KuiMission,
      "Template")
    layout_minichooser_child(@template)
  end
  
end
  
module RandomCargoEditor
  
  def layout_random_cargo
    @cargo = MiniBuilder.new(@driver,
      ListAdapter.new(@object.cargo, KuiCargo), "Cargo")
    layout_minibuilder_child(@cargo)
  end
  
end
  
module RandomDestinationEditor
  
  def layout_random_destination
    @destination_sectors = MiniBuilder.new(@driver,
      ListAdapter.new(@object.destinations, KuiSector), "Sectors")
    layout_minibuilder_child(@destination_sectors)
    
    @destination_planets = MiniBuilder.new(@driver,
      ListAdapter.new(@object.destinations, KuiPlanet), "Planets")
    layout_minibuilder_child(@destination_planets)
  end
  
end
  
class RandomCargoHandler < MultiChildHandler
  include RandomMissionEditor
  include RandomDestinationEditor
  include RandomCargoEditor
    
  def self.handles?(type)
    return type == KuiRandomCargo || type == KuiRandomFetch
  end
  
  def layout_children
    layout_random_mission
    layout_random_destination 
    layout_random_cargo
  end
end

class RandomScoutHandler < MultiChildHandler
  include RandomMissionEditor
  include RandomDestinationEditor
    
  def self.handles?(type)
    return type == KuiRandomScout
  end
  
  def layout_children
    layout_random_mission
    layout_random_destination 
  end
end


class RandomBountyHandler < MultiChildHandler
  include RandomMissionEditor
  include RandomDestinationEditor
  
  def self.handles?(type)
    return type == KuiRandomBounty
  end
  
  def layout_children
    layout_random_mission
    layout_random_destination
     
    @fleets = MiniBuilder.new(@driver,
      ListAdapter.new(@object.fleets, KuiFleet), "Fleet")
    layout_minibuilder_child(@fleets)
    
  end
end