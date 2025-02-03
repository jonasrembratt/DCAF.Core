local mlrs = DCAF.Artillery:New("Arty MLRS"):InitDeploymentLocations(
    "ZN Arty-1",
    "ZN Arty-2",
    "ZN Arty-3",
    "ZN Arty-4",
    "ZN Arty-5"
)

local spotterUAV = DCAF.ArtilleryObserver:New("ARTY Observer-UAV")
                                         :InitArtillery(mlrs)
                                         :InitOrders(
                                            DCAF.ArtilleryOrder:NewTimed("Ostrich STC APC-4", 60, true),
                                            DCAF.ArtilleryOrder:NewSalvoCount("Ostrich STC MBT-1", 4, true)
                                         )
                                         :Start()