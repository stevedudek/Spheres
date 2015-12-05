from HelperFunctions import*
from math import sin

class Fade(object):
	def __init__(self, spheremodel):
		self.name = "Fade"
		self.sphere = spheremodel
		self.speed = 0.1
		self.color = randColor()
		self.color_inc = randint(10,40)
		self.clock = 0

	
	def next_frame(self):

		centers = getCenters()

		while (True):

			for f in range(maxFace):
				for p in range(maxPanel):
					angle = sin(2 * 3.14159 * self.clock / 100) + 1	# 0 to 2
					gradient = get_distance(centers[(f,p)], centers[(0,0)])	# 0 to 2
					intense = abs(angle - gradient) / 2 	# 0 to 1

					self.sphere.set_cells([(f,p)], gradient_wheel(self.color, intense))

			self.color = changeColor(self.color, 1)

			self.clock = (self.clock + 1) % 100	# Smaller the number, the faster the fade

			yield self.speed