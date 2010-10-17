desc 'Play two bots against each other'
task :play do
  system %q[java -jar tools/PlayGame.jar maps/map1.txt 1000 200 last_game.log "ruby MyBot.rb" "ruby MyBot.rb speed"| java -jar tools/ShowGame.jar]
  exec "mate ./last_game.log"
end

task :debug do
  system %q[java -jar tools/PlayGame.jar maps/map1.txt 1000 200 last_game.log "ruby MyBot.rb -v" "ruby MyBot.rb -v speed"| java -jar tools/ShowGame.jar]
  exec "mate ./last_game.log"
end

desc 'Create a .zip file with all ruby files'
task :zip do
  files = `find . -name '*.rb'`.split("\n").map{|str| str.strip}
  system "zip", "-9", "narnach.zip", *files
end