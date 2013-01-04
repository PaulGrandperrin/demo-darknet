#!/usr/bin/ruby1.8
# -*- coding: utf-8 -*-

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
# Implement Object Search alhorithm
# Make it all work together
# Threading/Socket	Romain
# File management
#	-HTL 			Paul
# 	-lookup
#   -insertion
#   -cache management
# Cryptage			Romain
#   -file
#   -connections

require 'Qt'

# A class that represents the hash of a file
class HashFile

	attr_accessor :x, :y 
	
	def initialize xx, yy
		@x = xx
		@y = yy
	end
	
	# Euclidean distance
	def distance a
		return Math.sqrt((self.x-a.x)**2 + (self.y-a.y)**2)
	end
end #class HashFile

class File

   attr_reader :id, :contents
   attr_accessor :x, :y

	def initialize id, position = nil
		@id = id
		@contents = "Salaaam"  # This content CANNOT be modified

		if position.nil?
			@x, @y = rand, rand
		else
			@x, @y = position
		end
	end 
	
	def getHash
		return HashFile.new(@x, @y)
	end	

	# has the same id
	def equal id
		if id == @id
			return true
		else
			return false
		end
	end
	
	# has the same hash
	def equalHash hash
		if hash.x == @x and hash.y == @y 
			return true
		else
			return false
		end
	end
	
	# Euclidean distance
	def distance a
		return Math.sqrt((self.x-a.x)**2 + (self.y-a.y)**2)
	end
end #class File


class Node

	attr_reader :id, :friends, :files, :nbFiles, :HtlFile, :queryId, :queryCache
	attr_accessor :x, :y

	def initialize id, position = nil
		# Constants
	    @nbFiles = 2
		@HtlFile = 2
		@queryId = 1
		@id = id

		if position.nil?
			@x, @y = rand, rand
		else
			@x, @y = position
		end

		@friends = Array.new
		@queryCache = Hash.new
		
        # By default, each Node contains some files 
        @files = Array.new
        
        @nbFiles.times do |j|
           idFile = 1000 + @id*100 + j + 1
           newFile = File.new idFile
           @files.push newFile
        end
	end

    # Friends Block
	def addFriend node
		@friends.push node
	end

	def removeAllFriends
		@friends= Array.new
	end
		
	def unlink
		@friends.each do |friend|
			friend.friends.delete self
		end
	end

    # Files Block
	def addFile file
		@files.push file
	end

	def removeAllFiles
		@files= Array.new
	end
	
	# Look for a file by its id
	def findFile id
	
		file = nil
		@files.each do |f|
			if f.equal id
				file = f
			end
		end
		return file
	end
	
	# Look for a file by its hash
	def hasFile hash	
		file = nil

		@files.each do |f|
			if f.equalHash hash
				file = f
			end
		end
		return file
	end

	# Query Block       
	def getQueryId
		id = @queryId
		@queryId += 1
		return id
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

	# start a query to search a file, and add it if does exist
	def searchFileInit hash
		
		:route
		file = self.hasFile hash
		if not file.nil? 
			# The node has already the file
		else
			queryId = self.getQueryId
			bestFriends = (@friends - [self]).sort_by{|n| hash.distance n}
			@queryCache[queryId] = self
			
			friend = nil
			while file.nil? and not bestFriends.empty?
				friend = bestFriends.shift
				friend.queryCache[queryId] = self
				file = friend.searchFile(hash, queryId) {|r| @route = r}[0]
			end 
			
			# if the file was found
			if not file.nil?			
				self.addFile file
				return @route.push([self, friend])
			else
				return nil
			end
		end 
	end
	
 	# Search the file. If it doesn't exist, returns nil
	def searchFile hash, qId, excludedNodes = []
		
		@queryId = qId + 1		
		file = self.hasFile hash
		
		# The node has the file
		if not file.nil? 
			yield []
			return file, @HtlFile
		end

		# get friends ordered by proximity with destination
		bestFriends = (@friends - excludedNodes - [self]).sort_by{|n| hash.distance n}

		friend = nil
		while file.nil? and not bestFriends.empty?
			friend = bestFriends.shift
			friend.queryCache[queryId] = self
			file, htl = friend.searchFile(hash, qId, excludedNodes.push(self)){|route| yield route.push([self, friend])} 
		end

		# The file was found and we still can save it (htl > 0)
		if not file.nil? and htl > 0
			self.addFile file
			return file, htl-1
		else
			return file, 0
		end
	end
        
    # insert a file in the network
    def insertFile file,  excludedNodes = [], htl = @HtlFile 	

		bestFriends = (@friends - excludedNodes - [self]).sort_by{|n| file.distance n}
		friend = bestFriends.shift
		if friend.nil?
			return false
		end
						
		if htl != @HtlFile
			# if the exists already, cancel the insert of the file
	    	if @files.include? file
				return false
			end
	    	
			if htl == 0
				return true
			end

			if friend.insertFile(file, excludedNodes.push(self), htl-1)
				friend.addFile file
				return true
			else
				return false
			end

		else # the initiater of the query
			friend.insertFile(file, excludedNodes.push(self), htl-1)
	    end         	
    end
    
    # Insert all files in the network
    def insertAllFiles
    	@files.each do |file|
    		insertFile file
    	end
    end
	
    # Utility functions
    #1- Swap
	def swap n
		temp = @x
		@x = n.x
		n.x = temp
		
		temp = @y
		@y = n.y
		n.y = temp
	end
	
    #2- This is our secret formulas ;)
	def logSum n
		sum = 0.0
		@friends.each do |friend|
			if friend.x == n.x and friend.y == n.y # if the node n is one of our friend
				sum += Math.log((n.x - @x).abs + (n.y - @y).abs)
			else
				sum += Math.log((n.x - friend.x).abs + (n.y - friend.y).abs)
			end
		end
		return sum
	end
	
	#3- Euclidean distance
	def distance a
		return Math.sqrt((self.x-a.x)**2 + (self.y-a.y)**2)
	end
