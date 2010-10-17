# Bot launcher
# Syntax:
#   MyBot.rb <ai_name>
require './lib/planetwars.rb'
require './lib/ai.rb'
Dir.glob("./bots/*.rb").each do |file|
  require file
end

VERBOSE = ARGV.delete('-v')=='-v'

ai_class = AI.find(ARGV.shift || "speed")
bot = ai_class.new
bot.logging = VERBOSE
bot.run
