class Array
  def rand
    self[Kernel.rand(self.size)]
  end
end

BOTS = Dir.glob("bots/*.rb").map{|file| "./Mybot.rb #{File.basename(file).gsub(".rb","")}"}
SUBMISSION_BOTS = Dir.glob("submissions/*/MyBot.rb")
ALL_BOTS = BOTS + SUBMISSION_BOTS
MAPS = Dir.glob("maps/*.txt")
LBNS = BOTS.map{|bot| bot.size}.sort.last
LMNS = MAPS.map{|map| map.size}.sort.last

class Playgame
  DEFAULT_OPTIONS = {
    :timeout=>1000,
    :turns=>200,
    :map=>MAPS.first,
    :bot1=>ALL_BOTS.first,
    :bot2=>ALL_BOTS.last,
    :debug=>false,
    :debug1=>false,
    :debug2=>false,
    :visualize=>true,
    :verbose=>true,
    :logfile=>"last_game.log",
    :open_log=>true,
    :raw_output=>false,
  }
  attr_accessor *(DEFAULT_OPTIONS.keys)

  def initialize(options={})
    final_options = DEFAULT_OPTIONS.merge(options)
    final_options.each do |k,v|
      self.send("#{k}=",v)
    end
    # Use debug as a flag to override debug1 and debug2, unless they are explicitly set
    self.debug1=true if self.debug && !options.has_key?(:debug1)
    self.debug2=true if self.debug && !options.has_key?(:debug2)
    self.visualize = false if self.raw_output
    self.open_log=false if self.raw_output
  end

  def cmd
    %Q[java -jar tools/PlayGame.jar #{map} #{timeout} #{turns} #{logfile} "#{bot1} #{"-v" if debug1}" "#{bot2} #{"-v" if debug2}"#{"| java -jar tools/ShowGame.jar" if visualize}]
  end

  def run
    puts cmd if verbose
    if self.raw_output
      `#{cmd}`
    else
      system(cmd)
      puts "A matchup of '#{bot1}' vs '#{bot2}' on #{map}" if verbose
      exec "mate #{logfile}" if open_log
    end
  end
end

desc 'Play two bots against each other'
task :play do
  game = Playgame.new(:map=>MAPS.rand, :bot1=>"./MyBot.rb", :bot2=>SUBMISSION_BOTS.rand||ALL_BOTS.rand)
  game.run
end

desc 'Play current bot against old bots'
task :prezip_tournament do
  bots = SUBMISSION_BOTS + ["./MyBot.rb"]
  lbns = bots.map{|bot| bot.length}.max
  turns = (ENV['TURNS'] || bots.size * 5).to_i

  matches = []

  # Use bots_pool to pick the first bot. Each time a bot plays, he is kicked down the ladder. This means that the bot who has played the least drifts upwards
  bots_pool = bots.shuffle
  turns.times {
    bot1 = bots_pool.shift
    bot2 = bots_pool.rand
    bots_pool.delete(bot2)
    bots_pool.push bot1
    bots_pool.push bot2
    map = MAPS.rand

    game = Playgame.new(:map=>MAPS.rand, :bot1=>bot1, :bot2=>bot2, :debug=>false, :raw_output=>true, :verbose=>false)
    game.run
    result = game.raw_output

    print "A matchup of %#{lbns}s vs %#{lbns}s on %#{LMNS}s: " % [bot1, bot2, map]
    cmd = %Q[java -jar tools/PlayGame.jar #{map} 1000 200 last_game.log "ruby #{bot1}" "ruby #{bot2}" 2>&1]
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
      puts "Victory by %#{lbns}s (turn %3i)" % [bot1, match_turns]
    when "Player 2 Wins!"
      match[:winner]=bot2
      match[:loser]=bot1
      puts "Victory by %#{lbns}s (turn %3i)" % [bot2, match_turns]
    else
      puts "This response is unexpected: #{result.inspect}"
      exit 1
    end
    matches << match
  }

  # p matches
  bots.each do |bot|
    bot_matches = matches.select{|match| match[:p1] == bot or match[:p2] == bot}
    plays = bot_matches.size
    wins = bot_matches.select{|match| match[:winner] == bot}.size
    draws = bot_matches.select{|match| match[:winner] == nil}.size
    losses = bot_matches.select{|match| match[:loser] == bot}.size
    win_pct = plays > 0 ? 100.0 * wins / plays : 0
    puts "%10s: %#{turns.to_s.size}i/%#{turns.to_s.size}i/%#{turns.to_s.size}i (%#{turns.to_s.size}i games, %3i%% wins)" % [bot, wins, draws, losses, plays, win_pct]
  end
end

desc "Run with debug flags on. Use env variables MAP, BOT1 and BOT2 to change defaults. Set random to pick a random valid value"
task :debug do
  game = Playgame.new(:map=>ENV['MAP']||MAPS.rand, :bot1=>ENV['BOT1']||ALL_BOTS.rand, :bot2=>ENV['BOT2']||ALL_BOTS.rand, :visualize=>ENV['RAW'].nil?, :debug=>true)
  game.run
end

desc 'Create a .zip file with all ruby files'
task :zip do
  files = `find {lib,bots} -name '*.rb'`.split("\n").map{|str| str.strip}
  system "zip", "-9", "narnach.zip", 'MyBot.rb', *files
end

desc "Run the current default bot against the TCP server. Requires ./tcp to be compiled"
task :tcp do
  player = 'narnach'
  password = 'nartest123'
  system "gcc tcp.c -o tcp"
  bot = ENV['BOT'] || ''
  if bot != '' && !File.exist?("bots/#{bot}.rb")
    puts "Bot #{bot} does not exist"
    exit 1
  end
  system "./tcp 72.44.46.68 995 #{player} -p #{password} ./MyBot.rb #{bot}"
  system %Q[open "http://72.44.46.68/getplayer?player=#{player}"]
end

desc "Run a tournament of random matchups. Set TURNS to change the turn count it from the number of maps."
task :tournament do
  turns = (ENV['TURNS'] || MAPS.size).to_i

  matches = []

  # Use bots_pool to pick the first bot. Each time a bot plays, he is kicked down the ladder. This means that the bot who has played the least drifts upwards
  bots_pool = BOTS.shuffle
  turns.times {
    bot1 = bots_pool.shift
    bot2 = bots_pool.rand
    bots_pool.delete(bot2)
    bots_pool.push bot1
    bots_pool.push bot2
    map = MAPS.rand

    print "A matchup of %#{LBNS}s vs %#{LBNS}s on %#{LMNS}s: " % [bot1, bot2, map]
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
      puts "Victory by %#{LBNS}s (turn %3i)" % [bot1, match_turns]
    when "Player 2 Wins!"
      match[:winner]=bot2
      match[:loser]=bot1
      puts "Victory by %#{LBNS}s (turn %3i)" % [bot2, match_turns]
    else
      puts "This response is unexpected: #{result.inspect}"
      exit 1
    end
    matches << match
  }

  # p matches
  BOTS.each do |bot|
    bot_matches = matches.select{|match| match[:p1] == bot or match[:p2] == bot}
    plays = bot_matches.size
    wins = bot_matches.select{|match| match[:winner] == bot}.size
    draws = bot_matches.select{|match| match[:winner] == nil}.size
    losses = bot_matches.select{|match| match[:loser] == bot}.size
    win_pct = plays > 0 ? 100.0 * wins / plays : 0
    puts "%10s: %#{turns.to_s.size}i/%#{turns.to_s.size}i/%#{turns.to_s.size}i (%#{turns.to_s.size}i games, %3i%% wins)" % [bot, wins, draws, losses, plays, win_pct]
  end
end
