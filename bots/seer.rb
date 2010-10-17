# Seer behaves like the Speed bot (attack the most valuable planet nearby),
# but it accounts for planet growth and fleets in the air. It predicts the future.
class Seer < AI
  bot 'seer'
  # v1: Speed clone, remove fleet limit
  # v2: Naieve claim strategy pays attention to fleets and growth
  version 2

  LOOK_AHEAD=10
  PROXIMITY = 5
  PLANET_TURN_ESTIMATE = 15

  def do_turn
    return if @pw.my_planets.length == 0
    return if @pw.not_my_planets.length == 0

    self.reserved.clear

    # Calculate planet population and ownership for the next X turns for all planets based on no new fleets launching
    self.predict_planet_futures

    # * Minimum population of my planets is the Strikeforce
    self.calculate_strikeforce

    # Reinforce my planets that are under attack
    # * Negative future population = reinforce from Strikeforce
    # * Shortest-term threats go first

    # Double-check Targets (non-owned planets with friendly ships en-route) will still be claimed
    # * Dispatch help from Strikeforce based on shortest-term threads go firsts

    # Find targets of opportunity
    # * Neutral planet that gets taken over: SNIPE!
    # * Use naieve claim strategy for remaining Strikeforce
    self.naieve_claim_strategy
  end

  protected

  def naieve_claim_strategy
    # Old Speed bot behaviour, will eventually be dropped once all logic has been redone.
    @pw.my_planets.each do |planet|
      return log('almost out of time') if time_left < 0.1
      next if planet.num_ships == 0

      # From the closest 5 planets, pick the one with the best tradeoff between defending ships and growth rate
      target = @pw.not_my_planets.sort_by {|p| @pw.distance(planet, p)}[0...PROXIMITY].sort_by {|p| (p.growth_rate * PLANET_TURN_ESTIMATE) - p.num_ships}.last

      # Check how many ships we need to send to defeat it
      if target.neutral?
        ships_needed = target.num_ships + 1
      else
        ships_needed = target.num_ships + 1 + (@pw.distance(planet, target) * target.growth_rate).to_i
      end

      ships_sent = @pw.my_fleets.inject(0) do |ships, fleet|
        if fleet.destination_planet == target.planet_id
          ships + fleet.num_ships
        else
          ships
        end
      end
      enemy_ships_sent = @pw.enemy_fleets.inject(0) do |ships, fleet|
        if fleet.destination_planet == target.planet_id
          ships + fleet.num_ships
        else
          ships
        end
      end
      planet_growth = target.neutral? ? 0 : (@pw.travel_time(planet, target) * target.growth_rate)

      # Determine how many ships to send
      ships_left = (ships_needed + planet_growth + enemy_ships_sent) - ships_sent

      # Only send fleets that could win by themselves
      next if ships_left > planet.num_ships

      # Send ships if we have to
      num_ships = [ships_left, strikeforce_for(planet.planet_id)].min
      next if num_ships <= 0
      @pw.issue_order(planet.planet_id, target.planet_id, num_ships)
    end
  end

  ###### Strikeforce

  def reserved
    @reserved ||= Hash.new
  end

  def strikeforce_for(planet_id)
    @pw.planets[planet_id].num_ships - reserved_for(planet_id)
  end

  def reserved_for(planet_id)
    @reserved[planet_id]||=0
  end

  def calculate_strikeforce
    # TODO: Calculate strikeforce per planet
  end

  ###### Future prediction

  def forecast
    @forecast ||= Hash.new
  end

  def predict_planet_futures
    self.forecast.clear
    @pw.planets.each do |planet|
      self.forecast[planet.planet_id] = [planet.clone]
      (1...LOOK_AHEAD).each do |future_turn|
        self.forecast[planet.planet_id] << self.future_planet(planet.planet_id, future_turn)
      end
    end
  end

  # Given a planet in the state it was before the turn, calculate it after the turn. Helper method for predict_planet_populations.
  def future_planet(planet_id, turn)
    planet = self.forecast[planet_id].last.clone
    if planet.neutral?
      # No growth, battles can be 3-way
      p1_ships = @pw.fleets.select{|fleet| fleet.owner == 1 && fleet.turns_remaining == turn}.inject(0){|ships, fleet| ships + fleet.num_ships}
      p2_ships = @pw.fleets.select{|fleet| fleet.owner == 2 && fleet.turns_remaining == turn}.inject(0){|ships, fleet| ships + fleet.num_ships}

      # No invaders? Then the planet stays as it is
      return planet if p1_ships == 0 && p2_ships == 0

      # Are there two invaders?
      if p1_ships > 0 && p2_ships > 0
        # Attackers are the same size, so invasion fails. Neutral keeps the planet.
        if p1_ships == p2_ships
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
          planet.owner = 2
          planet.num_ships = p1_ships - planets.num_ships
        else
          # Invader loses
          planet.num_ships -= p1_ships
        end
      else # p2
        if planet.num_ships < p2_ships
          # Invader wins, owns planet
          planet.owner = 2
          planet.num_ships = p2_ships - planets.num_ships
        else
          # Invader loses
          planet.num_ships -= p2_ships
        end
      end
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
end