//MSAT library (Mission Screen And Telemetry updater) for getting into orbit
//designed to be used with runmode library MSAT.ks

runOncePath("MSAT").
runOncePath("mylib_math").
runOncePath("MSAT_staging").
runOncePath("MSAT_util").
runOncePath("MSAT_maneuver").


function MSATOrbit{
    parameter t_alt is false, t_inc is 0, t_lan is false.
    local seq is MSATSequence().
    seq:append("Store Target Orbit", {
        parameter mission.
        if t_alt:istype("String"){
            set t_alt to mission:readMem(t_alt).
            mission:eraseMem(t_alt).
        }
        if t_inc:istype("String"){
            set t_inc to mission:readMem(t_inc).
            mission:eraseMem(t_inc).
        }
        if t_lan:istype("String"){
            set t_lan to mission:readMem(t_lan).
            mission:eraseMem(t_lan).
        } 
        mission:storeMem("t_alt", t_alt).
        mission:storeMem("t_inc", t_inc).
        mission:storeMem("t_lan", t_lan).
        mission:storeMem("countdown", 10).
        mission:next().
    }).
    
    //calculate initial orbit based on target nad current location
    seq:append(MSATOrbitPrep()).
    //warp to time to launch
    seq:append(MSATWaitWarp("ttl")). 
    //countdown!
    seq:append(MSATCountdown("countdown")).
    //launch and gravity turn
    seq:append(MSATGravityTurn()).
    //create circularization maneuver
    seq:append(MSATcircMnv("t_alt")).
    //execute circularization maneuver
    seq:append(MSATexecMnv()).
    
    return seq:getSequence().
}

