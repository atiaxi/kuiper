
class TC_Repository_Tests < Test::Unit::TestCase
  
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
  
  def test_unique_tag
    @blarg = KuiObject.new
    blargtag = "tag_blarg"
    @blarg.tag = @repo.ensure_unique_tag(blargtag)
    # Should not have changed, as tag_blarg didn't exist before
    assert_equal(blargtag,@blarg.tag)
    
    @shabarg = KuiObject.new
    @shabarg.tag = @repo.ensure_unique_tag(blargtag)
    assert_not_equal(blargtag,@shabarg.tag)
    assert_equal(blargtag,@shabarg.base_tag)
  end
  
  def test_generated_tags
    @player.name = "The Player"
    assert_not_nil(@player.name)
    assert_equal("player_player", @repo.generate_tag_for(@player))
    
    @player.name = "The Best Player in the World is from a City in an Arboretum"
    assert_equal("player_best_player_world_city_arboretum",
      @repo.generate_tag_for(@player))
      
    # Make sure a 'the' at the end of something isn't also cut
    @player.name = "blargthe and stuff"
    assert_equal("player_blargthe_stuff",@repo.generate_tag_for(@player))
  end
  
  def test_generated_tag_collision
    @player.name = "The Player"
    @player.tag = "player_player"
    gen = @repo.generate_tag_for(@player)
    # Make sure tag isn't re-set if it's same as original
    assert_equal("player_player",gen)
    
    @player.tag = "something_else"
    gen = @repo.generate_tag_for(@player)
    assert_not_equal("player_player",gen)
    assert_equal("player_player-",gen[0...14])
  end
  
end