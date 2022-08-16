# dubinsTest
Testing stuff about Dubins paths/curves.

This version assumes that the truck is articulated; this means:
* the truck can't simply steer fully, then go (This would displace the truck and look odd.)
* the truck starts moving and steers at the same time until the truck is fully steering.

Incidently, to simulate this, we test that the truck will plan with Dubins path at a distance and offset angle away from the current location. 

