from random import random, randint, choice
from math import sqrt

#
# Constants
#
maxFace = 12
maxPanel = 10
maxColor = 1536
maxDir = 6

NUM_PIXELS = 144

#
# Common random functions
#

# Random chance. True if 1 in Number
def oneIn(chance):
	return True if randint(1,chance) == 1 else False

# Return either 1 or -1
def plusORminus():
	return (randint(0,1) * 2) - 1

# Increase or Decrease a counter with a range
def upORdown(value, amount, min, max):
	value += (amount * plusORminus())
	return bounds(value, min, max)

# Increase/Decrease a counter within a range
def inc(value, increase, min, max):
	value += increase
	return bounds(value, min, max)

def bounds(value, min, max):
	if value < min:
		value = max
	if value > max:
		value = min
	return value

# Get a random face
def randFace():
	return randint(0,maxFace - 1)

# Get a random panel
def randPanel():
	return randint(0,maxPanel - 1)

# Get a random cell
def randCell():
	return (randFace(),randPanel())

# Get a random direction
def randDir():
	return randint(0,maxDir)

# Return the left direction
def turn_left(dir):
	return (maxDir + dir - 1) % maxDir
	
# Return the right direction
def turn_right(dir):
	return (dir + 1) % maxDir

# Randomly turn left, straight, or right
def turn_left_or_right(dir):
	return (maxDir + dir + randint(-1,1) ) % maxDir

# In Bounds
def in_bounds(coord):
	(face,panel) = coord
	return (face >= 0 and face < maxFace and panel >= 0 and panel < maxPanel)

#
# Directions
#
maxDir = 4

# Get a random direction
def randDir():
	return randint(0,maxDir)

# Return the left direction
def turn_left(dir):
	return (maxDir + dir - 1) % maxDir
	
# Return the right direction
def turn_right(dir):
	return (dir + 1) % maxDir

# Randomly turn left, straight, or right
def turn_left_or_right(dir):
	return (maxDir + dir + randint(-1,1) ) % maxDir

#
# Color Functions
#
	
# Pick a random color
def randColor():
	return randint(0,maxColor-1)
	
# Returns a random color around a given color within a particular range
# Function is good for selecting blues, for example
def randColorRange(color, window):
	return (maxColor + color + randint(-window,window)) % maxColor

# Increase color by an amount (can be negative)
def changeColor(color, amount):
	return (maxColor + color + amount) % maxColor

# Wrapper for gradient_wheel in which the intensity is 1.0 (full)
def wheel(color):
	# FIX: should not need the 0.5!
	return gradient_wheel(color, 0.5)

# Picks a color in which one rgb channel is off and the other two channels
# revolve around a color wheel
def gradient_wheel(color, intense):
	intense /= 2	# Not sure why I need to do this!!!
	color = color % maxColor  # just in case color is out of bounds
	channel = color // 256;
	value = color % 256;

	if channel == 0:
		r = 255
		g = value
		b = 0
	elif channel == 1:
		r = 255 - value
		g = 255
		b = 0
	elif channel == 2:
		r = 0
		g = 255
		b = value
	elif channel == 3:
		r = 0
		g = 255 - value
		b = 255
	elif channel == 4:
		r = value
		g = 0
		b = 255
	else:
		r = 255
		g = 0
		b = 255 - value
	return (r*intense, g*intense, b*intense)
	
# Picks a color in which one rgb channel is ON and the other two channels
# revolve around a color wheel
def white_wheel(color, intense):
	intense /= 2	# Not sure why I need to do this!!!
	color = color % maxColor  # just in case color is out of bounds
	channel = color / 256;
	value = color % 256;

	if channel == 0:
		r = 255
		g = value
		b = 255 - value
	elif channel == 1:
		r = 255 - value
		g = 255
		b = value
	elif channel == 2:
		r = value
		g = 255 - value
		b = 255
	elif channel == 3:
		r = 255
		g = value
		b = 255 - value
	elif channel == 4:
		r = 255 - value
		g = 255
		b = value
	else:
		r = value
		g = 255 - value
		b = 255
	
	return (r*intense, g*intense, b*intense)

#
# Sphere coordinates
#
def getCenters():
	"""Return an dictionary (f,p) of panel centers"""
	A = 1.618;	# (1 * sqr(5) / 2)
	B = 0.618;	# 1 / (1 * sqr(5) / 2

	vertices = [(1, 1, 1), (1, 1, -1), (1, -1, 1), (1, -1, -1),
				(-1, 1, 1), (-1, 1, -1), (-1, -1, 1), (-1, -1, -1),
				(0, B, A), (0, B, -A), (0, -B, A), (0, -B, -A),
				(B, A, 0), (B, -A, 0), (-B, A, 0), (-B, -A, 0),
				(A, 0, B), (A, 0, -B), (-A, 0, B), (-A, 0, -B)]

	faces = [(0, 16, 2, 10, 8), (0, 8, 4, 14, 12), (16, 17, 1, 12, 0),
			 (1, 9, 11, 3, 17), (1, 12, 14, 5, 9), (2, 13, 15, 6, 10),
			 (13, 3, 17, 16, 2), (3, 11, 7, 15, 13), (4, 8, 10, 6, 18),
			 (14, 5, 19, 18, 4), (5, 19, 7, 11, 9), (15, 7, 19, 18, 6)]

	centers = {}

	for f in range(maxFace):

		corners = [vertices[faces[f][i]] for i in range(5)]	# 5 pentagon corners
		center = set_magnitude(lerp(lerp(corners[0], corners[1], 0.5), corners[3], 0.447))	# pentagon center

		for i in range(5):
			half = set_magnitude(lerp(corners[i], corners[(i+1)%5], 0.5))
			centers[(f,i*2)] = set_magnitude(get_center(corners[i], half, center))
			centers[(f,(i*2)+1)] = set_magnitude(get_center(corners[(i+1)%5], half, center))

	return centers

def lerp(V1, V2, x):
	"""Linear interpolation of x (0-1.0) between V1 and V2"""
	return [((1-x) * V1[0]) + (x * V2[0]), ((1-x) * V1[1]) + (x * V2[1]), ((1-x) * V1[2]) + (x * V2[2])]

def get_center(V1, V2, V3):
	"""Center of 3 vertices"""
	return [(V1[0]+V2[0]+V3[0])/3, (V1[1]+V2[1]+V3[1])/3, (V1[2]+V2[2]+V3[2])/3]

def set_magnitude(V, r=1):
	"""Return vector V (x,y,z) set to magnitude r - Default is normalization to length 1"""
	length = sqrt((V[0]*V[0]) + (V[1]*V[1]) + (V[2]*V[2]))
	coeff = r / length
	return [V[0]*coeff, V[1]*coeff, V[2]*coeff]

def get_distance(V1, V2):
	"""Distance between two Vertices"""
	return sqrt(((V2[0]-V1[0])*(V2[0]-V1[0])) + ((V2[1]-V1[1])*(V2[1]-V1[1])) + ((V2[2]-V1[2])*(V2[2]-V1[2])))