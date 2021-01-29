// this lib contains functions for orbital parameters calculations
// such as: true anomaly, mean anomaly, eccentric anomaly
// time to anomaly, anomaly to radius
// for all of the below functions the input and output are in degrees
// TODO: check for input/output angle range. (0..360) for elliptic, (-180..180) for hyperbolic

runOncePath("mylib_math").

//enumeral used to define an anomaly type
//in result or the input of the conversion function
global anomType is lexicon("a_mean", 0, "a_true", 1, "a_ecce", 2).

//converts eccentric anomaly to mean anomaly
// e - eccentricity, default value - orbit:eccentricity
function ano_e2m{
    parameter E_an,         //eccentric anomaly
    e is obt:eccentricity.  //eccentricity
    
    if e > 1{               //e>1 - orbit is hyperbolic 
        set E_an to clamp180(E_an).
        return e*sinh(E_an)*CONST_toDeg - E_an. 
    }
    //to account for angles >360 and <0 the sign and rotations are stored
    local laps is countLaps(E_an).
    set E_an to clamp360(E_an).
    return E_an - e*sin(E_an)*CONST_toDeg + 360*laps.
}

//converts eccentric anomaly to true anomaly
function ano_e2t{
    parameter E_an,
    e is obt:eccentricity.

    if e > 1{               //hyperbolic orbit
        set E_an to clamp180(E_an).
        local sign is E_an/abs(E_an).
        return sign * arcCos((cosh(E_an)-e)/(1-e*cosh(E_an))).
    }
    local laps is countLaps(E_an).
    set E_an to clamp360(E_an).
    if E_an > 180 { return 360 - arcCos((cos(E_an)-e)/(1-e*cos(E_an))) + 360*laps. }
    return arcCos((cos(E_an)-e)/(1-e*cos(E_an))) + 360*laps.
}

//converts true anomaly to eccentric
function ano_t2e{
    parameter T_an,
    e is obt:eccentricity.
    if e > 1{               //hyperbolic orbit
        set T_an to clamp180(T_an).
        local sign is T_an/abs(T_an).
        return sign*acosh((e+cos(T_an))/(1+e*cos(T_an))).
    }
    local laps is countLaps(T_an).
    set T_an to clamp360(T_an).
    if T_an > 180 { return 360 - arcCos((e+cos(T_an))/(1+e*cos(T_an))) + 360*laps. }
    return arcCos((e+cos(T_an))/(1+e*cos(T_an))) + 360*laps.
}

//converts mean anomaly to eccentric
//solving M = E - e*sin(E) for E using Newton-Raphson method
function ano_m2e{
    parameter M_an,
    e is obt:eccentricity,
    accuracy is 1E-15.
    local E_an is 0.
    if e > 1{                       //hyperbolic orbit
        set M_an to clamp180(M_an)*CONST_toRad.
        set E_an to M_an.         //initial guess
        for i in range(100){
            local err is e*sinh(E_an*CONST_toDeg) - E_an - M_an.        //function e*sinh(E) - E - M = 0
            local deriv is e*cosh(E_an*CONST_toDeg) - 1.                //derivitive e*cosh(E) - 1
            if abs(err) < accuracy {return E_an*CONST_toDeg.}
            set E_an to E_an - err/deriv.
        }
        //printMessage("Failed to converge on ano_m2E function for hyperbolic orbit.").
    }
    else{                           //elliptic 
        local laps is countLaps(M_an).
        set M_an to clamp360(M_an)*CONST_toRad.
        set E_an to M_an.
        for i in range(100){
            local err is E_an - e*sin(E_an*CONST_toDeg) - M_an.         //function E - e*sin(E) - M = 0
            local deriv is 1 - e*cos(E_an*CONST_toDeg).                 //derivitive 1 - e*cos(E)
            if abs(err) < accuracy {return E_an*CONST_toDeg + 360*laps.}
            set E_an to E_an - err/deriv.
        }
        //printMessage("Failed to converge on ano_m2E function for elliptic orbit.").
    }
    return E_an.
}

