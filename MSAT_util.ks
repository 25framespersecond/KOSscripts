//MSAT library (Mission Screen And Telemetry updater) with some utility functions 
//print message, wait, noop etc.

runOncePath("MSAT").

//returns a sequence step with printMessage function
function MSATprint{
    parameter str, displayTime is 4, sound is false, force is false.
    return MSATStep("Print", {parameter mission. mission:printMessage(str, displayTime, sound, force). mission:next().}).
}

//returns a sequence step with no execution
function MSATnoop{
    return MSATStep("Do nothing", {parameter mission. }).
}

//returns a sequence step that executes a delegate function
//use string storeResult to store function return value to mission memory
//use string argKey to use mission memory as an argument (use memory key)
//note: if result argument is not used or invalid delegate function with 0 parameters is expected, otherwise - 1 parameter is expected
function MSATexecute{
    parameter delegate, storeResult is false, argKey is false.
    return MSATStep("Execute function", {
        parameter mission.
        local res is 0.
        if argKey {
            local arg is mission:readMem(argKey).
            set res to delegate:call(arg).
        }
        else set res to delegate:call().

        if storeResult{
            mission:storeMem(storeResult, res).
        }
        mission:next().
    }).
}

//returns a sequence step that waits for a defined amount of seconds
function MSATwait{
    parameter t.
    return MSATStep("Wait", {
        parameter mission.
        if t:isType("String") set t to mission:readMem(t).
        if (time:seconds - mission:startTime() >= t) mission:next().
    }).
}

//returns a sequence step that prints current or previous result
function MSATprintResult{
    parameter memKey, displayTime is 4, sound is false, force is false.
    return MSATStep("Print Result", {
        parameter mission.
        
        local res is mission:readMem(memKey).
        mission:printMessage(res, displayTime, sound, force).
        mission:next().
    }).
}

//warp and wait a defined amount of time in seconds
//if 't' is a string, use mission memory address 't' for time
function MSATwaitWarp{
    parameter t.

    //warp to launch
    local step1 is MSATStep("Warp to", {
        parameter mission.
        if t:isType("String") set t to mission:readMem(t).
        warpTo(time:seconds+t).
        mission:next().
    }).

    //wait untill launch time
    local step2 is MSATwait(t).

    return list(step1, step2).
}

//countdown and wait for a define number of seconds
//if 't' is a string, use mission memory address 't' for time
function MSATcountdown{
    parameter t.

    //countdown
    local step1 is MSATStep("Countdown", {
        parameter mission.
        if t:isType("String") set t to mission:readMem(t).
        local i is t.
        until i <= 0 {
            mission:printMessage(i, 1, "bop").
            set i to i-1.
        }
        mission:printMessage("Launch!", 1, "beep").
        mission:next().
    }).

    //wait for countdown
    local step2 is MSATwait(t).

    return list(step1, step2).
}