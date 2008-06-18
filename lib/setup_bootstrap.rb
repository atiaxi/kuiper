#!/usr/bin/env ruby

# This script is designed to setup the bootstrap.kui file

require 'repository'
require 'kuiobject'
require 'kuispaceworthy'
require 'engine'

class Bootstrapper
  
  def initialize
    
  end
  
  def setup_player_org
    playorg = KuiOrg.new
    playorg.name = "The Player"
    playorg.tag = "org_player"
    return playorg
  end  

  def setup_ship_blueprints
    result = []
    
    scout = KuiShipBlueprint.new
    scout.image_filename = 'shuttle.png'
    scout.max_shields = 100
    scout.max_armor = 100
    scout.rot_per_sec = 200.0
    scout.accel = 150.0
    scout.max_speed = 200.0
    scout.secs_to_jump = 3.0
    scout.name="Scout"
    scout.tag="scout_class"
    result << scout
    
    return result
  end
  
  def setup_ships(blueprints)
    result = []
    
    scout = KuiShip.new
    scout.blueprint = blueprints[0]
    scout.shields = 100
    scout.armor = 100
    scout.name = "Scout"
    scout.tag = "scout_bare"
    scout.fuel = scout.max_fuel
    #scout.velocity = Rubygame::Ftor.new( 0, 0 )
    result << scout
    
    return result
  end

  # Main entry point
  def universe
    uni = KuiUniverse.new
    sector = KuiSector.new
    sector.name = 'Start Sector'
    sector.tag = 'start_sector'
    uni.map.sectors << sector
    uni.player.start_sector = sector
    uni.name = "New Universe"
    uni.tag = "universe"
    uni.description = "Describe your new universe here"
    
    blues = setup_ship_blueprints
    ships = setup_ships(blues)
    
    uni.player.org = setup_player_org 
    uni.player.start_ship = ships[0]
    uni.player.start_ship.owner = uni.player.org
    uni.player.credits = 1000
     
    return uni
  end
  
end


def main
  rl = Opal::ResourceLocator.instance
  repo = Repository.new
  rl.storage[:repository] = repo  
  
  bs = Bootstrapper.new
  
  repo.root = bs.universe
  repo.to_xml
end

if $0 == __FILE__
  main()
end