//define altitude, inclination, time to launch, initial turn angle (between UP vector and velocity vector),
//burn angle (between NORTH vector and velocity vector) based on target orbit parameters.
function MSATOrbitPrep{
    local seq is MSATSequence().

    //set altitude if undefined
    seq:append("Define Altitude", {
        parameter mission.

        mission:defineScreenData(MSATPredef:Suborbit).

        local t_alt is mission:readMem("t_alt").
        if t_alt = false{
            if body:atm:exists{
                set t_alt to body:atm:height+10000.
            }
            else{
                set t_alt to 20000.
            }
        }
        if t_alt < body:atm:height{
            mission:printMessage("Target orbit is within the body's atmosphere. Target altitude: "+round(t_alt)+"m. Atmosphere height: "+round(body:atm:height)+"m.", 4, "warning").
        }
        else mission:printMessage("Target orbit altitude: "+round(t_alt)+"m.", 4, "beep").
        mission:storeMem("init_alt", t_alt).
        mission:storeMem("turnAngle", getInitialAngle(t_alt)).
        mission:next().
    }). 

    //limit inclination based on ship position
    seq:append("Limit Inclination",{
        parameter mission.

        local t_inc is mission:readMem("t_inc").
        local init_inc to limitInclination(t_inc, ship:geoPosition:lat).
        mission:storeMem("init_inc", init_inc).
        mission:next().
    }).

    //calculate time to launch based on target longitude of ascending node
    seq:append("Get Start Time", {
        parameter mission.
        local t_lan is mission:readMem("t_lan").
        local init_inc is mission:readMem("init_inc").
        local burnAngle to getAz(init_inc, true, true).
        local t is 0.
        local countdown is mission:readMem("countdown").
        if t_lan{
            local c_lan is getLan(burnAngle).
            set t to clamp360(t_lan-c_lan)*body:rotationperiod/360-30. //minus 30 seconds to account for launch time

            // if time to start -inc orbit is less than +inc, set t to t2 and init_inc to -init_inc
            if abs(init_inc) >= abs(ship:geoposition:lat){
                local c_lan2 is getLan(180-burnAngle).
                local t2 is clamp360(t_lan-c_lan2)*body:rotationperiod/360-30.
                if (t2 < t) and (t2 > 22+countdown){
                    set t to t2.
                    set init_inc to -init_inc.
                    mission:storeMem("init_inc", init_inc).
                }
            }

            //set t to one extra rotation if it's lower than 32 seconds (enough time for messages and countdown)
            if t <= 22+countdown {
                set t to t + body:rotationperiod.
            }
            //wait for t-13-countdouwn seconds if lan is defined. 23s is to account for all of the messages and countdown
            set t to t - 13-countdown.
        }
        mission:storeMem("ttl", t).     //time to launch
        mission:printMessage("Initial inclination: "+round(init_inc, 2)+"deg.", 4, "beep").
        mission:printMessage("Time to match the longitude of the ascending node of the target orbit: "+round(t)+"s.", 4, "beep").      
        mission:next().
    }).

    //wait for all of the messages
    seq:append(MSATwait(12)).

    //calculates initial gravity turn angle based on final altitude
    function getInitialAngle{
        parameter p_alt.
        if p_alt >= 80000 set p_alt to 80000.
        return 15.//90-p_alt/1000.
    }

    //limit target inclination angle based on current latitude
    function limitInclination{
        parameter inc, lat.
        set inc to clamp180(inc).

        if abs(inc) < abs(lat){
            set inc to -lat.
        }
        else if (abs(inc) > 180 - abs(lat)){
            set inc to 180 - abs(lat).
            if lat < 0 set inc to -inc.
        }

        return inc.
    }

    //get current longitude of ascending node at given inclination and latitude
    function getLan{
        parameter
        angle. //target inclination
        local pos is ship:geoPosition.
        set angle to clamp360(angle).
        local dLon is -arcTan(sin(pos:lat)*tan(angle)).
            
        //if orbit is retrograde set dLon to negative
        if angle > 90 and angle <= 270 {
            set dLon to dLon+180.
        }

        //take into account current angle of planet rotation and current longitude
        local c_lan is body:rotationangle + pos:lng + dLon.
    
        //local vec_c_lan is solarPrimeVector*R(0, -c_lan, 0).
        //local vec_t_lan is solarPrimeVector*R(0, -t_lan, 0).
        //set vec_c_lan:mag to target:orbit:semimajoraxis.
        //set vec_t_lan:mag to target:orbit:semimajoraxis.
        //vecDraw(body:position, vec_c_lan, red, "c_lan", 1.0, true, 0.2, true).
        //vecDraw(body:position, vec_t_lan, green, "t_lan", 1.0, true, 0.2, true).

        return clamp360(c_lan).
    }

    return seq:getSequence().
}

