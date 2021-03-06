#!/usr/bin/env ruby

require 'options'
require 'test/unit'
require 'engine'

class TC_Options < Test::Unit::TestCase
  
  include Rubygame::Events
  
  def test_keydown
    good_event = KeyPressed.new(:a)
    bad_event = KeyPressed.new(:x)
    canceler = KeyReleased.new(:a)
    bad_canceler = KeyReleased.new(:x)
    right_out = MouseMoved.new([0,0],[0,0])
    
    kdc = KeyDownControl.new('Fire lasers',:a)
    assert(kdc === good_event)
    assert !(kdc === bad_event)
    assert !(kdc === canceler)
    assert kdc.canceled_by?(canceler)
    assert !(kdc.canceled_by?(bad_canceler))
    assert !(kdc === right_out)
    assert !(kdc.canceled_by?(right_out))
  end
  
  def test_joyaxis
    good_event = JoystickAxisMoved.new(0, 1, 1)
    bad_event = JoystickAxisMoved.new(1, 1, 1)
    good_cancel = JoystickAxisMoved.new(0, 1, -1)
    good_cancel2 = JoystickAxisMoved.new(0, 1, 0)
    right_out = KeyPressed.new(:a)
    
    jac = JoyAxisControl.new('Turn left', 0, 1, true)
    assert(jac === (good_event))
    assert(!(jac === bad_event))
    assert jac.canceled_by?(good_cancel)
    assert jac.canceled_by?(good_cancel2)
    assert !(jac.canceled_by?(good_event))
    assert(!(jac === right_out))
    assert !(jac.canceled_by?(right_out))
  end
  
  def test_joyball
    # I don't actually know which direction is 'up'
    # to a joystick trackball, but I'm going to guess -1
    up_event = JoystickBallMoved.new(1,1,[0,-10])
    left_event = JoystickBallMoved.new(1, 1, [-10, 0])
    down_event = JoystickBallMoved.new(1, 1, [ 0, 10])
    weak_upleft = JoystickBallMoved.new(1,1, [ -1, -1])
    wrong_joystick = JoystickBallMoved.new(2, 1 ,[0, -10])
    right_out = KeyPressed.new(:a)
    
    up_jbc = JoyBallControl.new('up',1,1,0,-5)
    upleft_jbc = JoyBallControl.new('upleft',1,1,-5,-5)
    
    assert(up_jbc === up_event)
    assert up_jbc.canceled_by?(down_event)
    assert upleft_jbc.canceled_by?(weak_upleft)
    assert !(up_jbc.canceled_by?(wrong_joystick))
    assert !(up_jbc.canceled_by?(right_out))
    assert !(up_jbc === left_event)
    assert !(up_jbc === down_event)
    assert !(up_jbc === wrong_joystick)
    assert !(up_jbc === right_out)
    assert !(upleft_jbc === weak_upleft)
    assert !(upleft_jbc === up_event)
    
  end
  
  def test_joybutton
    right_event = JoystickButtonPressed.new(1,1)
    canceler = JoystickButtonReleased.new(1,1)
    wrong_stick = JoystickButtonPressed.new(2,1)
    wrong_stick_cancel = JoystickButtonReleased.new(2,1)
    wrong_button = JoystickButtonPressed.new(1,2)
    right_out = KeyPressed.new(:a)
    
    jdc = JoyDownControl.new('Kill Skuls', 1, 1)
    assert jdc === right_event
    assert jdc.canceled_by?(canceler)
    assert !(jdc.canceled_by?(wrong_stick_cancel))
    assert !(jdc === wrong_stick)
    assert !(jdc === wrong_button)
    assert !(jdc === right_out)
  end
  
  def test_joyhat
    right_event = JoystickHatMoved.new(1,1,:left)
    canceler = JoystickHatMoved.new(1, 1, nil)
    wrong_stick = JoystickHatMoved.new(4,1,:left)
    wrong_hat = JoystickHatMoved.new(1,12,:left)
    wrong_direction = JoystickHatMoved.new(1,1,:up_left)
    right_out = KeyPressed.new(:a)
    
    jhc = JoyHatControl.new('Leftier', 1, 1, :left)
    assert jhc === right_event
    assert jhc.canceled_by?(canceler)
    assert !(jhc.canceled_by?(right_event))
    assert !(jhc === wrong_stick)
    assert !(jhc === wrong_hat)
    assert !(jhc === wrong_direction)
    assert !(jhc === right_out)
  end
  
  def test_mousedown
    right_event = MousePressed.new( [0,0],:mouse_left)
    canceler = MouseReleased.new( [0,0], :mouse_left)
    wrong_button = MousePressed.new( [0,0], :mouse_right)  
    right_out = KeyPressed.new(:a)
    
    mdc = MouseDownControl.new('Fire Lasers', :mouse_left)
    
    assert mdc === right_event
    assert mdc.canceled_by?(canceler)
    assert !(mdc.canceled_by?(right_event))
    assert !(mdc === wrong_button)
    assert !(mdc === right_out)
  end
  
  # We test relative motion pretty hard in joyball; since all MouseMotion is is
  # relative motion, there's fewer tests here.  Method's here in case we need to 
  # write more tests
  def test_mousemotion
    canceler = MouseMoved.new([0,0], [10, 10], [])
    smaller_canceler = MouseMoved.new([0,0], [-1, -1], [])
    
    mmc = MouseMotionControl.new('move mouse', -10, -10 )
    
    assert mmc.canceled_by?(canceler)
    assert mmc.canceled_by?(smaller_canceler)
  end
  
end