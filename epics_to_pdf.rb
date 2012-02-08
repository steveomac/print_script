#!/usr/bin/env ruby

# Script to generate PDF cards suitable for planning poker
# from Pivotal Tracker [http://www.pivotaltracker.com/] CSV export.

# Inspired by Bryan Helmkamp's http://github.com/brynary/features2cards/

# Example output: http://img.skitch.com/20100522-d1kkhfu6yub7gpye97ikfuubi2.png

require 'rubygems'
require 'ostruct'
require 'term/ansicolor'
require 'prawn'
require 'prawn/layout/grid'
require 'prawn/measurements'
require 'pivotal-tracker'
require 'optparse'
require 'pp'

BASEDIR=File.dirname(__FILE__)

# This hash will hold all of the options
# parsed from the command-line by
# OptionParser.
options = {}
filters = {:state => ["unstarted", "started", "finished", "delivered", "accepted", "rejected"], :label => ["to-print"]}
DEV_STREAMS = {   
                  "editor" => "fa6c0c",
                  "ts - hotel matching" => "0a62da",
                  "ts - bau - engineering" => "000000",
                  "ts - hotels in BTTD" => "0a62da",
                  "ts - publishing tools" => "7425b1",
                  "none" => "000000"
                }
                
PivotalTracker::Client.token = 'e3509189146f70a97cc7d12d2e9ba12c'

optparse = OptionParser.new do |opts|
  # TODO: Put command-line options here
  
  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help LABEL', 'defaults to label => "to-print" overide with -t "story,types" -s "state1,state2" -i "id1,id2,id3" -l "label_1,label_2"' ) do |l|
    filters[:label] = l.split(',')
  end
  opts.on( '-l', '--label LABEL', 'Define label filter comma seperated' ) do |l|
    filters[:label] = l.split(',')
  end
  opts.on( '-t', '--story_type CARD_TYPE', 'Define story type filter comma seperated' ) do |t|
    filters[:story_type] = t.split(',')
  end
  opts.on( '-s', '--state STATE', 'Define state filter comma seperated' ) do |s|
    filters[:state] = s.split(',')
  end
  opts.on( '-i', '--ids IDS', 'Define IDs filter comma seperated' ) do |s|
    filters[:id] = s.split(',')
  end
end

optparse.parse!

puts filters.inspect

class String; 
  include Term::ANSIColor; 
#  def force_encoding(enc)
#    self
#  end
end

# test project
#projects = [456831]

# epics
projects = [465769]



# real projects
#projects = [365927,428773]

projects.each do |project|
  
  # --- Create cards objects
  @a_project = PivotalTracker::Project.find(project)

  puts @a_project.inspect

  stories = @a_project.stories.all(filters)

  # --- Generate PDF with Prawn & Prawn::Document::Grid

  filename = "/Users/cussejw6/documents/cards_to_print/PT_to_print_"+Time.now.to_s+"_"+@a_project.name+".pdf"
  
  if stories.length == 0
    puts "no stories to print" 
  else
    begin

      Prawn::Document.generate(filename,
       :page_layout => :landscape,
       :margin      => [10, 10, 10, 10],
       :page_size   => [216,360]) do |pdf|

        pdf.font "#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf"
        
        stories.each_with_index do |card, i|        
          puts "* #{card.name}"
          card_theme = {}              
          padding = 10
          width = pdf.bounds.right-padding*2
          pdf.start_new_page if i>0

          # set the card icon
          card_theme[:icon] = card.story_type+".png"
            
          
          # set the theme color
          
          dev_stream = (card.labels.split(",") & (DEV_STREAMS.keys))
                    
          card_theme[:color] = (dev_stream.nil? | dev_stream.empty?) ? DEV_STREAMS["none"] : DEV_STREAMS[dev_stream[0]]
                        
          pdf.stroke_color = card_theme[:color]
          pdf.line_width = 10
          pdf.stroke_bounds   
          # --- Write content
          pdf.stroke_color = '666666'
          pdf.fill_color "000000"
          
          pdf.bounding_box [pdf.bounds.left+padding, pdf.bounds.top-padding], :width => width do
            pdf.text_box card.name.force_encoding("utf-8"), :size => 24, :width => width, :height => 80, :overflow => :shrink_to_fit
            tasks = card.tasks.all.collect {|t| t.description}
            y_position = -100
            tasks.each do |task|
              puts "before each task #{y_position}"
              p "   - #{task}"
              pdf.text_box "* #{task}", :size => 10, :at => [10,y_position], :width => width, :height => 18, :overflow => :shrink_to_fit
              y_position -= 20
            end
            pdf.fill_color "000000"
          end
        end
      end

      puts ">>> Generated PDF file in '#{filename}' with #{stories.size} stories:".black.on_green

      puts ">>> Updating pivotal labels".black.on_green
      
#      stories.each do |card|
#        card.labels = (card.labels.split(",") - ['to-print'] + ['p']).flatten.join(",") unless card.labels.nil?
#        card.update unless card.labels.nil?
#      end

      system("open", filename)

      rescue Exception
        puts "[!] There was an error while generating the PDF file... What happened was:".white.on_red
        raise
    end
  end
end