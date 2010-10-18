class Array
  def rand
    self[Kernel.rand(self.size)]
  end
end

@bots = Dir.glob("bots/*.rb").map{|file| File.basename(file).gsub(".rb","")}
@maps = Dir.glob("maps/*.txt")
@lbns = @bots.map{|bot| bot.size}.sort.last
@lmns = @maps.map{|map| map.size}.sort.last

desc 'Play two bots against each other'
task :play do
  system %q[java -jar tools/PlayGame.jar maps/map1.txt 1000 200 last_game.log "ruby MyBot.rb" "ruby MyBot.rb speed"| java -jar tools/ShowGame.jar]
  exec "mate ./last_game.log"
end

desc "Run with debug flags on. Use env variables MAP, BOT1 and BOT2 to change defaults. Set random to pick a random valid value"
task :debug do
  ENV['MAP'] = @maps.rand if ENV['MAP']=='random'
  map = ENV['MAP'] || 'maps/map1.txt'

  ENV['BOT1'] = @bots.rand if ENV['BOT1']=="random"
  bot = ENV['BOT1'] || 'seer'

  ENV['BOT2'] = @bots.rand if ENV['BOT2']=="random"
  bot2 = ENV['BOT2'] || 'toolbot'

  if ENV["RAW"].nil?
    output = "| java -jar tools/ShowGame.jar"
  else
    output = ""
  end

  puts "A matchup of #{bot} vs #{bot2} on #{map}"
  system %Q[java -jar tools/PlayGame.jar #{map} 3000 200 last_game.log "ruby MyBot.rb -v #{bot}" "ruby MyBot.rb -v #{bot2}"#{output}]
  puts "A matchup of #{bot} vs #{bot2} on #{map}"
  exec "mate ./last_game.log"
end

desc 'Create a .zip file with all ruby files'
task :zip do
  files = `find . -name '*.rb'`.split("\n").map{|str| str.strip}
  system "zip", "-9", "narnach.zip", *files
end

desc "Run the current default bot against the TCP server. Requires ./tcp to be compiled"
task :tcp do
  bot = ENV['BOT'] || ''
  unless File.exist?("bots/#{bot}.rb")
    puts "Bot #{bot} does not exist"
    exit 1
  end
  system "./tcp 72.44.46.68 995 narnach -p nartest123 ./MyBot.rb #{bot}"
end

desc "Run a tournament of random matchups. Set TURNS to change the turn count it from the number of maps."
task :tournament do
  turns = (ENV['TURNS'] || @maps.size).to_i

  matches = []

  # Use bots_pool to pick the first bot. Each time a bot plays, he is kicked down the ladder. This means that the bot who has played the least drifts upwards
  bots_pool = @bots.shuffle
  turns.times {
    bot1 = bots_pool.shift
    bot2 = bots_pool.rand
    bots_pool.delete("bot2")
    bots_pool.push bot1
    bots_pool.push bot2
    map = @maps.rand

    print "A matchup of %#{@lbns}s vs %#{@lbns}s on %#{@lmns}s: " % [bot1, bot2, map]
    cmd = %Q[java -jar tools/PlayGame.jar #{map} 1000 200 last_game.log "ruby MyBot.rb #{bot1}" "ruby MyBot.rb #{bot2}" 2>&1]
    result = `#{cmd}`
    win_line = result.split("\n").grep(/Draw|Player \d Wins/).first
    match_turns = result.split("\n").grep(/Turn \d+/).last.match(/\d+/)[0].to_i
    match = {:p1=>bot1, :p2=>bot2, :map=>map, :match_turns => match_turns}
    unless win_line
      puts "This response is unexpected: #{result.inspect}"
      exit 1
    end
    case win_line.strip
    when "Draw!"
      match[:winner]=nil
      match[:loser]=nil
      puts "Draw"
    when "Player 1 Wins!"
      match[:winner]=bot1
      match[:loser]=bot2
      puts "Victory by #{bot1}"
    when "Player 2 Wins!"
      match[:winner]=bot2
      match[:loser]=bot1
      puts "Victory by #{bot2}"
    else
      puts "This response is unexpected: #{result.inspect}"
      exit 1
    end
    matches << match
  }

  # p matches
  @bots.each do |bot|
    bot_matches = matches.select{|match| match[:p1] == bot or match[:p2] == bot}
    plays = bot_matches.size
    wins = bot_matches.select{|match| match[:winner] == bot}.size
    draws = bot_matches.select{|match| match[:winner] == nil}.size
    losses = bot_matches.select{|match| match[:loser] == bot}.size
    puts "%10s: %i/%i/%i (%i games)" % [bot, wins, draws, losses, plays]
  end
end
