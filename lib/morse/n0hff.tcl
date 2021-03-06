#
# Copyright (C) 2020 by Roger E Critchlow Jr, Charlestown, MA, USA.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# 
# notes from n0hff's book on the art and skill of radio telegraphy, artskill.pdf from

package provide morse::n0hff 1.0

namespace eval ::morse {}
namespace eval ::morse::n0hff {
    # Some of the published orders for learning the characters are:, artskill.pdf p. 34
    # Several corrections to these made to eliminate duplicates and insert missing letters
    array set data {
	letter-orders {
	    {5 0 E T A R - S L U Q J - H O N C V - I B Y P - W K Z M - D X F G}
	    {F G H M J R U - B D K N T V Y - C E I L O S - A P Q X Z W}
	    {E T A I M N - S O D R C U - K P H G W L - Q B F Y - Z V X J}
	    {E I S H - T M O - A N W G - D U V J B - R K L F - P X Z C Y Q}
	    {F K B Q T C Z H W X M D Y U P A J O E R S G N L V I}
	    {E T I M S O H - A W U J V P - C G K Q F Z - R Y L B X D N}
	    {A E I O U - T N R S D L H - B C F G J K M - P Q V W X Y Z}
	}
    }
    # The 100 Most Common Words in English, artskill.pdf p. 38
    array set data {
	100-most-common-words {
	    go am me on by to up so it no of as he if an us or in is at my we do be
	    and man him out not but can who has may was one she all you how any its say are now two for men her had the our his
	    been some then like well made when have only your work over such time were with into very what then more will they come that from must said them this upon
	    great about other shall every these first their could which would there before should little people
	}
    }
    # Chapter 21, Methods Not Recommended, p. 137
    # any printed representation of the code
    
