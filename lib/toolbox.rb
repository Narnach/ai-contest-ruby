module Toolbox
  protected

  def do_turn
    super
    self.log_planets
  end

  def log_planets
    @pw.planets.each do |planet|
      log "Planet id %3i O:%1i P:%4i G:%2i" % [planet.planet_id, planet.owner, planet.num_ships, planet.growth_rate]
    end
  end

  def ships_needed_to_capture(target, turns=nil)
    predictions = predict_future_population(target, turns)
    predictions.inject(0) do |ships, planet|
      if planet.mine?
        next 0
      else
        if ships > (planet.num_ships + 1)
          next ships
        else
          next planet.num_ships + 1
        end
      end
    end
  end

  def my_planets_by_distance_to_enemy
    return @pw.my_planets unless @pw.enemy_planets.size > 0
    @pw.my_planets.sort_by{|planet| @pw.distance(planet, @pw.closest_enemy_planets(planet).first)}
  end

  def easiest_planets_to_capture(planets=@pw.not_my_planets)
    planets.select {|planet|
      # Distance-based pruning: reject planets closer to enemies than to friendly planets
      next unless my_closest_planet = @pw.my_closest_planets(planet).first
      next unless closest_enemy_planet = @pw.closest_enemy_planets(planet).first
      next false if @pw.distance(planet, my_closest_planet) - @pw.distance(planet, closest_enemy_planet) > 0
      planet.growth_rate >= 1
    }.sort_by do |planet|
      # Defensibility pruning: reject planets that are likely to be recaptured and lost
      if closest_enemy_planet = @pw.closest_enemy_planets(planet).first
        nearest_fleet = closest_enemy_planet.num_ships
        regen_until_enemy_arrives = @pw.travel_time(closest_enemy_planet, planet) * planet.growth_rate
      else
        nearest_fleet = 0
        regen_until_enemy_arrives = 0
      end
      (planet.num_ships + nearest_fleet - regen_until_enemy_arrives) / planet.growth_rate
    end
  end

  def predict_future_population(target, turns=nil)
    predictions = [target.clone]
    inbound_fleets = @pw.fleets_underway_to(target) + @fleets_dispatched[target.planet_id]
    turns ||= inbound_fleets.map(&:turns_remaining).max || 0
    1.upto(turns) do |n|
      last_turn = predictions[n-1]
      planet = last_turn.clone
      planet.num_ships += planet.growth_rate unless planet.neutral?

      fleets = inbound_fleets.select{|fleet| fleet.turns_remaining == n}
      unless fleets.size == 0
        if planet.neutral?
          defenders = planet.num_ships
          my_attackers = fleets.select{|fleet| fleet.mine?}.inject(0){|ships, fleet| fleet.num_ships + ships}
          enemy_attackers = fleets.select{|fleet| fleet.enemy?}.inject(0){|ships, fleet| fleet.num_ships + ships}
          if defenders > my_attackers && defenders > enemy_attackers
            planet.num_ships = defenders - [my_attackers, enemy_attackers].max
          elsif my_attackers > defenders && my_attackers > enemy_attackers
            planet.owner = 1
            planet.num_ships = my_attackers - [defenders, enemy_attackers].max
          elsif enemy_attackers > defenders && enemy_attackers > my_attackers
            planet.owner = 2
            planet.num_ships = enemy_attackers - [defenders, my_attackers].max
          elsif my_attackers == enemy_attackers
            planet.num_ships = defenders - [defenders, my_attackers].min
          end
        elsif planet.mine?
          defenders = planet.num_ships + fleets.select{|fleet| fleet.mine?}.inject(0){|ships, fleet| fleet.num_ships + ships}
          attackers = fleets.select{|fleet| fleet.enemy?}.inject(0){|ships, fleet| fleet.num_ships + ships}
          if attackers > defenders
            planet.owner = 2
            planet.num_ships = attackers - defenders
          else
            planet.num_ships = defenders - attackers
          end
        else
          defenders = planet.num_ships + fleets.select{|fleet| fleet.enemy?}.inject(0){|ships, fleet| fleet.num_ships + ships}
          attackers = fleets.select{|fleet| fleet.mine?}.inject(0){|ships, fleet| fleet.num_ships + ships}
          if attackers > defenders
            planet.owner = 1
            planet.num_ships = attackers - defenders
          else
            planet.num_ships = defenders - attackers
          end
        end
      end
      predictions << planet
    end
    predictions
  end
end
