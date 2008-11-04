#!/usr/bin/env ruby

# Ruby's XML interpreter preserves newlines in attributes, which is, strictly
# speaking, against the XML spec.  Now that I'm moving the attributes to
# text elements of my own, this is biting me in the ass.  xsltproc(1)
# actually obeys the spec, and thus ignores the newlines.  This script acts
# like the xslt would if it worked the way I wanted it to.  Hopefully, now
# that this version and later will actually obey the spec, I won't have to
# write this kind of thing again.

require 'rexml/document'

def handle_children_of(element)
  child_element = REXML::Element.new(element.attributes["name"])
  element.each_element do | ref |
    child_element.add(ref)
  end
  return child_element  
end

doc = REXML::Document.new(gets(nil))
result = REXML::Document.new
kuiper = REXML::Element.new("kuiper")
kuiper.add_attribute("major",'0')
kuiper.add_attribute("minor",'0')
kuiper.add_attribute("bug",'3')

doc.root.elements.each do | element |
  adapted = REXML::Element.new(element.name)
  # Attributes to elements
  fields = REXML::Element.new('fields')
  element.attributes.each do |name,value|
    attr_element = REXML::Element.new(name.strip)
    value_element = REXML::CData.new(value)
    #puts value_element.to_s
    attr_element.add(value_element)
    fields.add(attr_element)
  end
  adapted.add(fields)
  # Children
  children = REXML::Element.new('children')
  element.each_element do | child |
    children.add(handle_children_of(child))
    
    #children.add(child_element)
  end
  adapted.add(children)
  
  kuiper.add(adapted)
end

result.add(kuiper)
result.write($stdout,2)