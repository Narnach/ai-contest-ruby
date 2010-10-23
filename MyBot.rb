#!/usr/bin/env ruby
# Bot launcher
# Syntax:
#   MyBot.rb <ai_name>
require './lib/core_ext.rb'
require './lib/planetwars.rb'
require './lib/ai.rb'                      
require './lib/toolbox.rb'
require './lib/ships_available.rb'

VERBOSE = ARGV.delete('-v')=='-v'
STDERR = ARGV.delete('--stderr')=="--stderr"

bot = ARGV.shift || "sniperbot"
Dir.glob("./bots/*.rb").each do |file|
  require file
end

ai_class = AI.find(bot)
bot = ai_class.new
bot.logging = VERBOSE
bot.log_stream = $stderr if STDERR
bot.run
