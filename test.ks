//file to test functions
//deletePath("1:/mission/").
//#include mylib_libs
//set RUNFROMARCHIVE to true.

runOncePath("MSAT").
runOncePath("MSAT_orbit").

//#include MSAT
//load_lib("MSAT_orbit").
//runOncePath("MSAT_orbit").


local seq is MSATSequence().

seq:append(MSATorbit(80000, 0)).

//wait until hasTarget.
//
//seq:append(MSATStep("Read input", {
//    parameter mission.
//    mission:readInput("Enter a number:", "number", "t_alt").
//    mission:next().
//})).
//
//seq:append(MSATStep("Calculate...", {
//    parameter mission.
//    local t_alt is mission:readMem("t_alt")+50.
//    mission:printMessage(t_alt, 6, "bop").
//    mission:next().
//})).
//seq:append(MSATwait(6)).
//
//seq:append(MSATStep("Read text", {
//    parameter mission.
//    local text is mission:readInput("Enter a text:").
//    mission:printMessage("Text entered: '" + text + "'", 6, "success").
//    mission:next().
//})).
////seq:append(MSATorbit(80000, target:orbit:inclination, target:orbit:lan)).
////seq:append(MSATStep("Clear Mem", {parameter mission. mission:clearMem(). mission:next().})).
////seq:append(MSATprint("pirate", 4, "pirate")).
seq:append(MSATnoop()).
local events is MSATSequence().
local miss is MSATMission("test", seq, events, MSATPredef:Suborbit).
miss:run().