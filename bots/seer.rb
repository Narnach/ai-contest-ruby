# Seer behaves like the Speed bot (attack the most valuable planet nearby),
# but it accounts for planet growth and fleets in the air. It predicts the future.
class Seer < AI
  bot 'seer'

  LOOK_AHEAD=3

  def do_turn
    return if @pw.my_planets.length == 0
    return if @pw.not_my_planets.length == 0

    # Calculate planet population for the next X turns for all planets

    @pw.my_planets.each do |planet|
      return log('almost out of time') if time_left < 0.1
      next if planet.num_ships == 0

      # From the closest 5 planets, pick the one with the best tradeoff between defending ships and growth rate
      target = @pw.not_my_planets.sort_by {|p| @pw.distance(planet, p)}[0...5].sort_by {|p| (p.growth_rate * 10) - p.num_ships}.last

      # Check how many ships we need to send to defeat it
      if target.neutral?
        ships_needed = target.num_ships + 1
      else
        ships_needed = target.num_ships + 1 + (@pw.distance(planet, target) * target.growth_rate).to_i
      end

      # Discount how many ships are already underway
      # TODO: Discount flight time left against growth rate of enemy planet
      ships_sent = @pw.my_fleets.inject(0) do |ships, fleet|
        if fleet.destination_planet == target.planet_id
          ships + fleet.num_ships
        else
          ships
        end
      end

      # Determine how many ships to send
      ships_left = ships_needed - ships_sent

      # Only send fleets that could win by themselves
      next if ships_left > planet.num_ships

      # Send ships if we have to
      num_ships = [ships_left, planet.num_ships].min
      next if num_ships <= 0
      @pw.issue_order(planet.planet_id, target.planet_id, num_ships)
    end
  end
end