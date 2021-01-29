//MSAT library (Mission Screen And Telemetry updater) for executing manevers
//designed to be used with runmode library MSAT.ks

runOncePath("MSAT").
runOncePath("MSAT_util").
runOncePath("mylib_obt").
runOncePath("mylib_maneuver").
runOncePath("mylib_vec").

//main executing maneuver function
function MSATexecMnv{
    local seq is MSATSequence().

    //get time to maneuver
    //get maneuver execution time
    //get total deltaV
    seq:append(MSATStep("Maneuver parameters", {
        parameter mission.
        local mnv to nextNode.
        local tMnv is mnv:eta()+time:seconds.
        local vec_dv is mnv:deltaV.
        //increase delta V by 10%
        set vec_dv:mag to vec_dv:mag*10/9.
        //no easy way to change delta V of the maneuver node, so have to re-add it
        remove mnv.
        set mnv to nodeFromVec(tMnv, vec_dv).
        add mnv.
        local tExec is getManeuverBurnTime(mnv).
        local maxThrottle is 1.0.
        //if execution time is lower than 10s limit throttle to make it 10s
        if tExec < 10{
            set maxThrottle to tExec/10.
            set tExec to 10.
        }
        local deltaV is mnv:deltaV:mag.
        mission:storeMem("tMnv", tMnv).
        mission:storeMem("tExec", tExec).
        mission:storeMem("deltaV", deltaV).
        mission:storeMem("c_dV", deltaV).
        mission:storeMem("maxThrottle", maxThrottle).
        mission:printMessage("Executing maneuver. DeltaV: "+round(deltaV,2)+"m/s. Execution Time: "+round(tExec)+"s.", 4, "beep").
        mission:addScreenData(list("Manever dV", "m/s", "c_dV")).
        mission:next().
    })).
    
    //turn to maneuver
    seq:append(MSATturnToNode()).

    //wait to maneuver start minus some time
    seq:append(MSATStep("Wait for maneuver", {
        parameter mission.
        local tMnv is mission:readMem("tMnv").
        local tExec is mission:readMem("tExec").
        local waitTime is (tMnv - time:seconds)-tExec/2-10. //wait to maneuver start minus 10s
        mission:storeMem("waitTime", waitTime).
        mission:next().
    })).
    seq:append(MSATwaitWarp("waitTime")).

    //turn to maneuver
    seq:append(MSATturnToNode()).

    //wait for maneuver start
    //start maneuver
    seq:append(MSATStep("Start Maneuver", {
        parameter mission.
        local tMnv is mission:readMem("tMnv").
        local tExec is mission:readMem("tExec").
        local maxThrottle is mission:readMem("maxThrottle").
        local t is tMnv - tExec/2.
        if t <= time:seconds+0.5{
            lock throttle to maxThrottle.
            mission:next().
        }
    })).

    //wait for maneuver end (based on delta v)
    seq:append(MSATAutoStage("Execute Maneuver", {
        parameter mission.
        local maxThrottle is mission:readMem("maxThrottle").
        //min throttle is 1% of max throttle
        local minThrottle is maxThrottle/100.
        local deltaV is mission:readMem("deltaV").
        //epsilon defines the margin at which maneuver ends as a 10% of deltaV
        local epsilon is deltaV/10.
        local mnv is nextNode.

        local thr is maxThrottle.
        local c_dV is mnv:deltaV:mag.
        //start reducing throttle at 10% deltaV
        if c_dV <= deltaV/10{
            set thr to (maxThrottle-minThrottle)*c_dV/(deltaV/10) + minThrottle.
        }

        lock throttle to thr.

        // TODO: ensure no overshooting occurs
        if c_dV <= epsilon{
            lock throttle to 0.
            unlock throttle.
            unlock steering.
            mission:printMessage("Maneuver Node Executed. Total DeltaV: "+round(deltaV-epsilon,2), 4, "success").

            //clear memory and remove node
            mission:eraseMem("tMnv").
            mission:eraseMem("tExec").
            mission:eraseMem("deltaV").
            mission:eraseMem("maxThrottle").
            mission:eraseMem("waitTime").
            mission:eraseMem("c_dV").
            mission:removeScreenData("Manever dV").
            remove mnv.
            mission:next().
            return.
        }
        mission:storeMem("c_dV", c_dV).
    })).

    //helper functions
    function MSATturnToNode{
        return MSATStep("Turn to Node", {
            parameter mission.
            local mnv is nextNode.
            lock steering to mnv:deltaV:direction.
            if vAng(mnv:deltaV:direction:vector, ship:facing:vector) <= 1{
                mission:next().
            }
        }).
    }

    function getManeuverBurnTime{
        parameter mnv.

        local deltaV is mnv:deltaV:mag.
        local isp is getStageISP().

        // deltaV = ISP*g0*ln(m0/mf) -> mf = m0/e^(deltaV/(ISP*g0)).
        local finalMass is ship:mass/constant:e^(deltaV/(isp*constant:g0)).
        local fuelFlow is ship:availablethrust/(isp*constant:g0).
        local deltat is (ship:mass - finalMass)/fuelFlow.

        return deltat.
    }

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

    return seq:getSequence().
}

//create circularization maneuver
function MSATcircMnv{
    parameter t_alt is false.

    return MSATStep("Create Circularization Maneuver", {
        parameter mission.
        if t_alt:istype("String"){
            set t_alt to mission:readMem(t_alt).
        }
        if t_alt > obt:apoapsis set t_alt to obt:apoapsis.
        else if t_alt < obt:periapsis set t_alt to obt:periapsis.
        local T_an is anomalyAtRadius(t_alt+body:radius, obt, anomType:a_true).
        local curr_state is getStateVectors(T_an, obt, anomType:a_true).
        local tar_state is getStateVectors(T_an, lex("sma", t_alt+body:radius, "ecc", 0, "aop", obt:argumentofperiapsis, "lan", obt:lan, "i", obt:inclination, "body", body), anomType:a_true).
        local deltaV is tar_state:vel - curr_state:vel.
        local t is timeAtAnomaly(T_an).
        local mnv is nodeFromVec(t+time:seconds, deltaV).
        add mnv.
        mission:next().
    }).
}