require 'search'

class TC_Repository_Search < Test::Unit::TestCase

  def setup
    @rl = Opal::ResourceLocator.instance
    @rl.storage[:repository] = Repository.new
    @repo = @rl.repository
    @repo.universe = KuiUniverse.new
    @player = @repo.universe.player
    
    @foo = KuiObject.new
    @foo.tag = "barf"
    @foo.labels = "foo, planet, werg"
  end
  
  # Did you know that tests will fail if you define an empty class?
  def test_placeholder
    assert(true)
  end
  
end

class TC_Search < Test::Unit::TestCase
  
  def setup
    
    @sol = KuiSector.new
    @sol.tag = 'sol'
    
    @centauri = KuiSector.new
    @centauri.tag = 'centauri'
    @centauri.links_to << @sol
    @sol.links_to << @centauri
    
    @medregg = KuiSector.new
    @medregg.tag = 'medregg'
    @medregg.links_to << @sol
    @sol.links_to << @medregg
    
    @centMed = SectorSearcher.new(@centauri, @medregg)
    @solCent = SectorSearcher.new(@sol, @centauri)
    @solMed =  SectorSearcher.new(@sol, @medregg)
  end
  
  def test_breadth_first
    course = @centMed.breadth_first
    assert_not_nil(course)
    assert_equal(3, course.size)
    assert_equal( [@centauri, @sol, @medregg], course)
    
    course = @solCent.breadth_first
    assert_not_nil(course)
    assert_equal(2, course.size)
    assert_equal( [@sol,@centauri], course)
    
    course = @solMed.breadth_first
    assert_not_nil(course)
    assert_equal(2, course.size)
    assert_equal( [@sol, @medregg], course)
  end
  
end

class TC_Array_Addons < Test::Unit::TestCase
  
  def setup
    @array = [1,1,2,3,3,2,1,1]
  end
  
  def test_delete_first
    @array.delete_first(2)
    assert_equal(7,@array.size)
    assert_equal(4,@array.index(2))
  end
  
end