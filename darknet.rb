#!/usr/bin/ruby1.8

#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
# Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
#
# Everyone is permitted to copy and distribute verbatim or modified
# copies of this license document, and changing it is allowed as long
# as the name is changed.
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.


# TODO List
# Improve GUI
# Implement Swapping algorithm
# Implement Object Search alhorithm
# Make it all work together


require 'Qt'


class Node

	attr_reader :id, :friends
	attr_accessor :x, :y

	def initialize id, position = nil
		@id = id

		if position.nil?
			@x, @y = rand, rand
		else
			@x, @y = position
		end

		@friends = Array.new
	end

	# Euclidean distance
	def distance a
		return Math.sqrt((self.x-a.x)**2 + (self.y-a.y)**2)
	end

	def chooseSmallWorldFriends nodes, nbFriends, nearbyFriendFactor

		nbFriends = [nodes.size - 1 - @friends.size, nbFriends].min
		nodes = nodes - [self] - @friends

		if nearbyFriendFactor == 0
			nbFriends.times do
				node = nodes.choice
				
				self.addFriend node
				node.addFriend self
				nodes.delete node
			end
		else
			# TODO rework that to be more accurate
			nodes = nodes.sort_by{|n| self.distance n}
			
			nbFriends.times do				
				node = nodes[((1.0-(1.0-rand()**(nearbyFriendFactor*2.0))**(1.0/(nearbyFriendFactor*2.0)))*nodes.size).floor]

				self.addFriend node
				node.addFriend self
				nodes.delete node
			end
		end

	end

	def addFriend node
		@friends.push node
	end

	def removeAllFriends
		@friends= Array.new
	end

	# Returns the route to dest without passing through the excludedNodes. If it doesn't exist, returns nil
	def greedyRoute dest, excludedNodes = []

		if @friends.include? dest
			return [[self, dest]]
		end

		# get friends ordered by proximity with destination
		bestFriends = (@friends - excludedNodes - [self]).sort_by{|n| dest.distance n}
		
		route = nil
		friend = nil

		while route.nil? and not bestFriends.empty?
			friend = bestFriends.shift
			route = friend.greedyRoute dest, excludedNodes.push(self)
		end

		if route
			return route.push [self, friend]
		else
			return nil
		end
	end

	def randomRoute dest, excludedNodes = []

		if @friends.include? dest
			return [[self, dest]]
		end

		# get friends ordered randomly
		bestFriends = (@friends - excludedNodes - [self]).shuffle
		
		route = nil
		friend = nil

		while route.nil? and not bestFriends.empty?
			friend = bestFriends.shift
			route = friend.randomRoute dest, excludedNodes.push(self)
		end

		if route
			return route.push([self, friend])
		else
			return nil
		end
		
	end
end


class Darknet

	attr_reader :nodes, :randomRoute, :greedyRoute, :nearbyFriendFactor, :nbFriends

	def initialize

		# The list of nodes
		@nodes = Array.new

		# The last routes that have been computed
		@greedyRoute = Array.new
		@randomRoute = Array.new

		# The nearby friend factor determine how nodes choose their friends.
		# The bigger the factor is, the more the proximity will be an important factor.
		# Example:
		# 0 ->		the odds of being friend with a node is the same for every node
		# 1 ->		the odds of being friend with a node is inversely proportional to the distance between them
		# 2..inf ->	the odds of being friend with a node is based on a polynomial formula of degree n
		# the exact formula is based on the circle formula (which is x² + y² = 1) :
		# probabilyOfBeingFriend = 1 - (1 - (distance - 1) ** n) ** (1/n)
		@nearbyFriendFactor = 2

		# The number of friends of each nodes
		@nbFriends = 10

	end # def initialize


	# Remove friends from nodes with too many friends without leaving nodes with too few friends
	def cleanNetwork
		# TODO implement
	end #def cleanNetwork

	def addNode
		newNode = Node.new @nodes.size
		@nodes.push newNode
	    		
		newNode.chooseSmallWorldFriends @nodes, [@nodes.size-1, @nbFriends].min, @nearbyFriendFactor

		cleanNetwork
	end # def addNode

	def recomputeFriends
		@greedyRoute = Array.new
		@randomRoute = Array.new

		@nodes.each do |node|
			node.removeAllFriends
		end

		@nodes.each do |node|
			node.chooseSmallWorldFriends @nodes, [@nodes.size-1, @nbFriends].min, @nearbyFriendFactor
		end

		cleanNetwork
	end

	def recomputePositions
		@nodes.each do |node|
			node.x, node.y = rand, rand
		end
	end


	def changeNearbyFriendFactor r
		@nearbyFriendFactor = r
		recomputeFriends
	end # def changenearbyFriendFactor


	def changeNbFriends n
		@nbFriends = n
		recomputeFriends
	end # def changeNbFriends


	def computeRoutes
		if @nodes.size < 2
			return
		end

		nodeA = @nodes.choice
		nodeB = @nodes.choice

		@greedyRoute = nodeA.greedyRoute nodeB
		@randomRoute = nodeA.randomRoute nodeB
	end

