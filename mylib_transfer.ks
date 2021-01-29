//intercept transfer calculations from one orbit to another

runOncePath("mylib_obt").
runOncePath("mylib_vec").
runOncePath("mylib_math").


//calculate true anomaly of an object in one orbit
//relative to the periapsis of the second orbit
//Note: relative true anomaly is returned by default
//pass mean anomaly to return relative mean anomaly
function getRelativeAnom{
    parameter chaseObt is obt,
    targetObt is target:obt,
    ano is chaseObt:trueanomaly.
    local AoP_s is chaseObt:argumentofperiapsis.
    local lan_s is chaseObt:lan.
    local AoP_t is targetObt:argumentofperiapsis.
    local lan_t is targetObt:lan.
    //local laps is countLaps(ano).
    return ano-(AoP_t + (lan_t - lan_s) - AoP_s).    
}

//get an angle between two objects in different orbits
//positive angles means that the chaser is behind the target
//negative angles means that the chaser is in front of the target
//the result angle is between -180..180 degrees
//Note: the angle between mean anomalies is returned
function getCurrPhaseAngle{
    parameter chaseObt is obt,
    targetObt is target:obt.
    local chaseAno is getRelativeAnom(chaseObt, targetObt, ano_t2m(chaseObt:trueanomaly, chaseObt:eccentricity)).
    local targetAno is ano_t2m(targetObt:trueanomaly, targetObt:eccentricity).
    return clamp360(targetAno - chaseAno).
}

//get phase angle of the interception
//the returned angle is a mean anomaly angle
//pass a transfer orbit period
//of the real orbit for accurate results
function getPhaseAngle{
    parameter tsfr_period,
    t_orbit is target:obt,
    //the function calculates angle between mean anomalies
    //to account for a difference between mean and true anomaly of the target
    //object the error angle is used (err = T_an - M_an)
    err is 0.
    local t_period is t_orbit:period.
    return clamp360(180 - tsfr_period * 180 / t_period - err).
}

//get time to an interception phase
//phase angles are mean anomaly based
function getTimeToPhase{
    parameter i_orbit, t_orbit,
    i_phase, t_phase.
    local i_period is i_orbit:period.
    local t_period is t_orbit:period.
    if(i_period>t_period){
        local temp is i_period.
        set i_period to t_period.
        set t_period to temp.
        set temp to i_phase.
        set i_phase to t_phase.
        set t_phase to temp.
    }
    return clamp360(i_phase-t_phase)/((1/i_period - 1/t_period)*360).
}

//get time to intercept maneuver
//initial orbit should be close to circular
//returns universal time to avoid delays caused by calculations
//orbital parameters of the transfer orbit are returned as a lexicon to reduce further calculations
//this function works if at least one of the orbits is circular
//for the calculation of the time of the transfer half of the transfer orbit period is used
//if both orbits are highly elliptical this would give incorrect results
function getInterceptTransfer{
    parameter i_orbit is obt,
    t_orbit is  target:obt, 
    f_phase is 0,   //final phase between chase and target objects after intercept
    err is 0.0005.
    //initial angle between chaser and the target
    local i_phase to getCurrPhaseAngle(i_orbit, t_orbit).
    //initial guess of the radius at the intercept point
    local R_final is t_orbit:semimajoraxis.
    local R_start is i_orbit:semimajoraxis.
    //the difference between true and mean anomaly plus final phase angle
    local ano_err is 0.
    //initial guess of the transfer period and transfer phase angle 
    local tsfr_semimajor is (R_start+R_final)/2.
    local tsfr_period is getPeriod(tsfr_semimajor, i_orbit:body).
    local t_phase is getPhaseAngle(tsfr_period, t_orbit).
    //initial guess of the transfer time
    local t to getTimeToPhase(i_orbit, t_orbit, i_phase, t_phase).
    local T_final2 is 0.
    local T_start1 is 0.
    //time error required to process loop iteration
    local err_t is 0.
    //vector to display convergence
    //local vis_ano_vec is vecDraw().
    for i in range(100){
        //recalculate current phase angle and target phase angle with each iteration
        //initial phase is recalculated because calculations take time and initial
        //phase is changing over time
        set i_phase to getCurrPhaseAngle(i_orbit, t_orbit).
        //transfer phase recalculation takes into account change in transfer period
        //and th difference between true and mean anomaly of the intercept position
        set t_phase to getPhaseAngle(tsfr_period, t_orbit, ano_err).
        //time is calculated as an avarage between prev and current time calculation
        //otherwise time oscillates too much and does not converge
        set t to (t+getTimeToPhase(i_orbit, t_orbit, i_phase, t_phase))/2.
        set err_t to time:seconds.
        //transer period is calculated from the radius of the final orbit
        //at the intercept position of the chaser orbitable
        set T_start1 to anomalyAtTime(t, i_orbit, i_orbit:trueanomaly).
        local M_start1 to ano_t2m(T_start1, i_orbit:eccentricity).
        local T_final1 is getRelativeAnom(i_orbit, t_orbit, T_start1+180).
        set R_final to radiusAtAnomaly(T_final1, t_orbit).
        set R_start to radiusAtAnomaly(T_start1, i_orbit).
        set tsfr_semimajor to (R_start+R_final)/2.
        set tsfr_period to getPeriod(tsfr_semimajor, i_orbit:body).
        //final position of the target orbitable is calculated using new transfer period
        local M_final2 is anomalyAtTime(t+tsfr_period/2, t_orbit, t_orbit:trueanomaly, anomType:a_mean).
        local T_final2_new is ano_m2t(M_final2, t_orbit:eccentricity).
        //anomaly error is the difference between true and mean final anomaly of the targer object
        //intended final phase angle is substracted from ano_err
        //TODO: make intended final phase to be calculated in mean anomaly terms 
        if abs(T_final2_new - T_final2) < err break.
        set T_final2 to T_final2_new.
        set ano_err to (T_final2 - M_final2)+(M_start1 - T_start1)+f_phase.
        //if i = 99 printMessage("Function getInterceptTime() failed to converge.").

        //set vis_ano_vec:show to false.
        //set vis_ano_vec to drawAnomaly(t_orbit, T_final2, red, "Convergence").
    }
    set err_t to time:seconds-err_t.
    set t to t+time:seconds-err_t.
    
    //transfer orbit parameters
    //e = rmax/a - 1
    local ecc is R_final/tsfr_semimajor - 1.
    local aop is clamp360(i_orbit:argumentofperiapsis+clamp360(T_start1)).

    //set vis_ano_vec:show to false.

    //return time of transfer and orbital parameters of the transfer
    return lex("t", t, "orbit", lex("sma", tsfr_semimajor, "ecc", ecc, "aop", aop, "lan", i_orbit:lan, "i", i_orbit:inclination, "body", i_orbit:body)).
}

//get deltaV required to change one orbit to another
//transfer lexicon obtained from getInterceptTime() can be used for either of the orbits
//for transfer lexicon initial and final anomalies are assume to be 180 and 0 degrees
function getOrbitDiffDeltaV{
    parameter t, i_orbit, t_orbit.
    local i_anomaly is 180.
    local t_anomaly is 0.
    if i_orbit:istype("Orbit") set i_anomaly to anomalyAtTime(t-time:seconds, i_orbit).
    if t_orbit:istype("Orbit") set t_anomaly to anomalyAtTime(t-time:seconds, t_orbit).
    local initState is getStateVectors(i_anomaly, i_orbit).
    local finalState is getStateVectors(t_anomaly, t_orbit).
    return finalState:vel - initState:vel.
}