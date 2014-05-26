Smart Phone Support for Bluetooth Body Sensors - 2010
==========

My final year university project (2010) involving what was then a smartphone, a [Nokia E51](https://en.wikipedia.org/wiki/Nokia_E51), connected via Bluetooth to a [Shimmer](http://www.shimmersensing.com/) sensor running a basic fall detection algorithm. These sensors used [TinyOS](http://www.tinyos.net/) and thus the somewhat unusual [nesC](https://en.wikipedia.org/wiki/NesC) language.

The idea was that a fall-risk person would wear the sensor, and then if a fall was detected the phone would automatically call an emergency contact and route audio to the loudspeaker. It mostly worked.

The phone ran a version of python that allowed for easy access to most of its peripheral, and relatively straightforward graphing of the received signals.

The [final document](https://raw.githubusercontent.com/hughobrien/shimmer-nokia-fall-detection/master/thirdparty/fyp.pdf) is probably worth a look. Tex sources included.

Demo
----
![demonstration](https://raw.githubusercontent.com/hughobrien/shimmer-nokia-fall-detection/master/thirdparty/DSC_7505.jpg)
![demonstration](https://raw.githubusercontent.com/hughobrien/shimmer-nokia-fall-detection/master/thirdparty/DSC_7453.jpg)