end #class Node

class Darknet

	attr_reader :nodes, :randomRoute, :greedyRoute, :firstNode, :lastNode, :nearbyFriendFactor, :nbFriends, :stats, :nodeInit	
	attr_reader :nodeInit, :hash, :fileRoute

	def initialize
		# The list of nodes
		@nodes = Array.new

		# The last routes that have been computed
		@greedyRoute = Array.new
		@randomRoute = Array.new
		@fileRoute = Array.new
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

	# Insert all the files of all the nodes	
	def insertAllFiles
		@nodes.each do |n| n.insertAllFiles end
	end
	
	# This function a bit cheating. We assume that the hash of a file could be computed.
	def idFileToHash id
		idNode = (id - 1000)/100
		
		node = @nodes[idNode]
		file = node.findFile id
		
		return file.getHash
	end
	
	def changeNodeInit s_id
	    	id = Integer(s_id)
    		@nodeInit = nodes[id]
		if @nodeInit and @hash 
			@fileRoute = @nodeInit.searchFileInit @hash	
		end
	end
	
	def changeHash idF
		@hash = idFileToHash Integer(idF) 
		if @nodeInit and @hash 
			@fileRoute = @nodeInit.searchFileInit @hash
		end
	end
	
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

	def changeNbNode n
		if n > @nodes.size
			(n - @nodes.size).times do
				self.addNode
			end
			
			if n != 0
				insertAllFiles
			end

		elsif n < @nodes.size
			@nodes.pop(@nodes.size - n).each{|node| node.unlink}
			
			# in order to avoid having routes passing by ghost-nodes
			@firstNode = @nodes.choice
			@lastNode = @nodes.choice
			@greedyRoute = @firstNode.greedyRoute(@lastNode){}
			@randomRoute = @firstNode.randomRoute(@lastNode){}
			
		end
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

	def swapRandomNodes
		(100*@nodes.size).times do
			nodeA, nodeB = @nodes.choice, @nodes.choice
			prob = Math.exp(-2 * (nodeA.logSum(nodeB) + nodeB.logSum(nodeA) - nodeA.logSum(nodeA) - nodeB.logSum(nodeB)))

			if rand < prob
			 	nodeA.swap(nodeB)
			end
		end

		if @nodes.size > 2
			@greedyRoute = @firstNode.greedyRoute(@lastNode){}
			@randomRoute = @firstNode.randomRoute(@lastNode){}
		end
	end
end #class Darknet

