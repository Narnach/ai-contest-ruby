class Ragebot < AI
  include Toolbox
  include ShipsAvailable
  bot 'ragebot'

  def do_turn
    super
    @pw.my_planets.each do |planet|
      reserve = planet.growth_rate * 10
      next unless planet.num_ships > reserve
      next unless target = @pw.closest_enemy_planets(planet).first
      ships_to_send = planet.num_ships - reserve
      attack_with(planet, target, ships_to_send)
    end
  end
end