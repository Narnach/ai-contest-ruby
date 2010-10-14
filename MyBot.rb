# Bot launcher
# Syntax:
#   MyBot.rb <ai_name>
require './planetwars.rb'
Dir.glob("bots/*.rb").each do |file|
  require file
end

ai_class = AI.find(ARGV.first || "naieve")
bot = ai_class.new
bot.run
