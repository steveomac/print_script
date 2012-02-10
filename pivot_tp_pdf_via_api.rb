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
                  # Capex shop stream
                  "ts-shop-digi-bundling-ox" => "fa6c0c",

                  # Capex Statler stream
                  "ts-bttd-cx" => "0a62da",
                  "ts-hotels in BTTD" => "0a62da",
                  "ts-hotel matching" => "0a62da",
                  "ts-hotels-cx" => "0a62da",

                  # Capex Themes/publishing tools stream
                  "ts-themes-cx" => "7425b1",                # not in SAP yet
                  "ts-publishing-tools-cx" => "7425b1",      # not in SAP yet

                  # Opex BAU stream
                  "ts-bau-development" => "00c000",
                  "ts-bau-design" => "00c000",
                  "ts-hotels-ox" => "00c000",
                  "ts-shop-ox" => "00c000",
                  "ts-advertising-ox" => "00c000",
                  "ts-marketing-ox" => "00c000",
                  "ts-editorial-ox" => "00c000",
                  "ts-poi-place-tagging-ox" => "00c000",      # not in SAP yet

                  # Opex engineering stream
                  "ts-bau-engineering" => "000000",           # legacy
                  "ts-janrain" => "000000",                   # legacy
                  "ts-engineering-ox" => "000000",            # not in SAP yet

                  # Non-project time categories
                  "ts-meetings-hr-admin" => "cccccc",        
     
                  # Grey for everything else
                  "none" => "cccccc"
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

# force encoding is required to run this in ruby 1.8 but not in 1.9. 
class String; 
  include Term::ANSIColor; 
  def force_encoding(enc)
    self
  end
end

# test project
#projects = [456831]

# epics
#projects = [465769]

# real projects
projects = [365927,428773]

projects.each do |project|
  
  # --- Create cards objects
  @a_project = PivotalTracker::Project.find(project)

  puts @a_project.inspect

  stories = @a_project.stories.all(filters)

  # --- Generate PDF with Prawn & Prawn::Document::Grid

  filename = "/Users/mcinnsw6/development/print_script/cards_to_print/PT_to_print_"+Time.now.to_s+"_"+@a_project.name+".pdf"
  
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
          card_theme = {}              
          padding = 10
          width = pdf.bounds.right-padding*2
          pdf.start_new_page if i>0

          # set the card icon
          card_theme[:icon] = card.story_type+".png"
            
          # If it is a design job card, then it is a different colour
          if card.labels.split(",").include? "design"   
              card_theme[:icon] = 'design.png'
          end
  
          # If it is a retro action card, then it is a different colour
          if card.labels.split(",").include? "retro"              
            card_theme[:icon] = 'idea.png'
          end
          
          # set the theme color    
          dev_stream = (card.labels.split(",") & (DEV_STREAMS.keys))
          
          puts dev_stream[0];
          puts dev_stream[1];
          
          card_theme[:color] = (dev_stream.nil? | dev_stream.empty?) ? DEV_STREAMS["none"] : DEV_STREAMS[dev_stream[0]]
                        
          pdf.stroke_color = card_theme[:color]
          pdf.line_width = 10
          pdf.stroke_bounds   
          # --- Write content
          pdf.stroke_color = '666666'
          pdf.fill_color "000000"
                
          pdf.bounding_box [pdf.bounds.left+padding, pdf.bounds.top-padding], :width => width do
            pdf.text_box card.name.force_encoding("utf-8"), :size => 24, :width => width, :height => 100, :at => [0,0], :overflow => :shrink_to_fit
            pdf.text_box "#"+card.id.to_s.force_encoding("utf-8"), :size => 16, :width => width-15, :height => 20, :at => [0,-100]
            pdf.fill_color "000000"
          end

          labels = (card.labels.nil? ? "" : (card.labels.split(",") - ['to-print']- ['ux']- ['ui']- ['design'] - ['retro']).join(" | ")).force_encoding("utf-8")

          pdf.text_box labels, :size => 14, :at => [10, 20], :width => width-15-60, :height => 20, :overflow => :shrink_to_fit unless labels.nil?

          # --- add a ui checkbox for cards tagged with 'ux'
          if card.labels.split(",").include? "ux"
            pdf.fill_color "666666"
            pdf.text_box "ux", :size => 12, :align => :left, :at => [130, 85], :width => width-80, :height => 15, :overflow => :shrink_to_fit
            pdf.fill_color = '663366'
            pdf.stroke do
              pdf.fill_circle [120, 80], 8
            end
          end 

          # --- add a ui checkbox for cards tagged with 'design'
          if card.labels.split(",").include? "design"
            pdf.fill_color = '666666'
            pdf.text_box "design", :size => 12, :align => :left, :at => [130, 65], :width => width-80, :height => 15, :overflow => :shrink_to_fit
            pdf.fill_color = 'FFCC00'
            pdf.stroke do
              pdf.fill_circle [120, 60], 8
            end
          end

          # --- add a design checkbox for cards tagged with 'ui'
          if card.labels.split(",").include? "ui"
              pdf.fill_color "666666"              
              pdf.text_box "ui", :size => 12, :align => :left, :at => [130, 45], :width => width-80, :height => 15, :overflow => :shrink_to_fit
              pdf.fill_color = '0099CC'
              pdf.stroke do
                pdf.fill_circle [120, 40], 8
              end
          end

          # only regular cards get the points
          if card.story_type == "feature"
            pdf.text_box card.estimate.to_s+" points",
              :size => 16, :at => [10, 60], :width => width-15, :overflow => :shrink_to_fit unless card.estimate == -1
          end

          pdf.fill_color = card_theme[:color]
          pdf.stroke_color = card_theme[:color]                    
          
          pdf.image "#{BASEDIR}/"+card_theme[:icon], :at => [270, 70], :width => 60
          
        puts "* #{card.name}"
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