module ShipsAvailable
  RESERVE_FACTOR = 5

  def do_turn
    super
    self.reset_ships_available
    self.reset_fleets_dispatched
    self.reset_defenders
  end

  def reset_ships_available
    @ships_available = Hash.new { |hash, key| hash[key] = 0 }
    @pw.my_planets.each {|planet| @ships_available[planet.planet_id] = planet.num_ships }
  end

  def reset_fleets_dispatched
    @fleets_dispatched = Hash.new { |hash, key| hash[key] = Array.new }
  end

  def reset_defenders
    @defenders = Hash.new { |hash, key| hash[key] = 0 }
  end
  
  def clear_defenders
    @defenders.each do |planet_id, defenders|
      @ships_available[planet_id] += defenders
    end
    @defenders.clear
  end

  def can_attack?(source, num_ships)
    @ships_available[source.planet_id] >= num_ships
  end

  def ships_available_on(source)
    @ships_available[source.planet_id]
  end

  def dispatch_fleet(source, target, num_ships)
    distance = @pw.travel_time(source, target)
    @fleets_dispatched[target.planet_id] << Fleet.new(source.owner, num_ships, source.planet_id, target.planet_id, distance, distance)
  end

  def assign_defenders(planet, num_ships)
    if ships_available_on(planet) >= num_ships
      @defenders[planet.planet_id] = num_ships
      @ships_available[planet.planet_id] -= num_ships
    else
      log "!!! Tried to assign more defenders than there are ships on planet #{planet.planet_id}. Want #{num_ships}, have #{ships_available_on(planet)}"
    end
  end

  def ships_for_defense_of(planet)
    @defenders[planet.planet_id] + ships_available_on(planet)
  end

  def attack_with(source, target, num_ships)
    if self.can_attack?(source, num_ships)
      log "#{source.owner == target.owner ? "Reinforcing" : "Attacking"} planet #{target.planet_id} with #{num_ships} ships from planet #{source.planet_id}. Distance is #{@pw.travel_time(source, target)}, defending ships are #{target.num_ships}."
      @ships_available[source.planet_id] -= num_ships
      @pw.issue_order(source.planet_id, target.planet_id, num_ships)
      dispatch_fleet(source, target, num_ships)
    else
      log "!!! BUG !!! Wanted to send #{num_ships} from #{source.planet_id} to #{target.planet_id}, while there are only #{ships_available_on(source)} available!"
    end
  end
end
