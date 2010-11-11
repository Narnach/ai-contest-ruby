require 'fileutils'

class Array
  def rand
    self[Kernel.rand(self.size)]
  end
end

class String
  # Used to call bot.name, pretty-printing a bot's name
  def name
    name = self.gsub("./","").gsub(".rb","")
    name = name.gsub("Mybot","") if name =~ /Mybot \w+/
    name.strip
  end
end

BOTS = Dir.glob("bots/*.rb").map{|file| File.basename(file).gsub(".rb","")}
SUBMISSION_BOTS = Dir.glob("submissions/*/MyBot.rb")
RECENT_SUBMISSION_BOTS = SUBMISSION_BOTS.sort_by {|file| file.match(/v(\d+)/)[1].to_i}[(-(ENV['RECENT']||5).to_i)..-1]
ALL_BOTS = BOTS + SUBMISSION_BOTS
MAPS = Dir.glob("maps/*.txt")
LBNS = BOTS.map{|bot| bot.size}.sort.last
LMNS = MAPS.map{|map| map.size}.sort.last
TAGS = `git tag -l`.split("\n").map{|tag| tag.strip}

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
    :analyze=>false,
  }
  attr_accessor *(DEFAULT_OPTIONS.keys)

  def initialize(options={})
    final_options = DEFAULT_OPTIONS.merge(options)
    final_options.each do |k,v|
      self.send("#{k}=",v)
    end
    self.bot1 = "./Mybot.rb #{self.bot1}" unless File.exist?(self.bot1)
    self.bot2 = "./Mybot.rb #{self.bot2}" unless File.exist?(self.bot2)
    self.map  = "maps/map#{self.map}.txt" unless File.exist?(self.map)
    # Use debug as a flag to override debug1 and debug2, unless they are explicitly set
    self.debug=true if ENV['DEBUG']=='true'
    self.debug1=true if self.debug && !options.has_key?(:debug1)
    self.debug2=true if self.debug && !options.has_key?(:debug2)
    self.raw_output=true if self.analyze
    self.visualize = false if self.raw_output
    self.open_log=false if self.analyze
  end

  def cmd
    bot1_cmd = "ruby #{bot1} #{"-v" if debug1}"
    bot2_cmd = "ruby #{bot2} #{"-v" if debug2}"
    %Q[java -jar tools/PlayGame.jar #{map} #{timeout} #{turns} #{logfile} "#{bot1_cmd}" "#{bot2_cmd}"#{"| java -jar tools/ShowGame.jar" if visualize}#{" 2>&1" if self.raw_output}]
  end

  def run
    puts cmd if verbose
    if self.raw_output
      raw = `#{cmd}`
      if self.analyze
        result = raw
        win_line = result.split("\n").grep(/Draw|Player \d Wins/).first
        match_turns = result.split("\n").grep(/Turn \d+/).last.match(/\d+/)[0].to_i
        match = {:p1=>bot1, :p2=>bot2, :map=>map, :turns => match_turns}
        unless win_line
          puts "This response is unexpected: #{result.inspect}"
          exit 1
        end
        case win_line.strip
        when "Draw!"
          match[:winner]=nil
          match[:loser]=nil
        when "Player 1 Wins!"
          match[:winner]=bot1
          match[:loser]=bot2
        when "Player 2 Wins!"
          match[:winner]=bot2
          match[:loser]=bot1
        else
          puts "This response is unexpected: #{result.inspect}"
          exit 1
        end
        return match
      else
        return raw
      end
    else
      system(cmd)
      puts "A matchup of '#{bot1}' vs '#{bot2}' on #{map}" if verbose
      exec "mate #{logfile}" if open_log
    end
  end
end

class Tournament
  DEFAULT_OPTIONS = {
    :debug=>false,
    :verbose=>false,
  }
  # External data
  attr_reader :bots, :turns, :maps, :options
  # Internal data
  attr_reader :matches, :lbns, :lmns

  def initialize(bots, maps, turns, options={})
    options[:random_maps] = true unless options.has_key?(:random_maps)
    @bots = bots
    @maps = maps
    @maps = @maps.shuffle if options.delete(:random_maps)
    @turns = turns
    @matches = []
    @lbns = bots.map{|bot| bot.name.length}.max
    @lmns = maps.map{|map| map.length}.max
    @options=options
  end

  def play
    # Use bots_pool to pick the first bot. Each time a bot plays, he is kicked down the ladder. This means that the bot who has played the least drifts upwards
    bots_pool = bots.shuffle
    turns.times { |n|
      turn = n+1
      if options[:bot1]
        bot1 = options[:bot1]
        bots_pool.delete(bot1)
      else
        bot1 = bots_pool.shift
      end
      if options[:bot2]
        bot2 = options[:bot2]
      else
        bot2 = bots_pool.rand
      end
      bots_pool.delete(bot2)
      bots_pool.push bot1
      bots_pool.push bot2
      if options[:map]
        map = options[:map]
      else
        map = maps.shift
        maps.push(map)
      end

      game = Playgame.new(DEFAULT_OPTIONS.merge(options).merge(:map=>map, :bot1=>bot1, :bot2=>bot2, :analyze=>true, :raw_output=>true, :logfile=>"tournament_game_#{turn}.log"))
      match = game.run

      matches << match
      if match[:winner]
        win_pct = match_stats(matches).find{|match_stat| match_stat[0] == match[:winner].name}[5]
        puts "Game %#{turns.to_s.size}i: Victory by %#{lbns}s against %#{lbns}s on %#{lmns}s (turn %3i), wins %3i%%" % [turn, match[:winner].name, match[:loser].name, map, match[:turns], win_pct]
      else
        puts "Game %#{turns.to_s.size}i: A draw for %#{lbns}s against %#{lbns}s on %#{lmns}s" % [turn, bot1.name, bot2.name, map]
      end
    }
  end

  def display_stats
    tournament_stats(@matches)
  end

  protected
  
  def match_stats(matches)
    bots = matches.map {|match| [match[:winner], match[:loser]]}.flatten.compact.uniq.sort
    bots.map do |bot|
      bot_matches = matches.select{|match| match[:p1] == bot or match[:p2] == bot}
      plays = bot_matches.size
      wins = bot_matches.select{|match| match[:winner] == bot}.size
      draws = bot_matches.select{|match| match[:winner] == nil}.size
      losses = bot_matches.select{|match| match[:loser] == bot}.size
      win_pct = plays > 0 ? 100.0 * wins / plays : 0
      next [bot.name, wins, draws, losses, plays, win_pct]
    end
  end

  def tournament_stats(matches)
    match_stats(matches).sort_by {|bot_match| 100-bot_match.last}.each do |stats|
      puts "%#{lbns}s: %#{turns.to_s.size}i/%#{turns.to_s.size}i/%#{turns.to_s.size}i (%#{turns.to_s.size}i games, %3i%% wins)" % stats
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
  bots = RECENT_SUBMISSION_BOTS
  if bots.size == 0
    puts "No bots found. Please run 'rake submissions'. This will reset your git branch a couple of times, so commit your changes first."
    exit 1
  end
  maps = MAPS
  turns = (ENV['TURNS'] || bots.size * 10).to_i
  options={:bot1=>"./MyBot.rb"}
  options[:bot1]=ENV['BOT1'] if ENV['BOT1']
  options[:verbose]=true if ENV['VERBOSE']
  options[:debug]=true if ENV['DEBUG']

  tournament = Tournament.new(bots, maps, turns, options)
  tournament.play
  tournament.display_stats
end

desc "Run with debug flags on. Use env variables MAP, BOT1 and BOT2 to change defaults. Set random to pick a random valid value"
task :debug do
  game = Playgame.new(:map=>ENV['MAP']||MAPS.rand, :bot1=>ENV['BOT1']||ALL_BOTS.rand, :bot2=>ENV['BOT2']||ALL_BOTS.rand, :visualize=>ENV['RAW'].nil?, :debug=>true, :verbose=>true)
  game.run
end

desc 'Create a .zip file with all ruby files'
task :zip do
  files = `find {lib,bots} -name '*.rb'`.split("\n").map{|str| str.strip}
  system "zip", "-9", "narnach.zip", 'MyBot.rb', *files
end

desc "Tag this git commit with the latest tag"
task :tag do
  previous_tag = `git tag -l`.split("\n").map{|tag| tag.strip}.map{|str| str.gsub(/\D+/,"").to_i}.sort.last
  new_tag = "v#{previous_tag + 1}"
  puts new_tag
  system "git tag -a #{new_tag} -m #{new_tag}"
end

desc "Release!"
task :release => [:prezip_tournament] do
  puts "The tournament has played. Are you happy with the results and are you ready to ship?\nPress ENTER to continue or Ctrl-C to stop."
  $stdin.gets
  Rake::Task['zip'].invoke
  Rake::Task['tag'].invoke
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
  debug = ENV['DEBUG'] ? " -v " : ""
  system "./tcp 72.44.46.68 995 #{player} -p #{password} ./MyBot.rb #{bot} #{debug} --stderr"
  system %Q[open "http://72.44.46.68/getplayer?player=#{player}"]
end

desc "Run a tournament of random matchups. Set TURNS to change the turn count it from the number of maps."
task :tournament do
  bots = BOTS
  maps = MAPS
  turns = (ENV['TURNS'] || bots.size * 5).to_i
  options = {}
  options[:bot1]=ENV["BOT1"] if ENV["BOT1"]
  options[:bot2]=ENV["BOT2"] if ENV["BOT2"]
  options[:map]=ENV["MAP"] if ENV["MAP"]
  options[:random_maps]=false if ENV["RANDOM_MAPS"]=="false"

  tournament = Tournament.new(bots, maps, turns, options)
  tournament.play
  tournament.display_stats
end

TAGS.each do |tag|
  dir = "submissions/#{tag}"
  file "#{dir}/MyBot.rb" do
    FileUtils.mkdir_p(dir)
    system "git checkout #{tag} && rake zip && unzip narnach.zip -x 'submissions/*' -d #{dir}/ && rm narnach.zip"
  end
end

desc 'Prepare submissions directory'
task :submissions => TAGS.map{|tag| "submissions/#{tag}/MyBot.rb"} do
  system "git checkout master"
  Rake::Task['fix_submissions'].invoke
end

desc 'Submissions load their own files instead of the current files'
task :fix_submissions do
  Dir.glob("submissions/**/*.rb").each do |file|
    next unless File.file?(file)
    old_code = File.read(file)
    new_code = old_code.split("\n").map { |line|
      if line =~ /require ((["''])(\.\/.+?)\2)/
        puts "Substituting #{$1}"
        old_require = $1
        new_require = $3.sub(/^.\//, '#{File.expand_path(File.dirname(__FILE__))}/')
        next line.sub(old_require, %Q["#{new_require}"])
      end
      if line =~ /Dir\.glob\(((["''])(\.\/.+?)\2)\)/
        puts "Substituting #{$1}"
        old_require = $1
        new_require = $3.sub(/^.\//, '#{File.expand_path(File.dirname(__FILE__))}/')
        next line.sub(old_require, %Q["#{new_require}"])
      end
      line
    }.join("\n")
    File.open(file, "w") {|f| f.write(new_code)}
  end
end