//converts true anomaly to mean
//T -> E -> M
function ano_t2m{
    parameter T_an,
    e is obt:eccentricity.
    return ano_e2m(ano_t2e(T_an, e), e).
}

//converts mean anomaly to true
//M -> E -> T
function ano_m2t{
    parameter M_an,
    e is obt:eccentricity,
    accuracy is 1E-15.
    return ano_e2t(ano_m2e(M_an, e, accuracy), e).
}

//get true anomaly at a specific time
//relative time should be used for the input
//parameter o accepts ORBIT type or list(eccentricity, period)
function anomalyAtTime{
    parameter t,
    o is obt,
    T_init is o:trueanomaly, //current true anomaly
    result is anomType:a_true.
    local e is 0.
    local P is 0.
    if o:isType("Lexicon"){
        set e to o:ecc.
        set P to o:period.
    }
    else{
        set e to o:eccentricity.
        set P to o:period.
    }
    local M_init is ano_t2m(T_init, e).
    local M_final is M_init + 360*t/P.
    if result = anomType:a_true
        return ano_m2t(M_final, e).
    else return M_final.
}

//get a time to a specific true anomaly
//relative time is returned
//parameter o accepts ORBIT type or list(eccentricity, period)
function timeAtAnomaly{
    parameter T_final,
    o is obt,
    T_init is o:trueanomaly,      //current true anomaly
    input is anomType:a_true.
    local e is 0.
    local P is 0.
    if o:isType("Lexicon"){
        set e to o:ecc.
        set P to o:period.
    }
    else{
        set e to o:eccentricity.
        set P to o:period.
    }
    local M_init is T_init.
    local M_final is T_final.
    if input = anomType:a_true{
        set M_init to ano_t2m(T_init, e).
        set M_final to ano_t2m(T_final, e).
    }
    return P*(M_final - M_init)/360.
}

//get radius (distance to the center of the body) at specific true anomaly
function radiusAtAnomaly{
    parameter T_an,
    o is obt,
    input is anomType:a_true.
    local e is 0.
    local a is 0.
    if o:istype("Lexicon"){
        set e to o:ecc.
        set a to o:sma.
    }
    else{
        set e to o:eccentricity.
        set a to o:semimajoraxis.
    }
    if input = anomType:a_mean{
        set T_an to ano_m2e(T_an, e).
        set input to anomType:a_ecce.
    }
    if input = anomType:a_ecce{
        return a*(1-e*cos(T_an)).
    }
    return a*(1-e^2)/(1+e*cos(T_an)).
}

//get radius at a specific time in a future
//relative time should be used for the input
function radiusAtTime{
    parameter t,
    o is obt,
    T_init is o:trueanomaly.
    return radiusAtAnomaly(anomalyAtTime(t, o, T_init), o).
}

//get anomaly at a specific radius
function anomalyAtRadius{
    parameter r,
    o is obt,
    output is anomType:a_ecce.
    local e is 0.
    local a is 0.
    if o:istype("Lexicon"){
        set e to o:ecc.
        set a to o:sma.
    }
    else{
        set e to o:eccentricity.
        set a to o:semimajoraxis.
    }
    local E_an is arcCos((1-r/a)/e).
    if output = anomType:a_true{
        set E_an to ano_e2t(E_an, e).
    }
    else if output = anomType:a_mean{
        set E_an to ano_e2m(E_an, e).
    }
    return E_an.
}

//get time to a specific radius from true anomaly
function timeAtRadius{
    parameter r,
    o is obt,
    T_init is o:trueanomaly.
    local e is 0.
    if o:istype("Lexicon"){
        set e to o:ecc.
    }
    else{
        set e to o:eccentricity.
    }
    
    local M_final is anomalyAtRadius(r, o, anomType:a_mean).
    local M_init is ano_t2m(T_init, e).
    return timeAtAnomaly(M_final, o, M_init, anomType:a_mean).
}

//get orbit period based on the sami major axis
function getPeriod{
    parameter a is obt,
    bdy is obt:body.
    if a:istype("Orbit") return a:period.
    return 2*constant:pi*SQRT(a^3/bdy:mu).
}
