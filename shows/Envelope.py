from HelperFunctions import*
from math import sin

class Envelope(object):
	def __init__(self, spheremodel):
		self.name = "Envelope"
		self.sphere = spheremodel
		self.speed = 0.5
		self.color = randColor()
		self.center = randCell()
		self.done = 0	# ranges from 0 to 2
		self.done_inc = 0.1

	
	def next_frame(self):

		centers = getCenters()

		while (True):

			new_cells = [cell for cell in self.sphere.all_cells_same_sphere()
						 if get_distance(centers[self.center], centers[cell]) >= self.done and
							get_distance(centers[self.center], centers[cell]) < self.done + self.done_inc]

			self.sphere.set_cells(new_cells, gradient_wheel(self.color, 0.5))

			self.done += self.done_inc

			if self.done > 2.0:
				self.done = 0
				self.color = randColor()
				self.center = randCell()

			yield self.speed