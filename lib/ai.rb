class AI
  def initialize
    @turn_start=Time.now
  end

  def self.find(name)
    bots[name]
  end
  
  def self.bot(name, klass=self)
    return AI.bot(name, klass) unless self==AI
    bots[name]=klass
  end
  
  def self.bots
    @bots ||= Hash.new
  end
  
  def do_turn(pw)
    # todo for actual AIs
  end
  
  def run
    map_data = ''
    loop do
      current_line = gets.strip rescue break
      if current_line.length >= 2 and current_line[0..1] == "go"
        @turn_start = Time.now
        @pw = PlanetWars.new(map_data)
        begin
          do_turn
        rescue => e
          log "#{e.class.name}: #{e.message}"
          log e.backtrace.first
        end
        @pw.finish_turn
        map_data = ''
      else
        map_data += current_line + "\n"
      end
    end
  end
  
  def time_left
    (@turn_start + 1) - Time.now
  end
  
  def log(msg)
    puts "# (left: #{time_left}) #{msg}"
  end
end