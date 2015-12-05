from HelperFunctions import*
	
class Half(object):
	def __init__(self, spheremodel):
		self.name = "Half"
		self.sphere = spheremodel
		self.speed = 10
		self.color1 = randColor()
		self.color2 = randColor()
		self.color_inc = randint(10,40)
		self.clock = 0

	
	def next_frame(self):

		centers = getCenters()

		while (True):

			for f in range(maxFace):
				for p in range(maxPanel):
					# The [2] is the z-coordinate! Checking to see whether it is + or -
					color = self.color1 if centers[(f,p)][2] > 0 else self.color2
					self.sphere.set_cell((f,p), wheel(color))

			yield self.speed