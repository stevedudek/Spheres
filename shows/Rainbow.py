from HelperFunctions import*
from math import sin

class Rainbow(object):
	def __init__(self, spheremodel):
		self.name = "Rainbow"
		self.sphere = spheremodel
		self.speed = 0.1
		self.color = randColor()
		self.color_inc = randColor()
		self.center = randCell()
		self.clock_max = randint(25,500)
		self.clock = 0

	
	def next_frame(self):

		centers = getCenters()

		while (True):

			for f in range(maxFace):
				for p in range(maxPanel):
					angle = sin(2 * 3.14159 * self.clock / self.clock_max) + 1	# 0 to 2
					gradient = get_distance(centers[(f,p)], centers[self.center])	# 0 to 2
					intense = abs(angle - gradient) / 2 	# 0 to 1

					self.sphere.set_cells([(f,p)], wheel(self.color + (intense * self.color_inc)))

			self.color = changeColor(self.color, 1)

			self.clock = (self.clock + 1) % self.clock_max	# Smaller the number, the faster the fade

			if oneIn(200):
				self.color_inc = randColor()
			if oneIn(200):
				self.center = randCell()
			if oneIn(200):
				self.clock_max = randint(25,500)

			yield self.speed