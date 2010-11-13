import math
import random

planets = []

minShips = 1
maxShips = 100
minGrowth = 1
maxGrowth = 5
minDistance = 2
maxRadius = 12
epsilon = 0.002

def make_planet(x, y, owner, num_ships, growth_rate):
    return {"x" : x, "y" : y, "owner" : owner, "num_ships" : num_ships, "growth_rate" : growth_rate}

def print_planet(p):
    print "P " + str(p["x"]) + " " + str(p["y"]) + " " + str(p["owner"]) + " " + str(p["num_ships"]) + " " + str(p["growth_rate"])

def translate_planets(planets):
    for p in planets:
        p["x"] += maxRadius+2
        p["y"] += maxRadius+2

def generate_coordinates(p, r, theta):
    if theta < 0:
        theta += 360
    if theta >= 360:
        theta -= 360
    p["x"] = r * math.cos( math.radians(theta) )
    p["y"] = r * math.sin( math.radians(theta) )


def rand_num(min, max):
    return (random.random() * (max-min) ) + min

def distance(p1, p2):
    dx = p1["x"] - p2["x"]
    dy = p1["y"] - p2["y"]
    return math.ceil(math.sqrt(dx * dx + dy * dy))

def actual_distance(p1, p2):
    dx = p1["x"] - p2["x"]
    dy = p1["y"] - p2["y"]
    return math.sqrt(dx * dx + dy * dy)

def not_valid(p1, p2):
    adist = actual_distance(p1, p2)
    if distance(p1, p2) < minDistance or abs(adist - round(adist)) < epsilon:
        return True
    for p in planets:
        adist1 = actual_distance(p, p1)
        adist2 = actual_distance(p, p2)
        if distance(p, p1) < minDistance or distance(p, p2) < minDistance or abs(adist1-round(adist1)) < epsilon or abs(adist2-round(adist2)) < epsilon:
            return True
    return False



#makes the centre neutral planet
planets.append(make_planet(0, 0, 0, random.randint(minShips, maxShips), random.randint(0, maxGrowth)))


#picks out the home planets
r = rand_num(minDistance, maxRadius)
theta1 = rand_num(0, 360)
theta2 = rand_num(0, 360)
p1 = make_planet(0, 0, 1, 100, 5)
p2 = make_planet(0, 0, 2, 100, 5)
generate_coordinates(p1, r, theta1)
generate_coordinates(p2, r, theta2)

while not_valid(p1, p2):
    r = rand_num(minDistance, maxRadius)
    theta1 = rand_num(0, 360)
    theta2 = rand_num(0, 360)
    generate_coordinates(p1, r, theta1)
    generate_coordinates(p2, r, theta2)
planets.append(p1)
planets.append(p2)


#picks out the rest of the neutral planets
for i in range(10):
    r = rand_num(minDistance, maxRadius)
    theta = rand_num(0, 360)
    if i == 0:
        num_ships = random.randint(minShips, 5*distance(p1, p2)-1)
    else:
        num_ships = random.randint(minShips, maxShips)
    growth_rate = random.randint(minGrowth, maxGrowth)
    p1 = make_planet(0, 0, 0, num_ships, growth_rate)
    p2 = make_planet(0, 0, 0, num_ships, growth_rate)
    generate_coordinates(p1, r, theta1+theta)
    generate_coordinates(p2, r, theta2-theta)

    while not_valid(p1, p2):
        r = rand_num(minDistance, maxRadius)
        theta = rand_num(0, 360)
        generate_coordinates(p1, r, theta1+theta)
        generate_coordinates(p2, r, theta2-theta)
    planets.append(p1)
    planets.append(p2)

translate_planets(planets)

for p in planets:
    print_planet(p)
