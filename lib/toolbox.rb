module Toolbox
  protected

  def do_turn
    super
    self.log_planets
  end

  def log_planets
    @pw.planets.each do |planet|
      inbound_ships = @pw.fleets_underway_to(planet).inject(0) {|ships, f| ships + (f.mine? ? f.num_ships : -f.num_ships)}
      warning = ""
      if planet.mine?
        if inbound_ships < 0
          warning << "!"
          predictions = predict_future_population(planet, @pw.fleets_underway_to(planet).map{|f| f.turns_remaining}.max)
          if predictions.any?{|future| future.enemy?}
            warning << "!"
            warning << "!" unless predictions.last.mine?
            warning << " [#{predictions.map{|f| f.mine? ? f.num_ships : -f.num_ships}.join(", ")}]"
          end
        end
      elsif nearest_planet = @pw.my_closest_planets(planet).first
        distance = @pw.travel_time(planet, nearest_planet)
        invasion_fleet = ships_needed_to_capture(planet, distance)
        if invasion_fleet > 0
          turns_needed_to_regenerate = planet.growth_rate > 0 ? (invasion_fleet.to_f / planet.growth_rate).ceil : -1
          turns_invested = turns_needed_to_regenerate >= 0 ? distance + turns_needed_to_regenerate : -0
          warning = "[Invasion: D:%2i F:%4i T:%3i]" % [distance, invasion_fleet, turns_invested]
        else
          predictions = predict_future_population(planet, distance)
          victory_turn = predictions.find{|future| future.mine?}
          warning = "[Invasion in %i turns]" % [predictions.index(victory_turn)+1]
        end
      end
      log "Planet id %3i O:%1i P:%4i G:%2i I:%4i %s" % [planet.planet_id, planet.owner, planet.num_ships, planet.growth_rate, inbound_ships, warning]
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

  def my_planets_by_distance_to_enemy(planets=@pw.my_planets)
    return planets unless @pw.enemy_planets.size > 1
    planets.sort_by{|planet| @pw.distance(planet, @pw.closest_enemy_planets(planet).first)}
  end

  def enemy_planets_by_distance_to_me(planets=@pw.enemy_planets)
    return planets unless @pw.my_planets.size > 1
    planets.sort_by{|planet| @pw.distance(planet, @pw.my_closest_planets(planet).first)}
  end

  def easiest_planets_to_capture(planets=@pw.not_my_planets, options={})
    options = {:pruning=>true}.merge(options)
    if options[:pruning]
      selected_planets = planets.select {|planet|
        # Distance-based pruning: reject planets closer to enemies than to friendly planets
        next unless my_closest_planet = @pw.my_closest_planets(planet).first
        next unless closest_enemy_planet = @pw.closest_enemy_planets(planet).first
        next false if @pw.distance(planet, my_closest_planet) - @pw.distance(planet, closest_enemy_planet) > 0
        planet.growth_rate >= 1
      }
    else
      selected_planets = planets
    end
    selected_planets.sort_by do |planet|
      # Defensibility pruning: reject planets that are likely to be recaptured and lost
      if closest_enemy_planet = @pw.closest_enemy_planets(planet).first
        nearest_fleet = closest_enemy_planet.num_ships
        regen_until_enemy_arrives = @pw.travel_time(closest_enemy_planet, planet) * planet.growth_rate
      else
        nearest_fleet = 0
        regen_until_enemy_arrives = 0
      end
      if closest_friendly_planet = @pw.my_closest_planets(planet).first
        distance_to_friendly = @pw.travel_time(planet, closest_friendly_planet)
      else
        distance_to_friendly = 0
      end
      growth_rate_factor = planet.neutral? ? planet.growth_rate : 2 * planet.growth_rate
      # Lower score means more desirable
      # Higher growth means the total score will be lower
      # Longer distance to travel is less desirable, so should increase score
      # Longer distance from enemy planets decreases score as it is more defensible
      # Enemy planet is double the value of a neutral, since it reduces the strength of the enemy
      next 0 if planet.growth_rate == 0
      (planet.num_ships + nearest_fleet - regen_until_enemy_arrives + (distance_to_friendly*planet.growth_rate)) / growth_rate_factor
    end
  end

  def predict_future_population(target, turns=nil)
    predictions = [target.clone]
    inbound_fleets = @pw.fleets_underway_to(target) + fleets_dispatched[target.planet_id]
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