class MainWindow < Qt::Widget

 	signals 'valueChanged(int)'
 	signals :clicked
  	slots 'changeNearbyFriendFactor(int)'
  	slots 'changeNbFriends(int)'
  	slots 'changeNbNode(int)'
  	slots :recomputeFriendLinks
  	slots :randomizePositions
  	slots :randomRoute
  	slots :swap
  	slots :reset
  	slots 'changeNodeInit(QString)'
  	slots 'changeFile(QString)'

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

        @spinBoxNN = Qt::SpinBox.new
        @spinBoxNN.setMinimum 0
        @spinBoxNN.setMaximum 999
        @spinBoxNN.setValue @darknet.nodes.size
        connect(@spinBoxNN, SIGNAL('valueChanged(int)'), self, SLOT('changeNbNode(int)'))

        @recomputeFriendLinks = Qt::PushButton.new "Recompute friend links"
        @recomputeFriendLinks.connect(:clicked, self, :recomputeFriendLinks)

        @randomizePositions = Qt::PushButton.new "Randomize nodes positions"
        @randomizePositions.connect(:clicked, self, :randomizePositions)

        @randomRoute = Qt::PushButton.new "Compute routes"
		@randomRoute.connect(:clicked, self, :randomRoute)

        @swap = Qt::PushButton.new "Swapping algorithm (100 times)"
        @swap.connect(:clicked, self, :swap)

        @reset = Qt::PushButton.new "Reset"
        @reset.connect(:clicked, self, :reset)
        
        @comboNode = Qt::ComboBox.new self
        connect @comboNode, SIGNAL("activated(QString)"), self, SLOT("changeNodeInit(QString)")

        @comboFile = Qt::ComboBox.new self
        connect @comboFile, SIGNAL("activated(QString)"), self, SLOT("changeFile(QString)")

        @menu = Qt::Widget.new
        menuL = Qt::FormLayout.new
		menuL.addRow Qt::Label.new("Nearby Friend Factor"), @spinBoxNFF
        menuL.addRow Qt::Label.new("Number of friends"), @spinBoxNF
        menuL.addRow Qt::Label.new("Number of nodes"), @spinBoxNN
        menuL.addRow Qt::Label.new("The Node"), @comboNode
        menuL.addRow Qt::Label.new("looks for the file"), @comboFile
        menuL.addRow @recomputeFriendLinks
        menuL.addRow @randomizePositions
        menuL.addRow @randomRoute
        menuL.addRow @swap
        menuL.addRow @reset
        @menu.setLayout menuL

        @networkWidget = NetworkWidget.new
        @networkWidget.darknet = @darknet

        @stats = StatsWidget.new
		@stats.darknet = @darknet

        layout = Qt::HBoxLayout.new
        layout.addWidget @menu
        layout.addWidget @networkWidget
        layout.addWidget @stats
        setLayout layout

        @networkWidget.setFocusPolicy Qt::StrongFocus
        @menu.setFixedWidth 200
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

    def changeNbNode n
    	@darknet.changeNbNode n
    	@darknet.computeStats
    	
    	@comboNode.clear
        fillComboNode
        
        @comboFile.clear
        fillComboFile
        
    	self.update
    end

    def changeNodeInit id
    	@darknet.changeNodeInit id
    	self.update
    end
    
    def changeFile idF
    	@darknet.changeHash idF
    	self.update	
    end
    
    def recomputeFriendLinks
    	@darknet.recomputeFriends
		self.update
    end

    def randomizePositions
    	@darknet.recomputePositions
    	@darknet.computeStats
    	self.update
    end

    def randomRoute
    	@darknet.computeRoutes
		self.update
    end

    def swap
    	@darknet.swapRandomNodes
		@darknet.computeStats
    	self.update	
    end

    def reset
    	@darknet = Darknet.new
    	@networkWidget.darknet = @darknet
    	@stats.darknet = @darknet
    	@darknet.changeNearbyFriendFactor @spinBoxNFF.value
    	@darknet.changeNbFriends @spinBoxNF.value
        @darknet.changeNbNode @spinBoxNN.value
        @darknet.insertAllFiles
    	@darknet.computeStats
    	self.update
    end
	
    def fillComboNode
    	@darknet.nodes.each do |n|
    		@comboNode.addItem n.id.to_s
    	end
    	changeNodeInit "0"
    end

    # add only the nodes' files    
    def fillComboFile
    	@darknet.nodes.each do |n|
    		n.files.each do |f|
    			if (f.id - 1000 - (n.id)*100 )/100 == 0
	    			@comboFile.addItem f.id.to_s
    			end
    		end 
		end
    end
    
    def keyPressEvent e
    	case e.key
	        when Qt::Key_Escape
		    	$qApp.quit

	    	when Qt::Key_N
	            @darknet.addNode
	    	    @darknet.computeStats
	    	    self.update

			when Qt::Key_F
				recomputeFriendLinks

            when Qt::Key_P
				randomizePositions

			when Qt::Key_R
				@darknet.computeRoutes

	        when Qt::Key_D
				reset

	        when Qt::Key_S
				swap	
		end
    end
end # class MainWindow
 
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
		
		# Paint the node that looks for a file
		if @darknet.nodeInit
			painter.setPen Qt::Color::new 255, 255, 255
			painter.setBrush Qt::Brush.new Qt::Color::new 0, 0, 0

			painter.drawEllipse @darknet.nodeInit.x*w-nodeSize, @darknet.nodeInit.y*h-nodeSize, nodeSize*2, nodeSize*2				
		end

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
 		
 		# Paint file route
 		if @darknet.fileRoute
			pen = Qt::Pen.new
	 		pen.setColor Qt::Color::new 255, 255, 0
	 		pen.setWidth 2
	 		painter.setPen pen 

			@darknet.fileRoute.each do |link|
	 			painter.drawLine link[0].x*w, link[0].y*h, link[1].x*w, link[1].y*h
	 		end
 		end
        painter.end

    end # def paintEvent
end # class NetworkWidget

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

	end # paintEvent
end # class statsWidget

app = Qt::Application.new ARGV
MainWindow.new
app.exec
