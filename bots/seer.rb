# Seer behaves like the Speed bot (attack the most valuable planet nearby),
# but it accounts for planet growth and fleets in the air. It predicts the future.
class Seer < AI
  bot 'seer'
  # v1: Speed clone, remove fleet limit
  # v2: Naieve claim strategy pays attention to fleets and growth
  # v3: Strikeforce calculations help in finding targets
  # v4: Multiple reactive strategies are implemented. Speed bot still wins 100%, though.
  version 4

  LOOK_AHEAD=10
  PROXIMITY = 5
  PLANET_TURN_ESTIMATE = 15

  def do_turn
    return if @pw.my_planets.length == 0
    return if @pw.not_my_planets.length == 0

    # Calculate planet population and ownership for the next X turns for all planets based on no new fleets launching
    self.predict_planet_futures

    # * Minimum population of my planets is the Strikeforce
    self.calculate_strikeforce

    # Reinforce my planets that are under attack
    # * Negative strikeforce means: HELP!
    # * Shortest-term threats go first
    self.reinforce_planets_in_need

    # Double-check Targets (non-owned planets with friendly ships en-route) will still be claimed
    # * Dispatch help from Strikeforce based on shortest-term threads go firsts
    self.reinforce_attack_fleeds_in_need

    # Calculate ratio of friendly / hostile ships in proximity of all our planets and send reinforcements from safe planets to unsafe planets
    self.reinforce_planets_in_hostile_territory

    # Find targets of opportunity
    # * Neutral planet that gets taken over: SNIPE!
    # * Use naieve claim strategy for remaining Strikeforce
    self.naieve_claim_strategy
  end

  protected

  def naieve_claim_strategy
    # Old Speed bot behaviour, will eventually be dropped once all logic has been redone.
    @pw.my_planets.each do |planet|
      # From the closest 5 planets, pick the one with the best tradeoff between defending ships and growth rate
      @pw.not_my_planets.sort_by {|p| @pw.distance(planet, p)}[0...PROXIMITY].select{|planet| strikeforce_for(planet.planet_id) > 0}.sort_by {|p| (p.growth_rate * PLANET_TURN_ESTIMATE) - p.num_ships}.reverse.each do |target|
        return log('almost out of time') if time_left < 0.1
        strikeforce = strikeforce_for(planet.planet_id)
        if strikeforce == 0
          log "Strikeforce for planet #{planet.planet_id} is 0."
          break
        end

        log "Considering planet #{planet.planet_id} attacks #{target.planet_id}"
        # Check how many ships we need to send to defeat it
        ships_needed = target.num_ships + 1

        # Our ships already underway
        ships_sent = @pw.my_fleets.inject(0) do |ships, fleet|
          if fleet.destination_planet == target.planet_id
            ships + fleet.num_ships
          else
            ships
          end
        end

        # Enemy ships already underway
        enemy_ships_sent = @pw.enemy_fleets.inject(0) do |ships, fleet|
          if fleet.destination_planet == target.planet_id
            ships + fleet.num_ships
          else
            ships
          end
        end

        # Enemy planet growth
        planet_growth = target.neutral? ? 0 : (@pw.travel_time(planet, target) * target.growth_rate)

        # Determine how many ships to send
        ships_left = (ships_needed + planet_growth + enemy_ships_sent) - ships_sent
        log "ships_left = (ships_needed + planet_growth + enemy_ships_sent) - ships_sent :: #{ships_left} = (#{ships_needed} + #{planet_growth} + #{enemy_ships_sent}) - #{ships_sent}"

        # Only send fleets that could win by themselves
        if strikeforce < ships_left
          log "The number of ships we want to send from #{planet.planet_id} to #{target.planet_id} is #{ships_left}. Strikeforce is only #{strikeforce}, so skipping it."
          break
        end

        # Send ships if we have to
        num_ships = [ships_left, strikeforce].min

        if num_ships <= 0
          log "The number of ships we want to send from #{planet.planet_id} to #{target.planet_id} is #{num_ships}, so skipping it. Needed: #{ships_left}, S: #{strikeforce}."
          break
        end

        log "Attack plans from #{planet.planet_id} (P:#{planet.num_ships}, S:#{strikeforce}) to #{target.planet_id} (P:#{target.num_ships}): F:#{num_ships}"
        @pw.issue_order(planet.planet_id, target.planet_id, num_ships)
        self.strikeforces[planet.planet_id] -= num_ships
        self.strikeforces[target.planet_id] -= num_ships
      end
    end
  end

  ###### Strikeforce

  def strikeforces
    @strikeforces ||= Hash.new
  end

  def strikeforce_for(planet_id)
    self.strikeforces[planet_id]
  end

  def calculate_strikeforce
    self.strikeforces.clear
    self.forecast.each do |planet_id, futures|
      strikeforce = futures.first.num_ships
      # log "Initial strikeforce: #{strikeforce}"
      owner = futures.first.owner
      futures.each_with_index do |future, turn|
        if future.owner == owner
          old_strikeforce = strikeforce
          strikeforce = [old_strikeforce, future.num_ships].min
          # log "Update strikeforce: strikeforce = [old_strikeforce, future.num_ships].min :: #{strikeforce} = [#{old_strikeforce}, #{future.num_ships}].min :: future: #{future.inspect}"
        else
          # TODO: Add to list of planets that require reinforcement
          strikeforce = -future.num_ships
          log "Planet #{planet_id} (O: #{futures.first.owner}, P: #{futures.first.num_ships}) has a strikeforce of #{strikeforce} when it is captured by #{future.owner}."
          break
        end
      end
      log "Planet #{planet_id} (O: #{futures.first.owner}, P: #{futures.first.num_ships}) has a strikeforce of #{strikeforce}" if strikeforce >= 0
      self.strikeforces[planet_id] = strikeforce
    end
  end

  ###### Future prediction

  def forecast
    @forecast ||= Hash.new
  end

  def predict_planet_futures
    self.forecast.clear
    @pw.planets.each do |planet|
      # log "Original: #{planet.inspect}"
      self.forecast[planet.planet_id] = [planet.clone]
      # log "Clone: #{self.forecast[planet.planet_id].last.inspect}"
      (1...LOOK_AHEAD).each do |future_turn|
        prediction = self.future_planet(planet.planet_id, future_turn)
        # log "Prediction #{future_turn}: #{prediction.inspect}"
        self.forecast[planet.planet_id] << prediction
      end
    end
  end

  # Given a planet in the state it was before the turn, calculate it after the turn. Helper method for predict_planet_populations.
  def future_planet(planet_id, turn)
    planet = self.forecast[planet_id].last.clone
    if planet.neutral?
      # No growth, battles can be 3-way
      inbound_fleets = @pw.fleets.select{|fleet| fleet.destination_planet == planet_id && fleet.turns_remaining == turn}
      p1_ships = inbound_fleets.select{|fleet| fleet.owner == 1}.inject(0){|ships, fleet| ships + fleet.num_ships}
      p2_ships = inbound_fleets.select{|fleet| fleet.owner == 2}.inject(0){|ships, fleet| ships + fleet.num_ships}
      # log "P1 ships: #{p1_ships}, P2 ships: #{p2_ships}"

      # No invaders? Then the planet stays as it is
      return planet if p1_ships == 0 && p2_ships == 0

      # Are there two invaders?
      if p1_ships > 0 && p2_ships > 0
        # Attackers are the same size, so invasion fails. Neutral keeps the planet.
        if p1_ships == p2_ships
          log "In #{turn} turns, on planet #{planet_id}, two players invade at the same time: #{p1_ships} && #{p2_ships} vs #{planet.num_ships}. Resetting planet ships to 0."
          planet.num_ships = 0
          return planet
        end

        # All forces fight. Winner is the one with the biggest fleet. Leftover ships is diff with 2nd fleet.
        if p1_ships > (enemies = [p2_ships, planet.num_ships].max)
          # p1 wins
          planet.owner = 1
          planet.num_ships = p1_ships - enemies
        elsif p2_ships > (enemies = [p1_ships, planet.num_ships].max)
          # p2 wins
          planet.owner = 2
          planet.num_ships = p2_ships - enemies
        else
          # neutral wins
          planet.num_ships -= [p1_ships, p2_ships].max
        end
        return planet
      elsif p1_ships > 0
        if planet.num_ships < p1_ships
          # Invader wins, owns planet
          planet.owner = 1
          planet.num_ships = p1_ships - planet.num_ships
        else
          # Invader loses
          planet.num_ships -= p1_ships
        end
      else # p2
        if planet.num_ships < p2_ships
          # Invader wins, owns planet
          planet.owner = 2
          planet.num_ships = p2_ships - planet.num_ships
        else
          # Invader loses
          planet.num_ships -= p2_ships
        end
      end
      return planet
    else
      # Growth, battles only 2-way
      planet.num_ships += planet.growth_rate
      planet.num_ships += @pw.fleets.select{|fleet| fleet.owner == planet.owner && fleet.turns_remaining == turn}.inject(0){|ships, fleet| ships + fleet.num_ships}
      invaders = @pw.fleets.select{|fleet| fleet.owner != planet.owner && fleet.turns_remaining == turn}.inject(0){|ships, fleet| ships + fleet.num_ships}
      if invaders > planet.num_ships
        planet.num_ships = invaders - planet.num_ships
        planet.owner = (planet.owner == 1 ? 2 : 1) # Change owner
      else
        planet.num_ships -= invaders
      end
      return planet
    end
  end

  ##### Reinforce

  def reinforce_planets_in_need
    log "Reinforcing our own planets in need"
    my_planets_in_need = self.strikeforces.select {|planet_id, strikeforce| strikeforce < 0 && @pw.planets[planet_id].mine?}
    if my_planets_in_need.empty?
      log "There are no planets in need"
      return
    end
    most_needy_planets = my_planets_in_need.sort_by {|planet_id, strikeforce| self.forecast[planet_id].index{|future| !future.mine? && future.num_ships == strikeforce.abs} }
    most_needy_planets.each do |planet_id, strikeforce|
      turns_before_attack = self.forecast[planet_id].index{|future| !future.mine? && future.num_ships == strikeforce.abs}
      log "Planet #{planet_id} has a negative strikeforce: #{strikeforce}. It needs help within #{turns_before_attack} turns!"

      # Find planets that could possibly help
      target = @pw.planets[planet_id]
      planets_with_strikeforce = @pw.my_planets.select{ |planet| self.strikeforces[planet.planet_id] > 0 }
      planets_with_strikeforce_in_range = planets_with_strikeforce.select{ |planet| @pw.travel_time(planet, target) <= turns_before_attack }

      # Find the closest planets with the biggest strikeforces first
      helpful_planets = planets_with_strikeforce_in_range.sort do |a, b|
        travel_a = @pw.travel_time(a, target)
        travel_b = @pw.travel_time(b, target)
        if travel_a == travel_b
          self.strikeforces[b.planet_id] <=> self.strikeforces[a.planet_id] # Prefer higher strikeforces. b <=> a gives larger b first
        else
          travel_a <=> travel_b # Prefer closer planets. a <=> b gives smaller a first
        end
      end
      if helpful_planets.empty?
        log "There are no helpful planets to help planet #{target.planet_id} within #{turns_before_attack} turns."
      end

      # Send help until there is enough
      helpful_planets.each do |planet|
        helpful_strikeforce = self.strikeforces[planet.planet_id]
        ships_to_send = [strikeforce.abs, helpful_strikeforce].min
        log "Reinforce from #{planet.planet_id} (P:#{planet.num_ships}, S:#{helpful_strikeforce}) to #{target.planet_id} (P:#{target.num_ships}, S:#{strikeforce}): F:#{ships_to_send}"
        @pw.issue_order(planet.planet_id, target.planet_id, ships_to_send)
        self.strikeforces[planet.planet_id] -= ships_to_send
        # Don't increase strikeforce on target planet, as it is not yet available
        strikeforce += ships_to_send
        break if strikeforce >= 0
      end
      if strikeforce < 0
        log "Unable to send reinforcements to planet #{planet_id}"
      end
    end
  end

  def reinforce_attack_fleeds_in_need
    log "Reinforcing attack fleeds in need"
    my_fleets_in_need = @pw.my_fleets.select {|fleet| !@pw.planets[fleet.destination_planet].mine? && self.strikeforces[fleet.destination_planet] > 0}.sort_by {|fleet| self.strikeforces[fleet.destination_planet]}
    first_to_arrive_at_planet = my_fleets_in_need.inject([]) {|fleets, fleet| fleets.find{|ff| ff.destination_planet == fleet.destination_planet} ? fleets : fleets + [fleet]}
    if first_to_arrive_at_planet.empty?
      log "There are no fleets in need of reinforcement"
      return
    end
    first_to_arrive_at_planet.each do |fleet|
      strikeforce = self.strikeforces[fleet.destination_planet].abs + 1 # Add 1 to actually win the battle as agressor
      turns_before_attack = fleet.turns_remaining
      # Find planets that could possibly help
      target = @pw.planets[fleet.destination_planet]
      planets_with_strikeforce = @pw.my_planets.select{ |planet| self.strikeforces[planet.planet_id] > 0 }
      planets_with_strikeforce_in_range = planets_with_strikeforce.select{ |planet| @pw.travel_time(planet, target) <= turns_before_attack }

      # Find the closest planets with the biggest strikeforces first
      helpful_planets = planets_with_strikeforce_in_range.sort do |a, b|
        travel_a = @pw.travel_time(a, target)
        travel_b = @pw.travel_time(b, target)
        if travel_a == travel_b
          self.strikeforces[b.planet_id] <=> self.strikeforces[a.planet_id] # Prefer higher strikeforces. b <=> a gives larger b first
        else
          travel_a <=> travel_b # Prefer closer planets. a <=> b gives smaller a first
        end
      end

      if helpful_planets.empty?
        log "There are no helpful planets to help our fleet of #{fleet.num_ships} ships, who reaches planet #{fleet.destination_planet} in #{fleet.turns_remaining} turns."
        next
      end

      # Send help until there is enough
      helpful_planets.each do |planet|
        helpful_strikeforce = self.strikeforces[planet.planet_id]
        ships_to_send = [strikeforce.abs, helpful_strikeforce].min
        log "Reinforcement for attack fleet. From #{planet.planet_id} (P:#{planet.num_ships}, S:#{helpful_strikeforce}) to #{target.planet_id} (P:#{target.num_ships}, S:#{strikeforce}): F:#{ships_to_send}"
        @pw.issue_order(planet.planet_id, target.planet_id, ships_to_send)
        self.strikeforces[planet.planet_id] -= ships_to_send
        self.strikeforces[target.planet_id] -= ships_to_send
        strikeforce -= ships_to_send
        break if strikeforce <= 0
      end
      if strikeforce > 0
        log "Unable to send enough reinforcements to planet #{target.destination_planet}"
      end
    end
  end

  def reinforce_planets_in_hostile_territory
    log "Reinforcing planets in hostile territory"
    threat_balance = Hash.new { |hash, key| hash[key] = 0 }
    @pw.my_planets.each do |target|
      closest_planets = @pw.planets.sort_by{|planet| @pw.travel_time(planet, target) }[0...PROXIMITY]
      closest_planets.each do |planet|
        case planet.owner
        when 0
          # neutrals are no threat or help
        when 1
          threat_balance[target.planet_id] += planet.num_ships
        else
          threat_balance[target.planet_id] -= planet.num_ships
        end
      end
    end
    sorted_planets = @pw.my_planets.sort_by{|planet| threat_balance[planet.planet_id]}
    sorted_planets.each do |planet|
      log "Planet #{planet.planet_id} (P:#{planet.num_ships}, S:#{self.strikeforces[planet.planet_id]}, Threat:#{threat_balance[planet.planet_id]})"
    end

    # Unsafest first
    unsafe_planets = sorted_planets.select{|planet| threat_balance[planet.planet_id] < 0}
    if unsafe_planets.empty?
      log "There are no unsafe planets"
      return
    end

    # Safest first
    safe_planets = sorted_planets.select{|planet| threat_balance[planet.planet_id] >= 0}.reverse
    if safe_planets.empty?
      log "There are no safe planets"
      return
    end
    safe_planets.reject! {|planet| self.strikeforces[planet.planet_id] <= 0}
    if safe_planets.empty?
      log "There are no safe planets with a strikeforce"
      return
    end

    safe_planets.each_with_index do |planet, index|
      helpful_strikeforce = self.strikeforces[planet.planet_id]
      target = unsafe_planets[index % unsafe_planets.size]
      strikeforce = self.strikeforces[target.planet_id]
      ships_to_send = helpful_strikeforce / 2

      log "Reinforcement for unsafe planet. From #{planet.planet_id} (P:#{planet.num_ships}, S:#{helpful_strikeforce}) to #{target.planet_id} (P:#{target.num_ships}, S:#{strikeforce}): F:#{ships_to_send}"
      @pw.issue_order(planet.planet_id, target.planet_id, ships_to_send)
      self.strikeforces[planet.planet_id] -= ships_to_send
      # Don't increase strikeforce on target planet, as it is not yet available
    end
  end
end