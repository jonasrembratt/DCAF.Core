# DCAF.EyeCandy.AirbaseTraffic

This script will help a mission maker creating "airbase traffic" (abbreviated **ABT** henceforth) on airbases that does not get into conflict with AI or player operated aircraft as they taxi, take off, or land.

## Creating a single "AirbaseTraffic" group

- Load the following scripts "MISSION START" triggers:
  - Moose.lua
  - DCAF.Core.lua
  - DCAF.EyeCandy.lua
  - DCAF.EyeCandy.AirbaseTraffic.lua
- Drop a vehicle group somewhere on the airbase (LTAG in this tutorial). Name it appropriately (for this tutorial, let's assume "`LTAG_TRAFFIC_1`")
- Create a plausible route for the **ABT**
- Add a "DO SCRIPT" action to a MISSION START (or some triggered action, depending on how/when you want to create the airbase group) to start the **ABT**, and add the following script:

```lua
LTAG_TRAFFIC_1 = DCAF.EyeCandy.AirbaseTraffic:New("LTAG_TRAFFIC_1", AIRBASE.Syria.Incirlik)
```

> Please note the name of the `AirbaseTraffic` - `LTAG_TRAFFIC_1` - we're using the same name as the group we dropped on the map (for convenience only; you can use any name but we'll be using it a lot so try to make some sense).

## Crossing taxiways and Runways

You now need to make sure whenever the group is about to cross taxiways and active runways it should always check for traffic and hold whenever a conflict is possible. To do so:

- Ensure the **ABT**'s route has a waypoint short of every TWY or RWY. Don't place it too close as the vehicle might need to slow down and stop.
- In the waypoint, add a "RUN SCRIPT" ADVANCED WAYPOINT ACTION and this script for taxiways:

```lua
LTAG_TRAFFIC_1:CrossTWY()
```

> Please note the `LTAG_TRAFFIC_1` element. This is the object we created first, when we created the **ABT**. This must be exactly the same name.

For crossing the active runway, use this script instead:

```lua
LTAG_TRAFFIC_1:CrossRWY()
```

As the **ABT** reaches these waypoints it will check for traffic and stop/hold as long as there might be a conflict. The way it does this is a little different for taxiways and runways, in that for runways it will automatically assume it's the **active** runway, and ensure no traffic is inbound inside of 6 nautical miles (the vehicle can remain holding for quite some time if a slow flying aircraft is inbound).

## Giving way

If you want the **ABT** group to move along taxiways, or other locations where it might come into conflict with other traffic, from any angle (oncoming or catching up) you can create a "give way zone" between two waypoints. Between those two zones the **ABT** will constantly monitor the nearby traffic and react to it. For oncoming conflicting traffic it will adjust its route to move out of the way. If the **ABT** senses traffic ahead that is moving slower, it will simply slow down to avoid catching up.

To create a give way zone (**GWZ**) between two waypoints, do the following:

- For the waypoint that should start the **GWZ**; add `ABT:GiveWay(<last GWZ waypoint>, <include ground traffic>, <space>)`. Assuming the **GWZ** starts with waypoint number 28 and ends with no. 30, create a "RUN SCRIPT" advanced waypoint action for waypoint 28:

```lua
LTAG_TRAFFIC_1:GiveWay( 30, true )
```

> The `30` means waypoint 30 will end the **GWZ**. The `true` means other ground traffic will also be avoided. You can also a third numeric value to control how far the **GWZ** will move to give way (default = 20 meters).

- Next, add another "RUN SCRIPT" advanced waypoint action for waypoint 30:
  
```lua
LTAG_TRAFFIC_1:GiveWayEnd()
```

> Yes, having to specify waypoint 30 twice like this is poor design, but I haven't found a technical solution yet for how to avoid it. I will look into this later.

## Holding

You can make the **GWZ** hold at various locations, for a specific or random amount of time. This can give the impression the vehicle(s) "have business" at locations, rather than constantly move around. It's also a nice way to ensure there are vehicles parked at various locations as players spawn in over the course of several hours.

To make the **GWZ** hold, you can use the `ABT:Hold(<min>, <max>, <text>, <function>)`. The min/max should be numerical, and specifies time (in seconds). You need to specify at least the first one but can specify both if you want the hold to last a random amount of time (between min/max seconds). The third parameter - text - is optional and only used for debugging purposes. The final parameter - `<function>` - can be a function to be called back when the hold is complete, and the vehicle is about to resume its route.

So, to make your **ABT** hold as some waypoint...

- Add another "RUN SCRIPT" advanced waypoint action for that waypoint (for this tutorial, let's assume we want the vehicle to make a stop at the tower):

```lua
LTAG_TRAFFIC_1:Hold(  Minutes(2), Minutes(5), "visits TWR" )
```

## Restarting the route

Eventually, the **ABT** will reach its final waypoint. If you want it to restart its route again, use the `ABT:RestartRoute(<startWaypoint>, <delay>)`. The first parameter - `<startWaypoint>` - is optional and defaults to 1. This allows restarting the route by going directly to some specific waypoint. The second parameter - `<delay>` - will make the vehicle wait for a time (seconds) before it restarts its route.

To make our `LTAG_TRAFFIC_1` **ABT** restart its route, add a "RUN SCRIPT" advanced waypoint action for its final waypoint:

```lua
LTAG_TRAFFIC_1:RestartRoute()
```