# Grower tries to conquer the biggest, least-defended enemy/neutral planet with the lowest amount of ships it can.
# It accounts for the growth rate of enemy planets and travel distance.
# It also lets multiple planets cooperate to send enough ships to take over the target planet.
class Grower < AI
  MAX_SHIPS_PCT = 0.9
  attr_reader :target
  bot 'grower'

  def do_turn
    return if @pw.my_fleets.length >= 10
    return if @pw.my_planets.length == 0
    return if @pw.not_my_planets.length == 0
    
    # Clear target if we own it
    if @target
      @target = @pw.planets[@target.planet_id]
      clear_target if @target.mine?
    end

    @pw.my_planets.each do |planet|
      find_target_for(planet) unless @target
      next unless @target

      if time_left < 0.1
        log 'almost out of time'
        return
      end
      if @target.neutral?
        num_ships = [@target.num_ships + 1, (planet.num_ships * MAX_SHIPS_PCT).to_i].min
      else
        num_ships = [@target.num_ships + 1 + (@pw.distance(planet, @target) * @target.growth_rate).to_i, (planet.num_ships * MAX_SHIPS_PCT).to_i].min
      end
      next if num_ships == 0
      @pw.issue_order(planet.planet_id, @target.planet_id, num_ships)

      # Pick a new target if it's most likely we will conquer this planet with the ships in transit
      @ships_for_target += num_ships
      if @target.neutral?
        clear_target if @ships_for_target > @target.num_ships
      else # enemy
        clear_target if @ships_for_target > (@target.num_ships + (@target.growth_rate * @pw.distance(planet, @target)))
      end
    end
  end
  
  def find_target_for(planet)
    log 'finding target'
    # highest growth, lowest ships
    max_ships = (planet.num_ships * MAX_SHIPS_PCT).to_i
    @target = @pw.not_my_planets.select{|p|
      next p.num_ships <= max_ships if p.neutral?
      next (p.num_ships + (@pw.distance(planet, p) * p.growth_rate)) <= max_ships
    }.sort { |a,b|
      next 1 if a.growth_rate > b.growth_rate
      next -1 if a.growth_rate < b.growth_rate
      next a.num_ships <=> b.num_ships
    }.last
    @ships_for_target = 0
    return unless @target
    log "found target: planet #{@target.planet_id} with #{@target.num_ships} ships and growth #{@target.growth_rate}"
  end
  
  def clear_target
    @target = nil
    @ships_for_target = 0
  end
end