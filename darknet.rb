#!/usr/bin/ruby1.8

require 'Qt'


class Position

	attr_reader :x, :y

	def initialize x = nil, y= nil
		@x = rand() unless x
		@y = rand() unless y
	end

	# Euclidean distance
	def distance a
		return Math.sqrt((self.x-a.x)**2 + (self.y-a.y)**2)
	end
end


class Node

	attr_reader :id
	attr_accessor :pos


	def initialize id, darknet
		@darknet = darknet
		@id = id
		@pos = Position.new
	end

	def distance a
		return self.pos.distance a.pos
	end

	def links
		return @darknet.links.select{|l| l[0] == self.id or l[1] == self.id}
	end

	def friends
		return self.links.map{|l| @darknet.nodes[l[0] == self.id ? l[1] : l[0] ]}
	end

	def greedyRoute dest, excludedNodes = []

		if friends.include? dest
			return true, [[self.id,dest.id]]
		end


		# get friends ordered by proximity with destination
		bestFriends = (friends - excludedNodes).sort_by{|node| dest.distance(node)}
		
		valid = false
		route = nil

		while not valid and not bestFriends.empty?
			friend=bestFriends.shift
			valid, route = friend.greedyRoute dest, excludedNodes.push(self)
		end

		if valid
			return true, route.push([self.id, route.last[0]])
		else
			return false, nil
		end
	end

	def randomRoute dest, excludedNodes = []

		if friends.include? dest
			return true, [[self.id,dest.id]]
		end


		# get friends ordered by proximity with destination
		bestFriends = (friends - excludedNodes).shuffle
		
		valid = false
		route = nil

		while not valid and not bestFriends.empty?
			friend=bestFriends.shift
			valid, route = friend.randomRoute dest, excludedNodes.push(self)
		end

		if valid
			return true, route.push([self.id, route.last[0]])
		else
			return false, nil
		end
	end
end


class Darknet

	attr_reader :nodes, :links, :randomRoute, :greedyRoute, :nearbyFriendRatio, :nbFriends

	def initialize

		# The list of nodes
		@nodes = Array.new

		# The list of links between nodes
		@links = Array.new

		# The last routes being computed
		@greedyRoute = Array.new
		@randomRoute = Array.new

		# The nearby friend ratio determine how nodes choose their friends.
		# The bigger the ratio is, the more the proximity will be an important factor.
		# Example:
		# 0 ->		the odds of being friend with a node is the same for every node
		# 1 ->		the odds of being friend with a node is inversely proportional to the distance between them
		# 2..inf ->	the odds of being friend with a node is based on a polynomial formula of degree n
		# the exact formula is based on the circle formula (which is x² + y² = 1) :
		# probabilyOfBeingFriend = 1 - (1 - (distance - 1) ** n) ** (1/n)
		@nearbyFriendRatio=5

		# The number of friends of each nodes
		@nbFriends = 4

	end # def initialize


	# Remove links from nodes with too many friends without leaving nodes with too few friends
	def cleanNetwork
		# TODO 
	end #def cleanNetwork

	def addFriendToNode node
		chanceFactorCounter = @nodes.size
		chanceFactor = 5
		nodesToTest = []
		while true
			if chanceFactorCounter == 0
				chanceFactorCounter = @nodes.size
				chanceFactor *= 2
			end

			n=@nodes[rand(@nodes.size)]

			if @links.include? [node.id, n.id] or @links.include? [n.id, node.id] or n == node
				next
			end

			# We normalize our distance by the maximum possible distance in the plane
			dist = node.distance(n) / Math.sqrt(2)
			
			# Our friendyness formula
			if @nearbyFriendRatio == 0
				p = 1
			else
				p = 1.0 - ( 1.0 - (dist - 1.0) ** (@nearbyFriendRatio*2)) ** (1.0 / (@nearbyFriendRatio*2))
				p /= @nodes.size
				p *= chanceFactor
			end

			if rand() < p
				@links.push [node.id, n.id]
				break
			end
			chanceFactorCounter -= 1
		end
	end

	def addNode
		newNode = Node.new @nodes.size, self
		@nodes.push newNode
	    		
		nbFriends = [@nodes.size-1, @nbFriends].min
		nbFriends.times{ addFriendToNode newNode }


		cleanNetwork

	end # def addNode

	def recomputeFriends
		@links = Array.new
		@greedyRoute = Array.new
		@randomRoute = Array.new

		@nodes.each do |node|
			nbFriends = [@nodes.size-1, @nbFriends].min
			(nbFriends-node.links.size).times{ addFriendToNode node }		
		end

		cleanNetwork
	end

	def recomputePositions
		@nodes.each do |node|
			node.pos=Position.new
		end
	end


	def changeNearbyFriendRatio r
		@nearbyFriendRatio = r
		recomputeFriends
	end # def changeNearbyFriendRatio


	def changeNbFriends n
		@nbFriends = n
		recomputeFriends
	end # def changeNbFriends


	def computeRoutes
		nodeA = @nodes[rand(@nodes.size)]
		nodeB = @nodes[rand(@nodes.size)]

		valid,@greedyRoute = nodeA.greedyRoute nodeB
		valid,@randomRoute = nodeA.randomRoute nodeB
	end

