// Additional math functions and constants
// for now it is only includes hyperbolic functions

//conversion radians to degrees
global CONST_toDeg is 180/constant:pi.

//conversion degrees to radians
global CONST_toRad is constant:pi/180.

//hyperbolic sin() input is in degrees
function sinh{
    parameter x.
    set x to x*CONST_toRad.
    local e is constant:e.
    return (e^x - e^(-x))/2.
}

//hyperbolic cos() input is in degrees
function cosh{
    parameter x.
    set x to x*CONST_toRad.
    local e is constant:e.
    return (e^x + e^(-x))/2.
}

//hyperbolic tan() input is in degrees. conversion is made in sinh and cosh functions
function tanh{
    parameter x.
    return sinh(x)/cosh(x).
}

//hyperbolic asin(), output is in degrees
function asinh{
    parameter x.
    return ln(x+sqrt(x^2+1))*CONST_toDeg.
}

//hyperbolic acos(), output is in degrees
function acosh{
    parameter x.
    return ln(x+sqrt(x^2-1))*CONST_toDeg.
}

//convert angle to 0..360 degrees
function clamp360{
    parameter x.
    set x to mod(x, 360).
    if x < 0{
        return x+360.
    }
    return x.
}

//convert angle to -180..180 degrees
function clamp180{
    parameter x.
    return clamp360(x+180) - 180.
}

//convert angle to a positive angle
function clampPos{
    parameter x.
    return choose clampPos(x+360) if x < 0 else x.
}

//count full circles (laps) in an angle
function countLaps{
    parameter x.
    local laps is floor(x/360).
    if x < 0 set laps to -(laps+1).
    return laps.
}

//limit value in range
function limit{
    parameter value, min, max.
    if value < min set value to min.
    else if value > max set value to max.
    return value.
}