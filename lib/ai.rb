class AI
  attr_accessor :logging, :log_stream

  def initialize
    @turn_start=Time.now
    @log_stream = $stdout
  end

  def self.version(version=nil)
    @version ||= 1
    @version = version unless version.nil?
    @version
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

  # Don't forget to start a bot's do_turn with a call to super
  def do_turn
    return if @pw.my_planets.length == 0
    return if @pw.enemy_planets.length == 0
    return if @pw.not_my_planets.length == 0
  end

  def run
    map_data = ''
    @turn = 0
    loop do
      current_line = gets.strip rescue break
      if current_line.length >= 2 and current_line[0..1] == "go"
        @turn += 1
        @turn_start = Time.now
        @pw = PlanetWars.new(map_data)
        begin
          log_state
          do_turn
        rescue => e
          log "#{e.class.name}: #{e.message}"
          e.backtrace[0...5].each do |line|
            log line
          end
        end
        log "Finishing turn"
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
    @log_stream.puts "# (left: %8.06f) %s" % [time_left, msg] if self.logging
  end

  def log_state
    @my_growth       = @pw.my_planets.inject(0) {|sum, planet| sum + planet.growth_rate}
    @neutral_growth  = @pw.neutral_planets.inject(0) {|sum, planet| sum + planet.growth_rate}
    @enemy_growth    = @pw.enemy_planets.inject(0) {|sum, planet| sum + planet.growth_rate}

    @my_population      = @pw.my_planets.inject(0) {|sum, planet| sum + planet.num_ships}
    @neutral_population = @pw.neutral_planets.inject(0) {|sum, planet| sum + planet.num_ships}
    @enemy_population   = @pw.enemy_planets.inject(0) {|sum, planet| sum + planet.num_ships}

    @my_fleets     = @pw.my_fleets.inject(0) {|sum, fleet| sum + fleet.num_ships}
    @enemy_fleets  = @pw.enemy_fleets.inject(0) {|sum, fleet| sum + fleet.num_ships}

    @my_ships     = @my_population + @my_fleets
    @enemy_ships  = @enemy_population + @enemy_fleets

    @my_fleet_pct = @my_ships == 0 ? 0.0 : 100.0 * @my_fleets / @my_ships
    @enemy_fleet_pct = @enemy_ships == 0 ? 0.0 : 100.0 * @enemy_fleets / @enemy_ships

    log "===== #{self.class.name} v#{self.class.version}, turn #{@turn}"
    log "Me:      T:%4i P:%4i F:%4i (%4.1f%%) G:%3i" % [@my_ships, @my_population, @my_fleets, @my_fleet_pct, @my_growth]
    log "Them:    T:%4i P:%4i F:%4i (%4.1f%%) G:%3i" % [@enemy_ships, @enemy_population, @enemy_fleets, @enemy_fleet_pct, @enemy_growth]
    log "Neutral: P:%4i G:%3i" % [@neutral_population, @neutral_growth]
  end
end