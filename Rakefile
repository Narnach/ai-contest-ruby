desc 'Play two bots against each other'
task :play do
  system %q[java -jar tools/PlayGame.jar maps/map1.txt 1000 500 last_game.log "ruby MyBot.rb" "ruby MyBot.rb grower"| java -jar tools/ShowGame.jar]
end

desc 'Create a .zip file with all ruby files'
task :zip do
  files = `find . -name '*.rb'`.split("\n").map{|str| str.strip}
  system "zip", "-9", "narnach.zip", *files
end