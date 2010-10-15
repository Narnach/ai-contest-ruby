class Naieve < AI
  bot 'naieve'

  def do_turn
    return if @pw.my_fleets.length >= 3
    return if @pw.my_planets.length == 0
    return if @pw.not_my_planets.length == 0

    # get a list of planets owned by me, sorted from weakest to strongest
    my_planets = @pw.my_planets.sort_by {|x| x.num_ships }
    # get a list of planets that aren't mine, from strongest to weakest
    other_planets = @pw.not_my_planets.sort_by {|x| 1.0/(1+x.num_ships) }

    # send half of the ships from my weakest planet to my strongest one
    source = my_planets[-1].planet_id
    source_ships = my_planets[-1].num_ships
    dest = other_planets[-1].planet_id
    if source >= 0 and dest >= 0 
      num_ships = source_ships / 2
      @pw.issue_order(source, dest, num_ships)
    end
  end
end