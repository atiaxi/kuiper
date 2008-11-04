# Catchall for classes and functions that don't go anywhere else
$ERB_SAFE_LEVEL = 3

$KUIPER_VERSION = [0,0,3]
$QUICKSAVE_SUFFIX = "quicksave"
$AUTOSAVE_SUFFIX="autosave"

# Returns an Ftor for a spot at the given radius
def random_spot(radius)
  angle = rand() * Math::PI * 2
  vec = Rubygame::Ftor.new_am(angle, radius)
  return vec
end


# I'd really like to be able to save the game anywhere
def save_game(pilot_name=nil, qualifier=nil)
  rl = ResourceLocator.instance
  universe = rl.repository.universe
  old_name = universe.name
  
  names = universe_basename(old_name, [pilot_name]).split('-')
  names << pilot_name if pilot_name
  names << qualifier if qualifier
  
  universe.name = names.join("-")
  module_name = universe.name+ ".ksg"
  savepath = rl.dotpath_for("saved_games")
  Dir.mkdir(savepath) unless File.exists?(savepath)
  fullpath = File.join(savepath, module_name)
  File.open(fullpath, "w") do | file |
    rl.repository.to_xml(file)
  end
  universe.name = old_name
end

# Turns out to be easier to save the universe than I thought.
def save_universe(universe)
  module_name = universe.name + ".kui"
  module_dir = universe.name
  rl = ResourceLocator.instance
  if universe.save_as_dev
    fullpath = "./data/#{module_dir}/"
  else
    fullpath = rl.dotpath_for(module_dir)
  end
  Dir.mkdir(fullpath) unless File.exists?(fullpath)
  fullpath = File.join(fullpath, module_name)
  File.open(fullpath, "w") do | file |
    rl.repository.to_xml(file)
  end
end

# Prints a stacktrace (unfortunately, includes the call to stacktrace)
def stacktrace
  begin; raise; rescue Exception => e; puts e.backtrace; end
end

# What the basic name of the universe is.  One named foo-pilot-autosave, for
# example, would just be 'foo', assuming 'pilot' was in screen_array
def universe_basename(fullname, screen_array)
  names = fullname.split('-')
  names = names.reject do | word |
    word == $QUICKSAVE_SUFFIX ||
    word == $AUTOSAVE_SUFFIX ||
    screen_array.include?(word)
  end
  return names.join('-')
end

# Function to check if you have rubygame or
# an extension installed and, if so, whether
# its version is up to snuff.
# library is a symbol of the lib to check in 
# Rubygame::VERSIONS (i.e. :sdl_image) and version
# is a tuple of version information (i.e. [1,2,5])
# returns whether the current version is greater than
# or equal to the given one.  If the version is nil,
# this will merely check to see if the library is installed at all
def version_check(library, version=nil)
  built = Rubygame::VERSIONS[library]
  return false unless built
  if version
    major,minor,bug = version
    built_major,built_minor,built_bug = built
    return true if built_major > major
    return false if built_major < major
    
    return true if built_minor > minor
    return false if built_minor < minor
    
    return false if built_bug < bug
  end
  return true
end

# Originally created because YAML had problems with things that needed objects
# as keys in hashes.  Kept because it's useful to have a serializable set
class ArraySet < Array
  
  # There are other methods (concatenation, etc) that bypass this one and can
  # make invalid sets, but I just use <<, so this /should/ work.
  def <<(item)
    self.push(item) if (not self.include?(item))
  end
  
  def +(array)
    result = self.dup
    array.each { |x| result << x }
    return result
  end

end