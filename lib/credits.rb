
# The Kuiper credits.  In addition to being valid code,
# should also be human-readable.

require 'banner'

def generate_credits
  root = []
  
  root << Title.new("Kuiper")
  root << SubTitle.new("Development")
  
  devs = []
  devs << ['Created By', 'Roger Ostrander']
  devs << ['Snippets From', 'Why the Lucky Stiff']
  devs << ['','AI for game programmers (TODO: Get full cite)']
  devs << ['rubyscript2exe.rb courtesy', 'Erik Veenstra']
  devs << ['','http://www.erikveen.dds.nl/rubyscript2exe/index.html']
  root << Table.new(devs)
  
  root << SubTitle.new("Other Art")

  other = []
  other << ['LiberationSans-Bold.ttf','Red Hat Liberation Fonts']
  other << ['Source:','https://www.redhat.com/promo/fonts/']
  other << ['License:',"GPL2+"]
  other << ['','']

  other << ['kuiper.png', 'NASA, The Hubble Heritage Team (AURA/STScI), ESA']
  other << ['Source',
    'http://hubblesite.org/newscenter/archive/releases/2000/06/image/a/']
  other << ['License:','Public Domain']
  root << Table.new(other)
  
  myCredit = "All images not listed above were created by Roger Ostrander and "+
    "are freely licensed as Creative Commons Attribution Share-Alike "+
    " (http://creativecommons.org/licenses/by-sa/3.0/us/)"
  
  root << MultiText.new(myCredit)
  
  root << SubTitle.new("Thanks To")
  
  thanks = []
  thanks << [ "The Rubygame Library:", "John Croisant"]
  thanks << [ "","Ash Wilson"]
  thanks << [ "","Rusterholz Stefan"]
  thanks << [ "","Bjorn De Meyer"]
  thanks << [ "","" ]
  thanks << [ "The Ruby-Talk mailing list",""]
  thanks << [ "","" ]
  thanks << [ "Software:","Ruby" ]
  thanks << [ "","Trac" ]
  thanks << [ "","Git"]
  thanks << [ "","Eclipse and the Ruby Development Tools"]
  thanks << [ "","Blender"]
  root << Table.new(thanks)
    
  return root
end
