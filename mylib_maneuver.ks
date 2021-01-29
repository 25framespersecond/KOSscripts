//library for executing maneuvers and calculating


//function to convert universal time and delta v vector to maneuver
function nodeFromVec{
    parameter t, deltaV, bdy is body.

    local vecProg is velocityat(ship, t):orbit.
    local vecNorm is vCrs(vecProg, positionAt(ship, t)-bdy:position).
    local vecRad is vCrs(vecNorm, vecProg).

    local nodeProg is vDot(deltaV, vecProg:normalized).
    local nodeNorm is vDot(deltaV, vecNorm:normalized).
    local nodeRad is vDot(deltaV, vecRad:normalized).
    return node(t, nodeRad, nodeNorm, nodeProg).
}

//function to conver maneuver node to time and deltaV vector
function vecFromNode{
    parameter node.
    local t is node:ETA + time:seconds.
    add node.
    local deltav is node:deltav.
    remove node.
    return lex("t", t, "deltav", deltav).
}

//get ISP of all active engines
function getStageISP{
    local isp is 0.
    list engines in allEngines.
    for eng in allEngines{
        if (eng:ignition and not(eng:flameout)){
            set isp to isp + (eng:isp * (eng:AVAILABLETHRUST/ship:AVAILABLETHRUST)).
        }
    }
    return isp.
}

//get deltaV of the current stage
function getStageDeltaV{
    // deltaV = ISP*g0*ln(m0/mf)
    local emptyMass is ship:mass - getStageFuelMass().
    return getStageISP() * constant:g0 * ln(ship:mass/emptyMass).
}

//calculate the mass of liquid and solid propelent for current stage
function getStageFuelMass{
    local resList is stage:RESOURCES.
    local fuelMass is 0.
    for res in resList{
        if (res:name = "LiquidFuel" or res:name = "Oxidizer" or res:name = "SolidFuel" or res:name = "Xenon"){
            set fuelMass to fuelMass+(res:amount * res:density).
        }
    }
    for res in resList{
        if (res:name = "LiquidFuel" or res:name = "Oxidizer" or res:name = "SolidFuel" or res:name = "Xenon"){
            set fuelMass to fuelMass+(res:amount * res:density).
        }
    }
    return fuelMass.
}