    # Chapter 22, Word Lists for Practice, p. 141
    array set data {
	100-words-by-function {
	    {a an the this these that some all any every who which what such other}
	    {I me my w us our you your he him his she her it its they them their}
	    {man men people time work well may will can one two grea little first}
	    {at by on upon over before to from with in into out for of about up}
	    {when then now how so like as well very only no not ore there than}
	    {and or if but}
	    {be am is are was were been has have had may can could will would shall should must say said like go come do made work}
	}
	100-words-sentences {
	    it is only there.
	    you will like your work.
	    have you been out?
	    was he with her?
	    i can go now.
	    we must say that.
	    would the people com?
	    she has a great work.
	    There are more over there.
	    such men may go in.
	    these men may come first.
	    all but you have been there.
	    it was as little as that.
	    you should not have said it.
	    how has he made up your work?
	    he has been very well.
	    no man said more than that.
	    he may not do any more.
	    are they like them?
	}
	rest-of-the-500-most-common-words {
	    did low see yet act die sea run age end new
	    set ago sun eye nor son air way far off ten
	    big arm few old too ask get own try add god
	    pay use boy got put war car law red sir yes
	    why cry let sat cut lie saw mrs ill
	    
	    also case even five head less just mile once seem talk
	    wall bank fill want tell seen open mind life keep hear
	    four ever city army back cost face full held kept line
	    miss part ship thus week lady many went told show pass
	    most live kind help gave fact dear best bill does fall
	    girl here king long move poor side took were mwhom town
	    soon read much look knew high give feet done body book
	    dont felt gone hold know lost name real sort tree wide
	    wind ture step rest near love land home good till door
	    both call down find half hope last make need road stop
	    turn wish came drop fine hand hour late mark next room
	    sure wait word year walk take same note mean left idea
	    hard fire each care
	    
	    young watch thing speak right paper least heard dress
	    bring above often water think stand river party leave
	    heart early built after carry again fight horse light
	    place round start those where alone cause force house
	    marry plant serve state three white still today whole
	    short point might human found child along began color
	    given large month price small story under world whose
	    tried stood since power money labor front close among
	    begin court green laugh night quite smile table until
	    write being cover happy learn order reach sound taken
	    voice wrong
	    
	    chance across letter enough public twenty always change
	    family matter rather wonder answer coming father moment
	    reason result appear demand figure mother remain supply
	    around doctor follow myself return system became dollar
	    friend number school second office garden during become
	    better either happen person toward
	    
	    hundred against brought produce company already husband
	    receive country america morning several another evening
	    nothing suppose because herself perhaps through believe
	    himself picture whether between however present without
	    
	    national continue question consider increase american
	    interest possible anything children remember business
	    together
	    
	    important themselves washington government something
	    condition president
	}
	prefixes {
	    un ex re de dis mis con com for per sub pur pro post
	    anti para fore coun susp extr trans
	}
	suffixes {
	    ly ing ify ally tial ful ure sume sult jure logy gram
	    hood raph ment pose pute tain ture cient spect quire
	    ulate ject ther
	}
	phrases {
	    we are in the he is and the will be we will that the
	    it is do not i am to the for the of this to them
	    it was and he of a from me that was on the they were
	    she is i will in a there is he was i will that was
	}
	long {
	    somewhere newspaper wonderful exchange household
	    grandfather overlooked depending movement handsome
	    contained amounting homestead workmanship production
	    discovered preventing misplaced requested breakfast
	    department investment throughout furnishing regulation
	    forwarded friendship herewith foundation deportment
	    geography important lemonade graduation federated
	    educational handkerchief conversation arrangement nightgown
	    commercial exceptional prosperity subscription visionary
	    federation hertofore ingredients certificate pneumonia
	    interview knowledge stockholders property chaperone
	    permanently demonstrated immediately responsible chautauqua
	    candidacy supervisor independent strawberry epidemics
	    specification agricultural catalogues phosphorus schedules
	    rheumatism temperature circumstances convenience pullman
	    trigonometry bourgeoisie slenderiz camouflage broadcast
	    defamatory ramshackle bimonthly predetermined clemency
	    beleaguered voluptuous intoxicating depository pseudonym
	    indescribable hieroglyphics morphologist yugoslavia cynosure
	    parallelogram pleasurable toxicology bassoonist influenza
	}
    }
    # Chapter 23, Making Sure You're Understood, p. 145
    # repetition, redundancy, word counts
    # center audio frequency best at minimum 7 times the telegraphic cycle rate
    # which works out to 350 Hz for 60 wpm
    # Chapter 24, Bandwidths and Key Clicks, p. 149
    # keying baud = wpm/1.2, where standard word is 50 units
    # 3rd harmonic sufficient to copy under good conditions
    # 5th harmonic required to copy under poor conditions
    # 7th harmonic makes for really good copy
    # baud = wpm/1.2, multiply by 3, 5, or 7 for harmonic
    # (20wpm / 1.2 = 16-2/3) * 3 = 50 Hz, * 5 = 83-1/3 Hz, * 7 = 116-2/3 Hz,
    # and double for both sidebands in transmitted bandwidth
    # don't you need both sidebands for receiving too?  
    # Should be able to tell by testing readability with applied filters
    #
    # koch method summary
    # koch found that using different tones for dit and dah increased the students' ability to
    # learn the audible gestalt of the characters.  the two tones merged together as the class
    # progressed.  artskill.pdf p. 172
    # add new characters when 90% accuracy achieved for old characters
    # when introducing the code by letter groups, learning new groups tends to obliterate the
    # earlier groups, so practice everything.  artskill.pdf p. 174
    # introduce characters as sounds at minimum 12wpm - character - space - character - space ...
    # but move to random 5 letter groups at normal 12wpm letter spacing, but with long spaces between groups.
    # initially just mark a dot for each character, using paper with blocks of 5 laid out.
    # and then when copying, mark the letter in the block, or mark a dot, but do not allow yourself to
    # be drawn into figuring out the last letter heard.  Either hear it and copy it down, or make just a dot.
    # There will be novel characters introduced at any time, they should be marked as dots, ie recognized
    # as an unknown character grouping.
    #
}
proc n0hff-letter-orders {} { return $::morse::n0hff::data(letter-orders) }
proc n0hff-common-words {} { return $::morse::n0hff::data(100-most-common-words) }
proc n0hff-words-by-function {} { return $::morse::n0hff::data(100-words-by-function) }
proc n0hff-words-sentences {} { return [split [string trim $::morse::n0hff::data(100-words-sentences)] \n] }
proc n0hff-more-words {} { return $::morse::n0hff::data(rest-of-the-500-most-common-words) }
proc n0hff-prefixes {} { return $::morse::n0hff::data(prefixes) }
proc n0hff-suffixes {} { return $::morse::n0hff::data(suffixes) }
proc n0hff-phrases {} { return $::morse::n0hff::data(phrases) }
proc n0hff-long {} { return $::morse::n0hff::data(long) }
