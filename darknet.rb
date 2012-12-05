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
			nbFriends.times do
				dist = (1.0-(1.0-rand()**(nearbyFriendFactor*2.0))**(1.0/(nearbyFriendFactor*2.0))) * Math.sqrt(2)
				node = nodes.min_by{|node| (self.distance(node) - dist).abs}

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
		
		route = []
		friend = nil

		while route.empty? and not bestFriends.empty?
			friend = bestFriends.shift
			yield [[self, friend]]
			route = friend.greedyRoute(dest, excludedNodes.push(self)){|route| yield route.push [self, friend]}
		end

		if not route.empty?
			return route.push [self, friend]
		else
			return []
		end

	end

	def randomRoute dest, excludedNodes = []

		if @friends.include? dest
			return [[self, dest]]
		end

		# get friends ordered randomly
		bestFriends = (@friends - excludedNodes - [self]).shuffle
		
		route = []
		friend = nil

		while route.empty? and not bestFriends.empty?
			friend = bestFriends.shift
			yield [[self, friend]]
			route = friend.randomRoute(dest, excludedNodes.push(self)){|route| yield route.push [self, friend]}
		end

		if not route.empty?
			return route.push([self, friend])
		else
			return []
		end
		
	end
end


class Darknet

	attr_reader :nodes, :randomRoute, :greedyRoute, :firstNode, :lastNode, :nearbyFriendFactor, :nbFriends, :stats

	def initialize

		# The list of nodes
		@nodes = Array.new

		# The last routes that have been computed
		@greedyRoute = Array.new
		@randomRoute = Array.new
		@firstNode, @lastNode = nil, nil

		# The nearby friend factor determine how nodes choose their friends.
		# The bigger the factor is, the more the proximity will be an important factor.
		# Example:
		# 0 ->		the odds of being friend with a node is the same for every node
		# 1 ->		the odds of being friend with a node is inversely proportional to the distance between them
		# 2..inf ->	the odds of being friend with a node is based on a polynomial formula of degree n
		# the exact formula is based on the circle formula (which is x² + y² = 1) :
		# probabilyOfBeingFriend = 1 - (1 - (distance - 1) ** n) ** (1/n)
		@nearbyFriendFactor = 3

		# The number of friends of each nodes
		@nbFriends = 5

		# Number of values per bar
		@nbValuesPerBar = 10
		@stats = Array.new

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

		if @nodes.size == 2
			@firstNode = @nodes[0]
			@lastNode = @nodes[1]
		elsif @nodes.size > 2
			@greedyRoute = @firstNode.greedyRoute(@lastNode){}
			@randomRoute = @firstNode.randomRoute(@lastNode){}
		end

		
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

		if @nodes.size > 2
			@greedyRoute = @firstNode.greedyRoute(@lastNode){}
			@randomRoute = @firstNode.randomRoute(@lastNode){}	
		end
	end

	def recomputePositions
		@nodes.each do |node|
			node.x, node.y = rand, rand
		end

		if @nodes.size > 2
			@greedyRoute = @firstNode.greedyRoute(@lastNode){}
			@randomRoute = @firstNode.randomRoute(@lastNode){}
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

		@firstNode = @nodes.choice
		@lastNode = @nodes.choice

		@randomRoute = @firstNode.randomRoute(@lastNode){}
		@greedyRoute = @firstNode.greedyRoute(@lastNode){}
	end

	def computeStats
		distances = @nodes.map{|node| node.friends.map{|friend| [node,friend]}}.flatten(1).select{|route| route[0].id < route[1].id}.map{|route| route[0].distance route[1]}

		@stats = Array.new
		nbBars = (distances.size / @nbValuesPerBar).to_i
		nbBars.times do |barNumber|
			range = Math.sqrt(2) / nbBars * barNumber, Math.sqrt(2) / nbBars * (barNumber + 1)

			@stats[barNumber] = distances.count{|distance| distance > range[0] and distance < range[1]}
		end

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

        @stats = StatsWidget.new
		@stats.darknet = @darknet        

        @menu = Qt::Widget.new
        menuL = Qt::FormLayout.new
		menuL.addRow Qt::Label.new("Nearby Friend Factor"), @spinBoxNFF
        menuL.addRow Qt::Label.new("Number of friends"), @spinBoxNF
        @menu.setLayout menuL

        @graphics = Qt::Widget.new
        graphicsL = Qt::HBoxLayout.new
        graphicsL.addWidget @networkWidget
        graphicsL.addWidget @stats
        @graphics.setLayout graphicsL

        layout = Qt::VBoxLayout.new
        layout.addWidget @menu
        layout.addWidget @graphics
        setLayout layout

        @networkWidget.setFocusPolicy Qt::StrongFocus
        @menu.setFixedHeight 60
        @stats.setFixedWidth 150

        show
    end

    def changeNearbyFriendFactor r
    	@darknet.changeNearbyFriendFactor r
    	@darknet.computeStats
    	self.update
    end

    def changeNbFriends n
    	@darknet.changeNbFriends n
    	@darknet.computeStats
    	self.update
    end

    def keyPressEvent e
    	case e.key

	    	when Qt::Key_N
	    		@darknet.addNode
	    		@darknet.computeStats
	    		self.update

		    when Qt::Key_Escape
		    	$qApp.quit

		    when Qt::Key_F
		    	@darknet.recomputeFriends
		    	@darknet.computeStats
		    	self.update

		    when Qt::Key_P
		    	@darknet.recomputePositions
		    	@darknet.computeStats
		    	self.update

		    when Qt::Key_R
		    	@darknet.computeRoutes
		    	self.update

		    when Qt::Key_D
		    	@darknet = Darknet.new
		    	@networkWidget.darknet = @darknet
		    	@stats.darknet = @darknet
		    	@darknet.changeNearbyFriendFactor @spinBoxNFF.value
		    	@darknet.changeNbFriends @spinBoxNF.value
		    	@darknet.computeStats
		    	self.update

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
		if @darknet.firstNode and @darknet.lastNode
			painter.setPen Qt::Color::new 255, 255, 255
			painter.setBrush Qt::Brush.new Qt::Color::new 0, 127, 0

			painter.drawEllipse @darknet.firstNode.x*w-nodeSize, @darknet.firstNode.y*h-nodeSize, nodeSize*2, nodeSize*2

			painter.setPen Qt::Color::new 255, 255, 255
			painter.setBrush Qt::Brush.new Qt::Color::new 200, 0, 0

			painter.drawEllipse @darknet.lastNode.x*w-nodeSize, @darknet.lastNode.y*h-nodeSize, nodeSize*2, nodeSize*2		
		end

        painter.end
    end

end

class StatsWidget < Qt::Widget
	
	attr_accessor :darknet

	def initialize
		super
	end

	def paintEvent event

		if @darknet.stats.empty?
			return
		end

		painter = Qt::Painter.new self

		h, w = self.size().height(), self.size().width()


		max = @darknet.stats.max

		nbBars = darknet.stats.size
		nbBars.times do |barNumber|
			greyShade = (50 + 150.to_f / nbBars * barNumber).to_i
			painter.setPen Qt::Color::new greyShade, greyShade, greyShade
			painter.setBrush Qt::Brush.new Qt::Color::new greyShade, greyShade, greyShade
			painter.drawRect 0,h.to_f/nbBars*barNumber,@darknet.stats[barNumber].to_f / max * w, h.to_f/nbBars
		end

		painter.end

	end
end


app = Qt::Application.new ARGV
MainWindow.new
app.exec
