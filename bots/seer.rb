# Seer behaves like the Speed bot (attack the most valuable planet nearby),
# but it accounts for planet growth and fleets in the air. It predicts the future.
class Seer < AI
  attr_accessor :reserved

  bot 'seer'
  # v1: Speed clone, remove fleet limit
  # v2: Naieve claim strategy pays attention to fleets and growth
  version 2

  LOOK_AHEAD=10
  PROXIMITY = 5
  PLANET_TURN_ESTIMATE = 15

  def reserved
    @reserved ||= Hash.new
  end

  def do_turn
    return if @pw.my_planets.length == 0
    return if @pw.not_my_planets.length == 0

    self.reserved.clear

    # Calculate planet population for the next X turns for all planets
    # * Minimum population of my planets is the Strikeforce
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

  def strikeforce_for(planet_id)
    @pw.planets[planet_id].num_ships - reserved_for(planet_id)
  end

  def reserved_for(planet_id)
    @reserved[planet_id]||=0
  end
end