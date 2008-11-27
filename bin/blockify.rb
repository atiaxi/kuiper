#!/usr/bin/env ruby

$: << 'lib'

require 'rubygame'
require 'engine'
require 'kuiwidgets'

def blockify
  
  tile_width = nil
  tile_height = nil
  dest = nil
  
  offset = 0
  ARGV.each do | filename |
    tile = Rubygame::Surface.load_image(filename)
    unless tile_width
      tile_width = tile.w
      tile_height = tile.h
      dest = Rubygame::Surface.new([tile_width*6,tile_height*6])
      dest.fill([255,0,255])
    end
    offset_x = (offset % 6) * tile_width
    offset_y = (offset / 6) * tile_height
    tile.blit(dest,[offset_x,offset_y])
    offset += 1
  end
  
  return dest
  
end

class Animator < Opal::State

  def initialize(driver,image)
    super(driver)
    @image = image
    @shipButton = ShipImageButton.new
    @shipButton.raw_image = image
    self << @shipButton
  end
  
end

def setup_screen
  Rubygame.init
  mode = Rubygame::DOUBLEBUF
  return Rubygame::Screen.set_mode([640,480],0,mode)
end

def main
  screen = setup_screen
  
  if screen
    img = blockify
    img.savebmp("blockify.out.bmp")
    engine = Opal::Engine.new()
    engine << Animator.new(engine,img)
    
    engine.run
  end
end

if File.basename($0) == File.basename(__FILE__)
  main
end