end

class MainWindow < Qt::Widget

 	signals 'valueChanged(int)'
  	slots 'changeNearbyFriendRatio(int)'
  	slots 'changeNbFriends(int)'

    def initialize
        super

        @darknet = Darknet.new

        resize 800, 480
        setWindowTitle "Darknet Demo"

        @spinBoxNFR = Qt::SpinBox.new
        @spinBoxNFR.setMinimum 0
        @spinBoxNFR.setValue @darknet.nearbyFriendRatio
        connect(@spinBoxNFR, SIGNAL('valueChanged(int)'), self, SLOT('changeNearbyFriendRatio(int)'))

		@spinBoxNBF = Qt::SpinBox.new
        @spinBoxNBF.setMinimum 0
        @spinBoxNBF.setValue @darknet.nbFriends
        connect(@spinBoxNBF, SIGNAL('valueChanged(int)'), self, SLOT('changeNbFriends(int)'))

        @networkWidget = NetworkWidget.new
        @networkWidget.darknet = @darknet

        menu = Qt::Widget.new
        menuL = Qt::FormLayout.new
		menuL.addRow Qt::Label.new("Nearby Friend Ratio"), @spinBoxNFR
        menuL.addRow Qt::Label.new("Number of friends"), @spinBoxNBF
        menu.setLayout menuL

        layout = Qt::VBoxLayout.new
        layout.addWidget menu
        layout.addWidget @networkWidget
        setLayout layout

        @networkWidget.setFocusPolicy Qt::StrongFocus
        menu.setFixedHeight 60

        show
    end

    def changeNearbyFriendRatio r
    	@darknet.changeNearbyFriendRatio r
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
		    	@darknet.changeNearbyFriendRatio @spinBoxNBF.value
		    	@darknet.changeNbFriends @spinBoxNBF.value
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

		painter.setPen Qt::Color::new 100, 100, 255

		@darknet.links.each do |link|
 			painter.drawLine @darknet.nodes[link[0]].pos.x*(w*0.95)+w*0.025, @darknet.nodes[link[0]].pos.y*(h*0.95)+h*0.025, @darknet.nodes[link[1]].pos.x*(w*0.95)+w*0.025, @darknet.nodes[link[1]].pos.y*(h*0.95)+h*0.025
 		end

 		pen = Qt::Pen.new
 		pen.setColor Qt::Color::new 0, 255, 0
 		pen.setWidth 4
 		painter.setPen pen 

		@darknet.randomRoute.each do |link|
 			painter.drawLine @darknet.nodes[link[0]].pos.x*(w*0.95)+w*0.025, @darknet.nodes[link[0]].pos.y*(h*0.95)+h*0.025, @darknet.nodes[link[1]].pos.x*(w*0.95)+w*0.025, @darknet.nodes[link[1]].pos.y*(h*0.95)+h*0.025
 		end

 		pen = Qt::Pen.new
 		pen.setColor Qt::Color::new 255, 0, 0
 		pen.setWidth 2
 		painter.setPen pen 

		@darknet.greedyRoute.each do |link|
 			painter.drawLine @darknet.nodes[link[0]].pos.x*(w*0.95)+w*0.025, @darknet.nodes[link[0]].pos.y*(h*0.95)+h*0.025, @darknet.nodes[link[1]].pos.x*(w*0.95)+w*0.025, @darknet.nodes[link[1]].pos.y*(h*0.95)+h*0.025
 		end

		painter.setPen Qt::Color::new 255, 255, 255
		painter.setBrush Qt::Brush.new Qt::Color::new 255, 100, 100

		@darknet.nodes.each do |node|
			 painter.drawEllipse  node.pos.x*(w*0.95)-5+w*0.025, node.pos.y*(h*0.95)-5+h*0.025, 10, 10
		end

        painter.end
    end

end


app = Qt::Application.new ARGV
MainWindow.new
app.exec
