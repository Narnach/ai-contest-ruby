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
          log_state
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

  def log_state
    my_growth       = @pw.my_planets.inject(0) {|sum, planet| sum + planet.growth_rate}
    neutral_growth  = @pw.neutral_planets.inject(0) {|sum, planet| sum + planet.growth_rate}
    enemy_growth    = @pw.enemy_planets.inject(0) {|sum, planet| sum + planet.growth_rate}

    my_population      = @pw.my_planets.inject(0) {|sum, planet| sum + planet.num_ships}
    neutral_population = @pw.neutral_planets.inject(0) {|sum, planet| sum + planet.num_ships}
    enemy_population   = @pw.enemy_planets.inject(0) {|sum, planet| sum + planet.num_ships}

    my_fleets     = @pw.my_fleets.inject(0) {|sum, fleet| sum + fleet.num_ships}
    enemy_fleets  = @pw.enemy_fleets.inject(0) {|sum, fleet| sum + fleet.num_ships}

    log "Growth: me %i / neutral %i / enemy %i" % [my_growth, neutral_growth, enemy_growth]
    log "Population: me %i / neutral %i / enemy %i" % [my_population, neutral_population, enemy_population]
    log "Fleets: me %i / enemy %i" % [my_fleets, enemy_fleets]
    log "Ships: me %i / enemy %i" % [my_fleets + my_population, enemy_fleets + enemy_population]
  end
end