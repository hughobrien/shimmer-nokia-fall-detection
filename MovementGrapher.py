# Accelerometer Grapher and Fall Dector - Hugh O'Brien March 2009
#
#This is a script for PyS60 that opens a bluetooth serial connection
#to a pre-programmed SHIMMER sensor, The SHIMMER provides accelerometer
#data in the form "1111 1111 1111" where '1111' will be in the range
#of 0 -> 4400. The three values represent the data gathered
#from monitoring the three axis of the accelerometer.
#
#The script reduces the accuracy of these values in order to be able
#to graph them on a screen that is only 320x240px in size
#
#The script also monitors the difference between two subsequent
#readings in order to determine if a large movement has occured.
#This can be interpreted as a fall. A call is then placed to a
#pre-defined telephone number and the details of the victim are
#read out to the receiver.

import e32, appuifw, audio, telephone
#btsocket is the 'old' BT system, new version introduced in
#PyS60 1.9.1 is harder to work with.
import btsocket as socket 

#a predefined BT MAC address can be set here to skip discovery process
target = ''

contact_name = "John Watson"
contact_number = "5550137"
victim_name = "Mr. Sherlock Holmes"
victim_address = "221 B. Baker Street. London"

sensitivity = 28

def fall():
    global app_lock, contact_name, contact_number, victim_name,\
    victim_address, data, prev
    
    audio.say("Dialling %s now" % contact_name)
    telephone.dial(contact_number)
    e32.ao_sleep(7) #7 sec delay for someone to answer
    for i in range(2, -1, -1):
        audio.say("This is an automated message. A fall has been detected.\
	Please assist %s at address %s. \
	This message will repeat %d more times" \
	% (victim_name, victim_address, i) )
	
    telephone.hang_up()
    data = ( 40, 40, 40 ) #reset values so as not to trigger again
    prev = data
    app_lock.signal() #unlock the main loop

def connect(): #this function sets up the BT socket connection
    global btsocket, target

    try:
         #socket params passed to the OS
        btsocket=socket.socket(socket.AF_BT,socket.SOCK_STREAM)

        if target == '': #if no target defined, begin OS discovery routine
            address,services = socket.bt_discover()
            target = (address, services.values()[0])

        btsocket.connect(target) #initiate connection and notify user
        appuifw.note(u"Connected to " + str(address), "info")

    except: #fail cleanly
        appuifw.note(u"Error connecting to device")
        btsocket.close()

def getData(): 	#this receives single characters over the bitstream
                #until it encounters a newline and carraige return it then
                #returns the characters it has buffered until that point
                
    global btsocket #use the globally defined socket
    buffer = "" #create an empty buffer
    rxChar = btsocket.recv(1) #receive 1 char over BT and save in rxChar

    #spin here until we get a 'real' char
    while (rxChar == '\n') or (rxChar == '\r'):
        rxChar = btsocket.recv(1)
        
    #as long as we receive 'real' chars buffer them
    while (rxChar != '\n') and (rxChar != '\r'):
        buffer += rxChar
        rxChar = btsocket.recv(1)
        
    return buffer #return the buffer contents

    
def graph_data(input): 	
    
    #this function produces the graphs on the screen. the screen is
    #landscape oriented with a resolution of 240x320. The constants seen
    #here are used to define where on the screen the graphs should be drawn
    
    global count, canvas, prev, data
    
    #take the input string formated like "1111 1111 1111"  and parse it
    #to acquire 3 sets of chars and then interpret them as digits saving
    #them to a list in this format: ( '1111', '1111', '1111' )
    #the values are then divided by 60 as they will be in the range
    #0 -> x -> 4400 as the screen is only 240px high. furthermore as there
    #are three graphs being drawn each is confined to (240 / 3 )px of
    #height. The divisor of 60 accommodates this at the cost of accuracy.
    
    try:
        data = (\
        int(input[0:4]) / 60, \
        int(input[5:9]) / 60, \
        int(input[10:14]) / 60\
        )
        
    #sane defaults if we receive a malformed reading
    except ValueError:
        data = ( 36, 36, 36 ) 

    #redraw the screen if there are more than 280 samples displayed.
    if count > 280: 
        reset()
    
    #draw a line, with the X1 starting 10 points from the left and
    #expanding right, Y1 being the previous value of Y2 (initially zero)
    #plus a vertical offset so the graphs don't overlap each other, X2
    #being one point right of X1 and Y2 one of the 3 XYZ readings plus
    #the vertical offset. other options are purely aesthetic.
    canvas.line(\
    (count + 10, prev[0], count + 11, data[0] ), \
    outline = 0xFF0000, width = 1)
    
    canvas.line(\
    (count + 10, prev[1] + 80, count + 11, data[1]  + 80), \
    outline = 0x00DD00, width = 1)
    
    canvas.line(\
    (count + 10, prev[2] + 160, count + 11, data[2]  + 160), \
    outline = 0x4444FF, width = 1)

    #increment counter - data should also be pushed into prev here
    #but this happens in the main loop for monitoring reasons
    count = count + 1
    
def reset(): # this function redraws the screen when it becomes full
    global count, canvas
    
    #reset the count and redraw a blank canvas
    count = 0
    canvas.rectangle((0, 0, 320, 240), fill = 0x000000)


#Main
data = ( 0, 0, 0 )
prev = (40, 40, 40) #initial zero values for 'previous values' of the data
canvas = appuifw.Canvas() #create a new Canvas object
appuifw.app.body = canvas
appuifw.app.screen = "full" #go 'fullscreen'
appuifw.app.orientation = "landscape" # draw in landscape orientation
appuifw.app.title = u"Activity Monitor" #name the program
app_lock = e32.Ao_lock() #locking system

connect() #open the BT socket
e32.ao_sleep(1) # sleep for 1 second in case of graphical slowness
reset() # initially reset the screen to draw the canvas

while 1: #loop the following code infinitely 
    e32.reset_inactivity() #keep the screensaver away
    graph_data( getData() ) # poll the BT data passing it to the grapher.
    
    #test the movement level between the last two samples
    if ( (abs(data[0] - prev[0]) > sensitivity ) \
    or (abs(data[1] - prev[1]) > sensitivity ) \
    or (abs(data[2] - prev[2]) > sensitivity ) ):
    
        fall() #if too much, take action
        app_lock.wait() #pause this loop until fall() finishes
        e32.ao_sleep(1)
        reset()
        
    prev = data #move current data into previous data buffer