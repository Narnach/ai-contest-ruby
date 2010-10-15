# Speed lets each planet attack the closest planet.
# Lower transit times means less time for planets to regenerate.
# A nice side-effect should be that it is a very defensive strategy,
# taking back planets that have been stolen by the enemy.
class Speed < AI
  bot 'speed'

  def do_turn
    return if @pw.my_fleets.length >= 10
    return if @pw.my_planets.length == 0
    return if @pw.not_my_planets.length == 0

    @pw.my_planets.each do |planet|
      return log('almost out of time') if time_left < 0.1
      next if planet.num_ships == 0

      # Pick the closest target
      target = @pw.not_my_planets.sort_by {|p| @pw.distance(planet, p)}.first

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