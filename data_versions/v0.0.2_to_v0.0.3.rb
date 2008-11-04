#!/usr/bin/env ruby

# Ruby's XML interpreter preserves newlines in attributes, which is, strictly
# speaking, against the XML spec.  Now that I'm moving the attributes to
# text elements of my own, this is biting me in the ass.  xsltproc(1)
# actually obeys the spec, and thus ignores the newlines.  This script acts
# likqe the xslt would if it worked the way I wanted it to.  Hopefully, now
# that this version and later will actually obey the spec, I won't have to
# write this kind of thing again.

require 'rexml/document'

def handle_fields_of(element)
  attributes = element.attributes
  result = REXML::Element.new('fields')
  tag = nil
  attributes.each do | name, value |
    if name == 'tag'
      tag = value
    else
      attr_element = REXML::Element.new(name.strip)
      value_element = REXML::CData.new(value)
      #puts value_element.to_s
      attr_element.add(value_element)
      result.add(attr_element)
    end
  end
  return result, tag
end

def handle_object(element)
  result = REXML::Element.new(element.name)
  fields,tag = handle_fields_of(element)
  result.add_attribute('tag',tag) if tag
  children = handle_children_of(element)
  
  result.add(fields)
  result.add(children)
  return result
end

def handle_children_of(element)
  result = REXML::Element.new('children')
  element.each_element do | child |
    result.add(handle_specific_child(child))
  end
  return result
end

def handle_specific_child(element)
  result = REXML::Element.new(element.attributes["name"])
  element.each_element do | ref |
    if ref.name == 'ref'
      result.add(ref)
    else
      result.add(handle_object(ref))
    end
  end
  return result
end

doc = REXML::Document.new(gets(nil))
result = REXML::Document.new
kuiper = REXML::Element.new("kuiper")
kuiper.add_attribute("major",'0')
kuiper.add_attribute("minor",'0')
kuiper.add_attribute("bug",'3')

doc.root.elements.each do | element |
  kuiper.add(handle_object(element))
end

result.add(kuiper)
result.write($stdout,2)