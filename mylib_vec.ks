//vector and matrix operations and visualization library
runOncePath("mylib_obt").

//draw an anomaly angle on a map view
//returns vectors that should be cleared afterwards
function drawAnomaly{
    parameter o is obt,
    ano is o:trueanomaly,
    color is yellow,
    name is "True Anomaly".
    local AN_vec to getANvec(o).
    local NORM_vec to getNormVec(o).
    local PE_vec to getPEvec(o, NORM_vec, AN_vec).
    local ano_vec is angleAxis(-ano, NORM_vec)*PE_vec.
    //set AN_vec:mag to o:semimajoraxis.
    //set NORM_vec:mag to o:semimajoraxis.
    local PERad to o:periapsis+o:body:radius.
    set PE_vec:mag to PERad.
    local anoRad is radiusAtAnomaly(ano, o).
    set ano_vec:mag to anoRad.
    function positionUpdate{
        parameter or.
        return or:body:position.
    }

    //local vis_AN_vec is vecDraw(o:body:position, AN_vec, green, "AN vec", 1.0, true, 0.2, false).
    //set vis_AN_vec:startupdater to positionUpdate@:bind(o).
    //set vis_AN_vec:vecupdater to getANvec@:bind(o).
    //local vis_NORM_vec is vecDraw(o:body:position, NORM_vec, magenta, "NORM vec", 1.0, true, 0.2, false).
    //set vis_NORM_vec:startupdater to positionUpdate@:bind(o).
    //local vis_PE_vec is vecDraw(o:body:position, PE_vec, red, "PE vec", 1.0, true, 0.2, false).
    //set vis_PE_vec:startupdater to positionUpdate@:bind(o).
    //set vis_PE_vec:vecupdater to {local v is getPEvec(o, NORM_vec). set v:mag to PERad. return v.}.
    local vis_ano_vec is vecDraw(o:body:position, ano_vec, color, name, 1.0, true, 0.2, false).
    set vis_ano_vec:startupdater to positionUpdate@:bind(o).
    set vis_ano_vec:vecupdater to {local v is getPEvec(o, NORM_vec). set v:mag to anoRad. return angleAxis(-ano, NORM_vec)*v.}.
    return vis_ano_vec.
}

//draw orbitable vectors: prograde, normal and radial
function drawManeuverVec{
    parameter o is ship.
    local PROG_vec is getProgVec(o).
    local NORM_vec is getNormVec(o).
    local RAD_vec is getRadVec(o).
    set PROG_vec:mag to 5.0.
    set NORM_vec:mag to 5.0.
    set RAD_vec:mag to 5.0.
    function positionUpdate{
        parameter sh.
        return sh:position.
    }
    local vis_PROG_vec is vecDraw(o:position, PROG_vec, yellow, "Prograde vector", 1.0, true, 0.2, true).
    set vis_PROG_vec:startupdater to positionUpdate@:bind(o).
    set vis_PROG_vec:vectorupdater to { local v is getProgVec(o). set v:mag to 5.0. return v. }.
    local vis_NORM_vec is vecDraw(o:position, NORM_vec, magenta, "Normal vector", 1.0, true, 0.2, true).
    set vis_NORM_vec:startupdater to positionUpdate@:bind(o).
    set vis_NORM_vec:vectorupdater to { local v is getNormVec(o). set v:mag to 5.0. return v. }.
    local vis_RAD_vec is vecDraw(o:position, RAD_vec, blue, "Radial vector", 1.0, true, 0.2, true).
    set vis_RAD_vec:startupdater to positionUpdate@:bind(o).
    set vis_RAD_vec:vectorupdater to { local v is getRadVec(o). set v:mag to 5.0. return v. }.
    return list(vis_PROG_vec, vis_NORM_vec, vis_RAD_vec).
}

//get ascending node vector of the orbit
function getANvec{
    parameter o is obt.
    local AN_vec is solarPrimeVector*R(0, -o:lan, 0).
    return AN_vec.
}

//get normal vector of the orbit
//funcion accepts orbit or an orbitable as a parameter
function getNormVec{
    parameter o is ship.
    local NORM_vec to vCrs(o:velocity:orbit, o:position-o:body:position).
    return NORM_vec.
}

//get vector pointing at periapsis
//if AN_vec and NORM_vec are not passed into the function they are calculated by the function
//if AN_vec and NORM_vec were previously calculated, pass them 
//as an argument of the function to prevent the redundant calculations
function getPEvec{
    parameter o is obt,
    NORM_vec is getNormVec(o),
    AN_vec is getANvec(o).    
    local PE_vec is angleAxis(-o:argumentofperiapsis, NORM_vec)*AN_vec.
    return PE_vec.
}

//get prograde vector of an orbitable
//funcion accepts orbit or an orbitable as a parameter
function getProgVec{
    parameter o is ship.
    local PROG_vec is o:velocity:orbit.
    return PROG_vec.
}

//get radial vector of an orbitable
//funcion accepts orbit or an orbitable as a parameter
//TODO: Radial vector function is incorrect in the current state
function getRadVec{
    parameter o is ship.
    local RAD_vec is o:body:position - o:position.
    return RAD_vec.
}

