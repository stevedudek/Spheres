from HelperFunctions import*
	
class Fan(object):
	def __init__(self, spheremodel):
		self.name = "Fan"        
		self.sphere = spheremodel
		self.speed = 0.2
		self.color = randColor()
		self.clock = 0

	
	def next_frame(self):

		while (True):

			for f in range(maxFace):
				for p in range(maxPanel):
					intense = 1 - (((p + self.clock) % maxPanel) / float(maxPanel))
					self.sphere.set_cell((f,p), gradient_wheel(self.color, intense))

			# Change it up!
			if oneIn(10):
				self.color = changeColor(self.color, 1)

			self.clock += 1

			yield self.speed