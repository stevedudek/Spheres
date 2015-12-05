"""
Model to communicate with a Sphere simulator over a TCP socket

"""

"""
Coordinates: (f,p) = (x,y) = (face,panel)  = (0-11, 0-9)

"""

NUM_PIXELS = 144
NUM_FACES = 12
NUM_PANELS = 10
NUM_BIG_SPHERE = 1

ALL_SPHERES = 9

from color import*
from collections import defaultdict
from random import choice

def load_spheres(model):
    return Sphere(model)

class Sphere(object):

    """
    Sphere coordinates are stored in a hash table.
    Keys are (s,f,p) coordinate triples
    Values are (strip, pixel) triples
    
    Frames implemented to shorten messages:
    Send only the pixels that change color
    Frames are hash tables where keys are (s,f,p) coordinates
    and values are (r,g,b) colors
    """
    def __init__(self, model):
        self.model = model
        self.cellmap = self.add_strips()
        self.curr_frame = {}
        self.next_frame = {}
        self.init_frames()

    def __repr__(self):
        return "Spheres(%s)" % (self.model, self.side)

    def all_cells(self):
        "Return the list of valid coords"
        return list(self.cellmap.keys())

    def all_cells_same_sphere(self):
        "Return all cells of one sphere"
        return [(f,p) for f in range(12) for p in range(10)]

    def cell_exists(self, coord, s=0):
        (f,p) = coord
        return self.cellmap[(s,f,p)]

    def set_cell(self, coord, color, s=ALL_SPHERES):
        if self.cell_exists(coord):
            (f,p) = coord
            if s == ALL_SPHERES:
                for s in range(NUM_BIG_SPHERE):
                    self.next_frame[(s,f,p)] = color
            else:
                self.next_frame[(s,f,p)] = color
        else:
            print "{} does not exist".format(coord)

    def set_cells(self, coords, color, s=ALL_SPHERES):
        for coord in coords:
            self.set_cell(coord, color, s)

    def set_all_cells(self, color):
        for c in self.all_cells():
            self.next_frame[c] = color

    def clear(self):
        self.force_frame()
        self.set_all_cells((0,0,0))
        self.go()

    def go(self):
        self.send_frame()
        self.model.go()
        self.update_frame()

    def morph(self, fract):
        self.model.morph(fract)

    def update_frame(self):
        for coord in self.next_frame:
            self.curr_frame[coord] = self.next_frame[coord]

    def send_frame(self):
        for coord,color in self.next_frame.items():
            if self.curr_frame[coord] != color: # Has the color changed? Hashing to color values
                self.model.set_cells(self.cellmap[coord], color)

    def force_frame(self):
        for coord in self.curr_frame:
            self.curr_frame[coord] = (-1,-1,-1)  # Force update

    def init_frames(self):
        for coord in self.cellmap:
            self.curr_frame[coord] = (0,0,0)
            self.next_frame[coord] = (0,0,0)

    def add_strips(self):
        cellmap = defaultdict(list)
        for strip in range(NUM_BIG_SPHERE):
            cellmap = self.add_strip(cellmap, strip)
        return cellmap

    def add_strip(self, cellmap, strip):
        """
        Stuff the cellmap with a Sphere strip, going row by column
        """
        for i in range(NUM_PIXELS):
            face = i // NUM_PANELS
            panel = i % NUM_PANELS
            fix = i #get_light_from_coord((face,panel))
            cellmap[(strip, face, panel)].append((strip, fix))
        
        return cellmap

    def get_light_from_coord(self, coord):
        """
        Algorithm to convert (face,panel) coordinate into an LED number
        Mirrors GetLightFromCoord in the Processing Sphere simulator
        cleaner code would not reproduce the algorithm twice
        """
        (f,p) = coord

        return (f * NUM_PANELS) + p


    
##
## sphere cell primitives
##

def is_on_board(coord):
    (f,p) = coord
    return (p < 6 and p > -6)

def neighbors(coord):
    "Returns a list of the four neighboring tuples at a given coordinate"
    (x,y) = coord

    neighbors = [ (0, 1), (1, -1), (0, -1), (-1, 1) ]

    return [get_coord((x+dx, y+dy)) for (dx,dy) in neighbors]

def sphere_in_line(coord, direction, panel=0):
    """
    Returns the coord and all pixels in the direction
    along the panel
    """
    return [sphere_in_direction(coord, direction, x) for x in range(panel)]

def sphere_in_direction(coord, direction, panel=1):
    """
    Returns the coordinates of the cell in a direction from a given cell.
    Direction is indicated by an integer
    There are 4 directions along curved axes
    """
    for i in range(panel):
        coord = sphere_nextdoor(coord, direction)
    return coord

def sphere_nextdoor(coord, direction):
    """
    Returns the coordinates of the sphere cell in the given direction
    Coordinates determined from a lookup table
    """
    _lookup = [ (0, 1), (-1, -1), (0, -1), (1, 1) ]

    (x,y) = coord
    (dx,dy) = _lookup[(direction % 4)]
    
    return (x+dx, y+dy)

def get_rand_neighbor(coord):
    """
    Returns a random neighbors
    Neighbor may not be in bounds
    """
    return choice(neighbors(coord))
