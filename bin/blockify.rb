#!/usr/bin/env ruby

$: << 'lib'

$BLOCKIFY_VERSION = [ 1, 0, 0]

require 'rubygame'
require 'engine'
require 'kuiwidgets'
require 'ostruct'
require 'optparse'

def blockify(opts)
  
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
      dest.fill(opts.background)
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
  return Rubygame::Screen.set_mode([320,240],0,mode)
end

def parse_args(args = ARGV)
  options = OpenStruct.new
  options.background = [255,0,255]
  
  opts = OptionParser.new do | opts |
    opts.banner = "Usage: blockify [options] 1.png 2.png ... 36.png"
    
    opts.on("-b", "--background R,G,B",
      "Background color, in range of 0-255") do |colors|
        rgb = colors.split(",")
        options.background = rgb.collect { |color| color.to_i }
    end
    
    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
    
    opts.on_tail("--version", "Show version") do
      puts "blockify v#{$BLOCKIFY_VERSION.join(".")}"
      exit
    end
    
  end
  opts.parse!(args)
  return options
end

def main
  opts = parse_args
  screen = setup_screen
  
  if screen
    img = blockify(opts)
    img.savebmp("blockify.out.bmp")
    engine = Opal::Engine.new()
    engine << Animator.new(engine,img)
    
    engine.run
  end
end

if File.basename($0) == File.basename(__FILE__)
  main
end