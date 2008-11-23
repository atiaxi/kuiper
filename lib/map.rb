
require 'engine'
require 'overrides'
require 'search'

# This is exactly the same as ordinary buttons, but can hold a number of halos
# to be drawn behind it.
class HaloButton < Opal::Button
  
  HALO_THICKNESS = 3
  
  def initialize(text='', size=12, font=$FONT, &callback)
    @halos = []
    super(text,size,font,&callback)
  end
  
  def halos=(list)
    @halos = []
    @halos += list
    self.border_thickness = @halos.size * HALO_THICKNESS + 1
  end
  
  def add_halo(halo)
    unless @halos.include?(halo)
      @halos << halo
      self.border_thickness = @halos.size * HALO_THICKNESS + 1
    end
  end
  
  def remove_halo(halo)
    if @halos.delete(halo)
      self.border_thickness = @halos.size * HALO_THICKNESS + 1
    end
  end
  
  def text=(string)
    super(string)
    inset = 1
    @halos.each do | halo |
      (0...HALO_THICKNESS).each do | offset |
        set = @border_thickness - inset - offset
        @image.draw_box([set,set],
          [@image.w - set, @image.h-set], halo.as_color)
      end
      inset += HALO_THICKNESS
    end
  end
  
end

# The map state serves three purposes: To be used by the player to navigate,
# to be used by the editor to select a sector, and as the map editor itself.
class MapState < Opal::State
  
  attr_accessor :select_mode
  attr :selected
  
  SCROLL_SPEED = 10
  SECTOR_DEPTH = 100
    
  def self.select_mode(driver)
    result = self.new(driver)
    result.select_mode = true
    return result
  end
  
  def initialize(driver)
    super(driver)
    @center = nil
    @link_mode = false
    @new_sector_mode = false
    @select_mode = false
    @rl = ResourceLocator.instance
    @spacing = 3
    
    @selection_halo = KuiHalo.new(255,255,255)
    
    reload_sectors
    self.center = nil
    self.selected = nil
    
  end
  
  def activate
    reload_sectors
  end
  
  def add_one
    @rl.repository.universe.player.start_ship.itinerary << @selected
    reload_sectors
  end
  
  def clear_course
    @rl.repository.universe.player.start_ship.itinerary.clear
    reload_sectors
  end
  
  def center=(rect)
    @center = rect
    reload_sectors
  end
  
  def del_sector
    unlink_sector
    # TODO: A more thorough search of the models to make sure
    # this sector's not referenced anywhere
    @selected
    @map.delete(@selected)
    reload_sectors
  end
  
  def done
    button = @sectors_to_buttons[@selected]
    button.remove_halo(@selection_halo) if button
    @driver.pop
  end
  
  def draw(screen)
    @buttons_to_sectors.each do | button, sector |
      sector.links_to.each do | link |
        target = @sectors_to_buttons[link]
        if target
          # I'd wanted to avoid popping in and out of the screen, but it
          # appears that I can't without causing random crashes due to SDL_gfx
          # not liking off-screen co-ords (but only sometimes)
          cropRect = @rl.screen_rect
          cropButton = Rubygame::Rect.new(button.rect.centerx,
            button.rect.centery, 1, 1)
          cropTarget = Rubygame::Rect.new(target.rect.centerx,
            target.rect.centery, 1, 1)
          next unless cropRect.contain?(cropButton)
          next unless cropRect.contain?(cropTarget)
          
          #@rl.logger.debug("Button rect: #{cropButton.center}, target rect: #{cropTarget.center}")
          screen.draw_line(cropButton.center,
                           cropTarget.center,
                          [255,255,255])
        end
      end
    end
    super
  end
  
  def link_sector()
    if @link_mode
      @link_mode = false
      @link_button.text = "Link this sector"
      @link_button.rect.right = @done.rect.right
      @unlink_button.visible = true
    else
      @link_mode = true
      @link_button.text = "Click a sector to link to, or click here to cancel"
      @link_button.rect.right = @done.rect.right
      @unlink_button.visible = false
    end
  end
  
  def map_button(source)
    self.selected = source
  end
  
  def mouseUp(event)
    if @new_sector_mode
      x,y = event.pos
      if @new_sector.rect.collide_point?(x,y)
        super
      else
        s = KuiSector.new
        s.name = "New Sector"
        #s.tag = "new_sector"
      
        dx = x - @rl.screen.width / 2
        dy = @rl.screen.height / 2 - y
        s.x = @center.x + dx
        s.y = @center.y - dy
        @map.sectors << s
      
        reload_sectors
      end
    else
      super
    end
  end
  
  def new_sector
    if @new_sector_mode
      @new_sector_mode = false
      @new_sector.text = "New Sector"
      @new_sector.rect.right = @done.rect.right
    else
      @new_sector_mode = true
      @new_sector.text = "Click to place the new sector.  Click here to cancel"
      @new_sector.rect.right = @done.rect.right
    end
  end
  
  def plot_course
    player = @rl.repository.universe.player
    src = player.start_sector
    dest = @selected
    if @selected
      s = SectorSearcher.new(src, dest)
      itin = s.breadth_first
      itin.delete_at(0)
      player.start_ship.itinerary = itin
    end
    reload_sectors
  end
  
  def props
    if @selected
      dialog = SectorEditor.new(@selected, @driver)
      @driver << dialog
    end
  end
  
  def reload_edit_mode
    bottom = @done.rect.top - @spacing
  
    right = @done.rect.right
  
    @new_sector_mode = false
    @new_sector = Button.new("New Sector") { self.new_sector }
    @new_sector.rect.bottomright = [ right, bottom ]
    self << @new_sector
    bottom = @new_sector.rect.top - @spacing
    
    @del_button = Button.new("Delete this sector") { self.del_sector }
    @del_button.rect.bottomright = [ right, bottom ]
    @del_button.enabled = false
    self << @del_button
    bottom = @del_button.rect.top - @spacing
    
    @link_mode = false
    @link_button = Button.new("Link this sector") {self.link_sector}
    @link_button.rect.bottomright = [ right, bottom ]
    @link_button.enabled = false
    self << @link_button
    
    @unlink_button = Button.new("Unlink this sector") { self.unlink_sector }
    @unlink_button.rect.bottomright = [ @link_button.rect.left - @spacing,
      bottom]
    @unlink_button.enabled = false
    self << @unlink_button
    bottom = @link_button.rect.top - @spacing
    
    @props = Button.new("Properties") { self.props }
    @props.rect.bottomright = [ right, bottom ]
    @props.enabled = false
    self << @props
    bottom = @props.rect.top - @spacing
    
    operators = [ @new_sector, @del_button, @link_button,
        @unlink_button, @props ]
    rects = operators.collect {|o| o.rect }
    leftmost = rects.min { |r,s| r.x <=> s.x }
    h = @rl.screen_rect.bottom - @spacing - bottom
    box = Box.new
    box.rect.x = leftmost.x - @spacing
    box.rect.y = bottom
    box.rect.w = @rl.screen_rect.right - box.rect.x
    box.rect.h = h
    self << box
  end
  
  def reload_playing_mode
    bottom = @done.rect.top - @spacing
    right = @done.rect.right
    
    @plot_course = Button.new("Plot Course") { plot_course }
    @plot_course.rect.bottomright = [right, bottom ]
    @plot_course.enabled = false
    self << @plot_course
    
    bottom = @plot_course.rect.top - @spacing
    @clear_course = Button.new("Clear Course") { clear_course }
    @clear_course.rect.bottomright = [right, bottom]
    itin = @rl.repository.universe.player.start_ship.itinerary
    @clear_course.enabled = itin.size > 0
    self << @clear_course
    
    bottom = @clear_course.rect.top - @spacing
    @add_to_itin = Button.new("Add to itinerary") { add_one }
    @add_to_itin.rect.bottomright = [ right, bottom]
    @add_to_itin.enabled = false
    self << @add_to_itin
    
    right = @rl.screen_rect.w
    itin_label = Label.new("Itinerary:")
    itin_label.rect.topright = [ right - 3, 3 ]
    self << itin_label
    
    y = itin_label.rect.bottom + 3
    
    @itinerary = ListBox.new
    @itinerary.rect.width = 200
    @itinerary.rect.height = 150
    itin = @rl.repository.universe.player.start_ship.itinerary
    names = itin.collect do | sector |
      sector.name
    end
    @itinerary.items = names
    @itinerary.translate_to( right - 203, y)
    self << @itinerary
  end
  
  def reload_sectors
    universe = @rl.repository.universe
    
    @map = universe.map
    self.clear
    @buttons_to_sectors = {}
    @sectors_to_buttons = {}
    rect = @rl.screen_rect
    
    @selected_box = Box.new
    @selected_box.rect.x = 0
    @selected_box.rect.y = 0
    @selected_box.rect.w = @rl.screen_rect.w
    @selected_box.rect.h = 1
    self << @selected_box
    
    @selected_label = Label.new("<No sector selected>")
    @selected_label.rect.topleft = [3,3]
    self << @selected_label
    
    @selected_desc = MultiLineLabel.new
    @selected_desc.rect.topleft = [6, @selected_label.rect.bottom + 3]
    @selected_desc.rect.w = rect.w - 200
    self << @selected_desc
    
    @done = Button.new("Done") { self.done }
    @done.rect.bottomright = [ rect.right - @spacing, rect.bottom - 3 ]
    self << @done
    
    unless @center
      @current_sector ||= universe.player.start_sector
      @center = Rubygame::Rect.new(@current_sector.x, @current_sector.y, 1, 1)
    end

    @map.sectors.each do | sector |
      name = sector.name
      links_to_us = []
      unless $edit_mode
        name = 'Unknown' unless sector.visited
      
        links_to_us = @map.sectors.select { |s| s.links_to.include?(sector) }
      end  
      if sector.visited || links_to_us.detect { |s| s.visited } || $edit_mode
        button = HaloButton.new(name) { self.map_button(sector) }
        @buttons_to_sectors[button] = sector
        @sectors_to_buttons[sector] = button
        button.halos = sector.halos
        button.depth = SECTOR_DEPTH
        self << button 
      end
    end
    
    translate_sectors
    
    if $edit_mode
      reload_edit_mode
    else
      # TODO: At some point, I'm going to want to switch the usual sector
      #       selection dialog for this fancy map state; we'll need to do more
      #       setup then.
      reload_playing_mode
    end
    
    @sectors_to_buttons = @buttons_to_sectors.invert
  end
  
  def selected=(sector)
    previous = @selected
    if @link_mode and sector
      if previous != sector
        previous.links_to << sector
        sector.links_to << previous
      else
        link_sector # Should cancel
      end
      reload_sectors
    else
      @selected = sector
      if sector
        name = sector.name
        description = sector.description
        unless sector.visited or $edit_mode
          name = 'Unknown'
          description = 'No data available'
        end
        @selected_label.text = name
        @selected_desc.text = description
        @selected_box.rect.h = @selected_desc.rect.bottom - 
          @selected_label.rect.y + 3
        button = @sectors_to_buttons[sector]
        button.add_halo(@selection_halo)
        if previous && previous != @selected
          prevButton = @sectors_to_buttons[previous]
          prevButton.remove_halo(@selection_halo) if previous && prevButton
        end
        if $edit_mode
          @link_button.enabled = true
          @del_button.enabled = true
          @props.enabled = true
          @unlink_button.enabled = true if sector.links_to.size > 0
        else
          itin = @rl.repository.universe.player.start_ship.itinerary
          last = itin.last
          last = @current_sector unless last # If no itinerary
          @add_to_itin.enabled = last.links_to?(sector)
          @plot_course.enabled = true
          # TODO: Enable buttons, if necessary.
        end
      else
        @selected_label.text = '<No sector selected>'
      end
    end
  end
  
  def translate_sectors
    rect = @rl.screen_rect
    @map.sectors.each do | sector |
      button = @sectors_to_buttons[sector]
      if button
        dx = sector.x - @center.x
        dy = sector.y - @center.y
        #button.rect = rect.move(rect.centerx + dx, rect.centery + dy)
        button.rect.center = [rect.centerx + dx, rect.centery + dy]
      end
   end
  end
  
  def unlink_sector
    sector = @selected
    sector.links_to.each do | target, discard |
      target.links_to.delete(sector)
    end
    sector.links_to.clear
    reload_sectors
    @unlink_button.enabled = false
  end
  
  def update(delay)
    super(delay)
    old_x, old_y = @center.topleft
    if @keyStatus[:up]
      @center.y -= SCROLL_SPEED
    elsif @keyStatus[:down]
      @center.y += SCROLL_SPEED
    end
    
    if @keyStatus[:left]
      @center.x -= SCROLL_SPEED
    elsif @keyStatus[:right]
      @center.x += SCROLL_SPEED
    end
    if @center.x != old_x || @center.y != old_y
      translate_sectors
    end
  end
  
end