require 'engine'

class Adapter

  def initialize(wrap)
    @adaptee = wrap
    @rl = Opal::ResourceLocator.instance
  end
  
  def <<(item)
    add_item(item)
  end
  
  # Override this to do adaptee-specific additions
  def add_item(item, amount=1)
    
  end
  
  # This should return a common superclass that all items will share.
  # Used by editors, selectors, etc.
  def constraint
    return Object
  end
  
  # This should return a list of items the adaptee contains
  def items
    
  end
  
  # Override this to do adaptee-specific removals
  def remove_item(item, amount=1)
    
  end
  
end

class ListAdapter < Adapter
  
  def initialize(wrap, type = nil)
    super(wrap)
    @create_type = type
  end
  
  def add_item(item, amount = 1)
    amount.times { @adaptee << item }
  end
  
  def constraint
    return @create_type
  end
  
  def items
    return @adaptee
  end
  
  # For now, this removes the exact item; change that behavior isn't what we're
  # expecting.  It also deletes all of that item in the list
  def remove_item(item, amount=1)
    @adaptee.delete(item)
  end
end

class ReadOnlyListAdapter < ListAdapter
  def remove_item(item, amount=1)
  end
  
  def add_item(item, amount = 1)
    amount # So eclipse won't complain
  end
end

class PlayerMissionAdapter < Adapter
  
  def initialize(player)
    super
  end
  
  # Directly adds the given mission to the player; does none of the setup
  # actions in the process - in non-edit modes, KuiMission::award is probably
  # what you're looking for.
  def add_item(item,amount=1)
    @adaptee.add_mission(item)
    amount # So eclipse won't yell at me
  end
  
  def constraint
    return KuiMission
  end
  
  def items
    @adaptee.missions
  end
  
  # Directly removes the given mission from the player; as in add_item, this
  # performs none of the cleanup. Amount is ignored
  def remove_item(item, amount=1)
    @adaptee.remove_mission(item)
  end
  
end

# This is a READ ONLY adapter for the repository
class RepositoryAdapter < Adapter
  
  # You don't need to provide the repository to wrap, this will get it from the
  # resourcelocator.  Filter is the kind of objects to show.
  def initialize(filter = KuiObject, base_only=true)
    @rl = Opal::ResourceLocator.instance
    super(@rl.repository)
    @constraint = filter
    @base_only = base_only
  end
  
  def constraint
    return @constraint
  end
  
  def items
    return @adaptee.everything_of_type(@constraint, @base_only).sort
  end
  
end

# Any adapter that represents something the player can pay for and put on their
# ship should include Buyable.
# Note that this is intended for adapters, but may work if you have an @adaptee
module Buyable

  # This subtracts the cost of the item(s) from the player's store.
  # Note that it does not actually give the item; that's handled in
  # BuilderDialog
  def buy(item,amount)
    cost = item.price * amount
    player = ResourceLocator.instance.repository.universe.player
    player.credits -= cost
  end

  def can_afford_item?(item, amount)
    cost = item.price * amount
    player = ResourceLocator.instance.repository.universe.player
    return player.credits >= cost
  end
  
  # This also screens for amounts <= 0
  def can_fit_item?(item, amount)
    return false if amount <= 0
    result = true
    self.requires.each do | key |
      avail = amount_free(key)
      result = result && (avail >= amount)
    end
    return result
  end
  
  def amount_free(requirement)
    to_call = ("available_"+requirement).to_sym
    if @adaptee
      return @adaptee.send(to_call)
    end
    return 0
  end
  
  # Returns a list of "properties" that this kind of adapter requires in its
  # target ships (e.g. "hardpoints" or "cargo")
  def requires
    return []
  end
  
end

class ShipAddonAdapter < Adapter
  
  include Buyable
  
  def initialize(ship)
    super(ship)
  end
  
  def add_item(item, amount=1)
    @adaptee.add_addon(item, amount)
  end
  
  def constraint
    return KuiAddon
  end
  
  def items
    return @adaptee.addons
  end
  
  # Removes the given addon
  def remove_item(item, amount=1)
    @adaptee.remove_addon(item,amount)
  end
  
  def requires
    return [ "expansion", "hardpoints" ]
  end
  
end

class ShipAllCargoAdapter < Adapter
  
  include Buyable
  
  def initialize(ship)
    super(ship)
  end

  def add_item(item, amount=1)
    @adaptee.add_cargo(item, amount)
  end
  
  def constraint
    return KuiCargo
  end
  
  def items
    return @adaptee.all_cargo
  end

  def remove_item(item, amount=1)
    @adaptee.remove_cargo(item,amount)
  end
  
  def requires
    return [ "cargo" ]
  end
  
end


class ShipCargoAdapter < ShipAllCargoAdapter
    
  def items
    return @adaptee.non_mission_cargo
  end
  
end

class ShipWeaponAdapter < Adapter

  include Buyable
  
  def initialize(ship)
    super(ship)
  end
  
  def add_item(item, amount=1)
    award = item.amount == 0 ? amount : item.amount
    @adaptee.add_weapon(item, award, !$edit_mode)
  end
  
  def constraint
    return KuiWeaponBlueprint
  end
  
  def items
    return @adaptee.all_weapons
  end
  
  def remove_item(item, amount=1)
    @adaptee.remove_weapon(item, amount)
  end
  
  def requires
    return [ "expansion", "hardpoints" ]
  end
  
end