//rotate vector around another vector by theta degrees
//the direction of the rotation is defined by the right hand rule
//NOTE: rotateAroundAxis function is obsolete,
//use angleAxis(angle, vector) built-in function instead
function rotateAroundAxis{
    parameter a, b, theta.
    //coefficints
    local c1 is sin(theta)/b:mag.
    local c2 is (1-cos(theta))/b:sqrmagnitude.
    //initial matrix
    local L is list(   0,      b:z,    -b:y,
                        -b:z,   0,      b:x,
                        b:y,    -b:x,   0 ).
    //identity matrix
    local I is list(    1,  0,  0,
                        0,  1,  0,
                        0,  0,  1).
    //rotation matrix
    local R is matrixAdd(matrixAdd(I, matrixMultiply(L, c1)), matrixMultiply(matrixMultiply(L, L), c2)). //{[I] + sin(theta)/d * [L] + (1-cos(theta))/d^2 * ([L]x[L])}

    //return a x [R].
    return v(   R[0]*a:x + R[1]*a:y + R[2]*a:z,
                R[3]*a:x + R[4]*a:y + R[5]*a:z,
                R[6]*a:x + R[7]*a:y + R[8]*a:z).


}

//matrix multiplication 
//both matrices are 3x3 composed in one dimentional list
//NOTE: matrix math functions are obsolete
function matrixMultiply{
    parameter m1, m2.
    local result is list().
    if m1:isType("List") and m2:isType("List"){
        for i in range(9){
            local j is floor(i/3)*3.
            local k is mod(i, 3).
            local value is m1[j]*m2[k] + m1[j+1]*m2[k+3] + m1[j+2]*m2[k+6].
            result:add(value).
        }
    }
    //scalar multiplication
    else{
        local k is m2.
        if m2:isType("List"){
            set k to m1.
            set m1 to m2.
        }
        for i in range(9){
            result:add(m1[i]*k).
        }
    }
    return result.
}

//matrix addition
//both matrices are 3x3 composed in one dimentional list
//NOTE: matrix math functions are obsolete
function matrixAdd{
    parameter m1, m2.
    local result is list().
    for i in range(min(m1:length, m2:length)){
        result:add(m1[i]+m2[i]).
    }
    return result.
}

//matrix addition
//both matrices are 3x3 composed in one dimentional list
//NOTE: matrix math functions are obsolete
function matrixSub{
    parameter m1, m2.
    local result is list().
    for i in range(min(m1:length, m2:length)){
        result:add(m1[i]-m2[i]).
    }
    return result.
}

//get state vectors, relative position and velocity vector
//of an orbit at the true anomaly
//based on https://downloads.rene-schwarz.com/download/M001-Keplerian_Orbit_Elements_to_Cartesian_State_Vectors.pdf
//TODO: implement calculations for hyperbolic orbits
function getStateVectors{
    parameter T_an,
    //parameter o accepts orbit and eccentricity
    //if eccentricity is used, semimajor and mass should be passed as well
    o is obt,
    input is anomType:a_true.
    local a is 0.       //semimajor axis
    local e is 0.       //eccentricity
    local aop is 0.     //argument of periapsis
    local lan is 0.     //longitude of the ascending node
    local i is 0.       //inclination
    local mu is 0.       //central body mu
    local E_an is 0.    //eccentric anomaly   
    if o:istype("Orbit"){
        set a to o:semimajoraxis.
        set e to o:eccentricity.
        set aop to o:argumentofperiapsis.
        set lan to o:lan.
        set i to o:inclination.
        set mu to o:body:mu.
    }
    else if o:istype("Lexicon"){
        set a to o:sma.
        set e to o:ecc.
        set aop to o:aop.
        set lan to o:lan.
        set i to o:i.
        set mu to o:body:mu.
    }
    if input = anomType:a_true{
        set E_an to ano_t2e(T_an, e).
    }
    else if input = anomType:a_mean{
        set E_an to ano_m2e(T_an, e).
        set T_an to ano_e2t(E_an, e).
    }
    else if input = anomType:a_ecce{
        set E_an to T_an.
        set T_an to ano_e2t(E_an, e).
    }
    local r is radiusAtAnomaly(T_an, lex("ecc", e, "sma", a)).
    local c is sqrt(mu*a)/r.
    local pos is r*V(cos(T_an), 0, sin(T_an)).
    local vel is c*V(-sin(E_an), 0, sqrt(1-e^2)*cos(E_an)).
    //rotate vectors in a frame of reference of the central body
    //using aop, lan and inclination
    local an is solarPrimeVector*R(0, -lan, 0).
    local norm is v(0, 1, 0)*angleAxis(-i, an).
    local rotToAn is rotatefromto(v(1,0,0), an).
    local rotIncl is angleAxis(-i, an).
    local rotAoP is angleAxis(-aop, norm).
    set pos to pos*rotToAn*rotIncl*rotAoP.
    set vel to vel*rotToAn*rotIncl*rotAop.
    return lex("pos", pos, "vel", vel).
}