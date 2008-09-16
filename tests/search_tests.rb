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