function MSATGravityTurn{
    local seq is MSATSequence().
    local thrPID is pidLoop(0.05, 0.005, 0.25, 0.1, 1).
    //launch stage until launched
    seq:append("Launch", {
        parameter mission.
        //mission:storeMem("thrt", 1.0).
        lock steering to heading(0, 90, 0).
        lock throttle to 1.0.
        mission:next().
    }).

    //wait until surface velocity is 75m/s
    seq:append(MSATAutoStage("Start Gravity Turn", {
        parameter mission.
        if (velocity:surface:mag >= 75) {
            local turnAngle is mission:readMem("turnAngle").
            local inc is mission:readMem("init_inc").
            local burnAngle is getAz(inc, true, false).

            mission:printMessage("Initiate gravity turn at " + round(turnAngle)+"deg angle.", 4, "beep").
            //initiate time warp
            set kuniverse:timewarp:mode to "PHYSICS".
            set kuniverse:timewarp:warp to 2.
            lock steering to heading(burnAngle, 90-turnAngle).
            mission:next().
        }
    })).

    //wait few seconds to start gravity turn
    seq:append("Wait for Turn", {
        parameter mission.
        //when ship is turned to initial turn angle +- 2 deg
        local turnAngle is mission:readMem("turnAngle").
        if vAng(up:vector, ship:facing:vector)+2 >= turnAngle{
            mission:eraseMem("turnAngle").
            mission:next().
        }
    }).

    seq:append("Wait for Velocity Vector", {
        parameter mission.
        //when velocity vector matches ship facing +- 2 deg
        if vAng(velocity:surface, ship:facing:vector) <= 2 {
            mission:next().
        }  
    }).

    //continue gravity turn
    seq:append(MSATAutoStage("Gravity Turn", {
        parameter mission.
        local init_inc is mission:readMem("init_inc").
        local t_alt is mission:readMem("t_alt").
        local burnAngle to getAz(init_inc).
        local turnAngle to vAng(up:vector, velocity:surface).
        lock steering to heading(burnAngle, 90-turnAngle).
        local force is ship:availablethrust.
        //set min throttle to maintain 4.0 TTW
        if force{
            set thrPID:minoutput to 4*ship:mass/force.
        }
        
        //update throttle based on current altitude compared to target altitude and time to apoapsis
        local x is altitude/t_alt.
        local targetETA is 69.8895 + 22.2376 * x - 61.4641 * x^2. //keeps ETA to apoapsis between 70 seconds at early stages of ascend and 30 seconds at the late stages
        set thrPID:setpoint to targetETA.
        local thr is thrPID:update(time:seconds, ETA:apoapsis).
        lock throttle to thr.

        //end gravity turn maneuver when reached target altitude
        if (apoapsis >= t_alt){
            mission:printMessage("Target apoapsis of "+ t_alt + "m reached", 4, "success").
            unlock steering.
            lock throttle to 0.
            unlock throttle.
            set kuniverse:timewarp:warp to 0.
            set kuniverse:timewarp:mode to "RAILS".
            mission:defineScreenData(MSATPredef:Orbit).
            mission:next().
        }
    })).

    return seq:getSequence().
}

function getThrust{
    local engs is list().
    list ENGINES in engs.
    local thrust is 0.
    for eng in engs{
        set thrust to thrust + eng:THRUST.
    }
    return thrust.
}

//stolen from https://www.reddit.com/r/Kos/comments/3a5hjq/instantaneous_azimuth_function/ with minor changes
function getAz {
    parameter
	inc, // target inclination
    initAngle is false, // true for initial angle calculations (ignores the change of the inclination to oposite when reaches 'highest' point in orbit)
    ignoreOrb is false. // true if no account for current orbital vector is required

    // find horizontal component of current orbital velocity vector
    local V_ship_h is ship:velocity:orbit - vdot(ship:velocity:orbit, up:vector)*up:vector.

    // project the orbital velocity vector onto east and south directions
    local orb_e is vdot(V_ship_h, heading(90,0):vector).
    local orb_s is vdot(V_ship_h, heading(180,0):vector).

    // calculate current orbital vector heading from east
    local orbAngle is clamp360(arctan2(orb_s, orb_e)).
    
    if not initAngle{
        set inc to abs(inc).
        if orbAngle < 180 set inc to -inc.
    }

    // find orbital velocity for a circular orbit at the current altitude.
    local V_orb is sqrt( body:mu / ( ship:altitude + body:radius)).

    // project desired orbit onto surface heading
    local az_orb is arcsin ( limit(cos(inc) / cos(ship:latitude), -1, 1)).
    if (inc < 0) {
	    set az_orb to 180 - az_orb.
    }

    // if ignoreOrb = true -> do not take into account current orbital vector
    if ignoreOrb return az_orb.

    // create desired orbit velocity vector
    local V_star is heading(az_orb, 0)*v(0, 0, V_orb).

    // calculate difference between desired orbital vector and current (this is the direction we go)
    // to speed up the angle increase the vector length of the current orbit vector
    // to avoid burning sideways/backwards ensure that the second term is always smaller
    set V_ship_h:mag to V_star:mag*0.8.
    local V_corr is V_star - V_ship_h.

    // project the velocity correction vector onto north and east directions
    local vel_n is vdot(V_corr, ship:north:vector).
    local vel_e is vdot(V_corr, heading(90,0):vector).

    // calculate compass heading
    local az_corr is arctan2(vel_e, vel_n).
    return clamp360(az_corr).
}