from HelperFunctions import*
from math import sin

class Stripes(object):
	def __init__(self, spheremodel):
		self.name = "Stripes"
		self.sphere = spheremodel
		self.speed = 1
		self.color1 = randColor()
		self.color2 = randColor()
		self.center = randCell()
		self.clock_max = 20
		self.clock = 1

	
	def next_frame(self):

		centers = getCenters()

		while (True):

			for f in range(maxFace):
				for p in range(maxPanel):
					distance = get_distance(centers[(f,p)], centers[self.center])	# 0 to 2

					color = self.color1 if round(distance * self.clock) % 2 else self.color2
					self.sphere.set_cells([(f,p)], wheel(color))

			self.color1 = changeColor(self.color1, 1)
			self.color2 = changeColor(self.color2, -2)

			self.clock = 1 + ((self.clock + 1) % self.clock_max)

			if oneIn(200):
				self.center = randCell()
			if oneIn(200):
				self.clock_max = randint(25,500)

			yield self.speed