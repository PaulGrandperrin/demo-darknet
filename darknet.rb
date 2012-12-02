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

	def initialize id
		@id = id
		@pos = Position.new
	end

	def distance a
		return self.pos.distance a.pos
	end
end

class Darknet

	attr_reader :nodes, :links, :closeFriendRatio

	def initialize

		# The list of nodes
		@nodes = Array.new

		# The list of links between nodes
		@links = Array.new

		# The nearby friend ratio determine how nodes choose their friends.
		# The bigger the ratio is, the more the proximity will be an important factor.
		# Example:
		# 0 ->		the odds of being friend with a node is the same for every node
		# 1 ->		the odds of being friend with a node is inversely proportional to the distance between them
		# 2..inf ->	the odds of being friend with a node is based on a polynomial formula of degree n
		# the exact formula is based on the circle formula (which is x² + y² = 1) :
		# probabilyOfBeingFriend = 1 - (1 - (distance - 1) ** n) ** (1/n)
		@nearbyFriendRatio=0

		# The number of friends of each nodes
		@nbFriends = 0

	end # def initialize


	# Remove links from nodes with too many friends without leaving nodes with too few friends
	def cleanNetwork
		# TODO 
	end #def cleanNetwork

	def addFriendToNode node
		chanceFactor = 1
		while true
			n = @nodes[rand(@nodes.size)]

			if @links.include? [node.id, n.id] or @links.include? [n.id, node.id] or n == node
				next
			end

			# We normalize our distance by the maximum possible distance in the plane
			dist = node.distance(n) / Math.sqrt(2)
			
			# Our friendyness formula
			if @nearbyFriendRatio == 0
				p = 1
			else
				p = 1.0 - ( 1.0 - (dist - 1.0) ** (@nearbyFriendRatio)) ** (1.0 / (@nearbyFriendRatio))
				p *= chanceFactor
			end

			if rand() < p
				@links.push [node.id, n.id]
				break
			end

			chanceFactor *= 1.1
		end
	end

	def addNode
		newNode = Node.new @nodes.size
		@nodes.push newNode
	    		
		nbFriends = [@nodes.size-1, @nbFriends].min
		nbFriends.times{ addFriendToNode newNode }


		cleanNetwork

	end # def addNode

	def recomputeFriends
		@links = Array.new

		@nodes.each do |node|
			nbFriends = [@nodes.size-1, @nbFriends].min
			(nbFriends-@links.select{|l| l[0] == node.id or l[1] == node.id}.size).times{ addFriendToNode node }		
		end

		cleanNetwork
	end

	def recomputePositions
		@nodes.each do |node|
			node.pos=Position.new
		end
	end


	def changeNearbyFriendRatio r
		@nearbyFriendRatio = r * 2
		recomputeFriends
	end # def changeNearbyFriendRatio


	def changeNbFriends n
		@nbFriends = n
		recomputeFriends
	end # def changeNbFriends

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
        @spinBoxNFR.setValue 0
        connect(@spinBoxNFR, SIGNAL('valueChanged(int)'), self, SLOT('changeNearbyFriendRatio(int)'))

		@spinBoxNBF = Qt::SpinBox.new
        @spinBoxNBF.setMinimum 0
        @spinBoxNBF.setValue 0
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

		    when Qt::Key_D
		    	@darknet = Darknet.new
		    	@networkWidget.darknet = @darknet
		    	@darknet.changeNearbyFriendRatio @spinBoxNBF .value
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
 			painter.drawLine @darknet.nodes[link[0]].pos.x*(w*0.9)+w*0.05, @darknet.nodes[link[0]].pos.y*(h*0.9)+h*0.05, @darknet.nodes[link[1]].pos.x*(w*0.9)+w*0.05, @darknet.nodes[link[1]].pos.y*(h*0.9)+h*0.05
 		end


		painter.setPen Qt::Color::new 255, 255, 255
		painter.setBrush Qt::Brush.new Qt::Color::new 255, 100, 100

		@darknet.nodes.each do |node|
			 painter.drawEllipse  node.pos.x*(w*0.9)-5+w*0.05, node.pos.y*(h*0.9)-5+h*0.05, 10, 10
		end

        painter.end
    end

end


app = Qt::Application.new ARGV
MainWindow.new
app.exec
