#!/usr/bin/env ruby
# Bot launcher
# Syntax:
#   MyBot.rb <ai_name>
require './lib/core_ext.rb'
require './lib/planetwars.rb'
require './lib/ai.rb'

VERBOSE = ARGV.delete('-v')=='-v'

bot = ARGV.shift || "toolbot"
Dir.glob("./bots/*.rb").each do |file|
  require file
end

ai_class = AI.find(bot)
bot = ai_class.new
bot.logging = VERBOSE
bot.run
