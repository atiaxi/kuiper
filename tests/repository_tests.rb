
require 'test/unit'

class TC_Repository_Tests < Test::Unit::TestCase
  
  def setup
    @rl = Opal::ResourceLocator.instance
    @rl.storage[:repository] = Repository.new
    @repo = @rl.repository
    @repo.universe = KuiUniverse.default
    @player = @repo.universe.player
    
    @foo = KuiObject.new
    @foo.tag = "barf"
    @foo.labels = "foo, planet, werg,obj"
    
    @bar = KuiObject.new
    @bar.tag = "shabarg"
    @bar.labels = "baz,omg,obj"
  end
  
  def test_all_labels
    
    labels = @repo.all_labels
    assert_equal(6,labels.size)
    ['foo','planet','werg','obj','baz','omg'].each do |label|
      assert(labels.include?(label))
    end
  end
  
  def test_label_search
    objs = @repo.everything_with_label('obj')
    assert_equal(2,objs.size)
    assert(objs.include?(@foo))
    assert(objs.include?(@bar))
    
    bazs = @repo.everything_with_label('baz')
    assert_equal(1,bazs.size)
    assert(bazs.include?(@bar))
    
    nothings = @repo.everything_with_label('xyzzy')
    assert_not_nil(nothings)
    assert_equal(0,nothings.size)
  end
  
  def test_labels_search
    objs = @repo.everything_with_labels(['foo','baz'])
    assert_equal(2,objs.size)
    assert(objs.include?(@foo))
    assert(objs.include?(@bar))
    
    bazs = @repo.everything_with_labels(['baz','xyzzy'])
    assert_equal(1,bazs.size)
    assert(bazs.include?(@bar))
    
    nothings = @repo.everything_with_labels(['xyzzy'])
    assert_not_nil(nothings)
    assert_equal(0,nothings.size)
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