end

class MainWindow < Qt::Widget

 	signals 'valueChanged(int)'
  	slots 'changeNearbyFriendFactor(int)'
  	slots 'changeNbFriends(int)'

    def initialize
        super

        @darknet = Darknet.new

        resize 1024, 640
        setWindowTitle "Darknet Demo"

        @spinBoxNFF = Qt::SpinBox.new
        @spinBoxNFF.setMinimum 0
        @spinBoxNFF.setValue @darknet.nearbyFriendFactor
        connect(@spinBoxNFF, SIGNAL('valueChanged(int)'), self, SLOT('changeNearbyFriendFactor(int)'))

		@spinBoxNF = Qt::SpinBox.new
        @spinBoxNF.setMinimum 0
        @spinBoxNF.setValue @darknet.nbFriends
        connect(@spinBoxNF, SIGNAL('valueChanged(int)'), self, SLOT('changeNbFriends(int)'))

        @networkWidget = NetworkWidget.new
        @networkWidget.darknet = @darknet

        menu = Qt::Widget.new
        menuL = Qt::FormLayout.new
		menuL.addRow Qt::Label.new("Nearby Friend Factor"), @spinBoxNFF
        menuL.addRow Qt::Label.new("Number of friends"), @spinBoxNF
        menu.setLayout menuL

        layout = Qt::VBoxLayout.new
        layout.addWidget menu
        layout.addWidget @networkWidget
        setLayout layout

        @networkWidget.setFocusPolicy Qt::StrongFocus
        menu.setFixedHeight 60

        show
    end

    def changeNearbyFriendFactor r
    	@darknet.changeNearbyFriendFactor r
    	self.repaint
    end

    def changeNbFriends n
    	@darknet.changeNbFriends n
    	self.repaint
    end

    def keyPressEvent e
    	case e.key

	    	when Qt::Key_N
	    		@darknet.addNode
	    		self.repaint

		    when Qt::Key_Escape
		    	$qApp.quit

		    when Qt::Key_F
		    	@darknet.recomputeFriends
		    	self.repaint

		    when Qt::Key_P
		    	@darknet.recomputePositions
		    	self.repaint

		    when Qt::Key_R
		    	@darknet.computeRoutes
		    	self.repaint

		    when Qt::Key_D
		    	@darknet = Darknet.new
		    	@networkWidget.darknet = @darknet
		    	@darknet.changeNearbyFriendFactor @spinBoxNFF.value
		    	@darknet.changeNbFriends @spinBoxNF.value
		    	self.repaint 

	    end
    end

end

class NetworkWidget < Qt::Widget
	
	attr_accessor :darknet

	def initialize
		super
	end

	def paintEvent event

        painter = Qt::Painter.new self
        painter.setRenderHint Qt::Painter::Antialiasing

		h, w = self.size().height(), self.size().width()

		nodeSize = 10

		# Paint friends links

		painter.setPen Qt::Color::new 100, 100, 255

		@darknet.nodes.each do |node|
			node.friends.each do |friend|
 				painter.drawLine node.x*w, node.y*h, friend.x*w, friend.y*h
 			end
 		end

 		# Paint random route

 
		pen = Qt::Pen.new
 		pen.setColor Qt::Color::new 0, 255, 0
 		pen.setWidth 4
 		painter.setPen pen 

		@darknet.randomRoute.each do |link|
 			painter.drawLine link[0].x*w, link[0].y*h, link[1].x*w, link[1].y*h
 		end

 		# Paint greedy route

 		pen = Qt::Pen.new
 		pen.setColor Qt::Color::new 255, 0, 0
 		pen.setWidth 2
 		painter.setPen pen 

		@darknet.greedyRoute.each do |link|
 			painter.drawLine link[0].x*w, link[0].y*h, link[1].x*w, link[1].y*h
 		end

 		# Paint nodes

		painter.setPen Qt::Color::new 255, 255, 255
		painter.setBrush Qt::Brush.new Qt::Color::new 255, 100, 100

		@darknet.nodes.each do |node|
			 painter.drawEllipse  node.x*w-nodeSize/2, node.y*h-nodeSize/2, nodeSize, nodeSize
		end

		# Paint first and last node of the routes
		if not @darknet.greedyRoute.empty?
			painter.setPen Qt::Color::new 255, 255, 255
			painter.setBrush Qt::Brush.new Qt::Color::new 0, 255, 0

			node = @darknet.greedyRoute.last[0]
			painter.drawEllipse  node.x*w-nodeSize, node.y*h-nodeSize, nodeSize*2, nodeSize*2

			painter.setPen Qt::Color::new 255, 255, 255
			painter.setBrush Qt::Brush.new Qt::Color::new 255, 0, 0

			node = @darknet.greedyRoute.first[1]
			painter.drawEllipse  node.x*w-nodeSize, node.y*h-nodeSize, nodeSize*2, nodeSize*2		
		end

        painter.end
    end

end


app = Qt::Application.new ARGV
MainWindow.new
app.exec
