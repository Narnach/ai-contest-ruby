class Bullybot < AI
  include Toolbox
  include ShipsAvailable
  bot 'bullybot'

  def do_turn
    super
    # If we have a fleet in flight, do nothing
    return if @pw.my_fleets.any?
    # Pick my strongest planet
    source = @pw.my_planets.sort_by{|planet| -planet.num_ships}.first
    # Pick weakest other planet
    target = @pw.not_my_planets.sort_by{|planet| planet.num_ships}.first
    # Send half the source planet's ships away
    attack_with(source, target, source.num_ships / 2)
  end
end