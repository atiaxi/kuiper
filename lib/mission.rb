
require 'kuidialogs'

class MissionEvaluatorState
  
  include Waker
  
  attr_reader :done
  
  # Missions are the missions to check or award
  def initialize(driver, missions, host)
    @driver = driver
    @missions = missions.dup
    @done = false
    @host = host
    setup_waker
  end
  
  # Use this entry point to check whether to award a mission
  def award
    @host.continue = self
    @missions.each do | mission |
      input = mission.awardable?
      result = handle_responses(input)
      if result == true
        popup = mission.award
        result = handle_responses(popup)
      end
    end
    return true
  end
  
  # Here's where we pretend to be a continuation, so as to call our own
  def call
    self.activate
  end
  
  # Use this entry point to check on existing missions
  def check
    @host.continue = self
    result = true
    @missions.each do | mission |
      input = mission.check
      result = handle_responses(input)
    end
    
    return result
  end
  
  # Returns whether the popups returned what we expected
  # Will return nil if we just ceded control to a dialog
  def handle_popup(item)
    result = true
    @host.continue = self
    popup = InfoDialog.new(@driver, item.message)
    case(item)
    when KuiInfoAction
      callcc do | cont |
        @continue = cont
        @driver << popup
      end
      return nil unless popup.result
    when KuiYesNoCondition
      popup.choices = [ ["Yes",item.expected_response],
                        ["No",!item.expected_response] ]
      callcc do | cont |
        @continue = cont
        @driver << popup
        return nil
      end
      result = popup.result
    end
    return result
  end
   
  def handle_responses(responses)
    while responses.respond_to?(:each)
      question, cont = responses
      handled = handle_popup(question)
      return nil if handled == nil
      question.resolve(handled)
      cont.call
    end
    return responses
  end
    
end

class MissionState < DataActionDialog
  
  include Waker
  
  def initialize(driver, all_missions)
    @missions = all_missions
    super(driver)
  end
  
  def accept_mission
    mission = @itemList.chosen
    if mission
      @eval = MissionEvaluatorState.new(@driver, [mission], self)
      @eval.award
      setup_gui
    end
  end
  
  def layout_actions
    @acceptField = Button.new("Accept this mission") { self.accept_mission }
    layout_action(@acceptField)
  end
  
  def layout_data
    @title = Label.new("Missions Available")
    layout_data_item(@title)
    
    w = @mainRect.w / 4 * 3
    @itemList = ListBox.new
    @itemList.rect.w = w
    @itemList.rect.h = @mainRect.h / 2
    @itemList.displayBlock { | mission | mission.name }
    @itemList.items = self.qualified_missions
    @itemList.chooseCallback do
      preview(@itemList.chosen)
    end
    layout_data_item(@itemList)
    
    @description = MultiLineLabel.new
    @description.rect.w = @itemList.rect.w
    layout_data_item(@description)
    
  end
  
  def preview(chosen)
    @description.text = chosen.description if chosen
  end
  
  def qualified_missions
    return @missions.select { |m| m.awardable? == true }
  end
  
end