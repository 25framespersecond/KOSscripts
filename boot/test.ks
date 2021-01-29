core:part:getmodule("kOSProcessor"):doevent("Open Terminal").

//run library for running libraries
//#include mylib_libs
local lib is "mylib_libs".
if exists("1:/"+lib){
    runOncePath("1:/"+lib).
}
else{
    runOncePath("0:/"+lib).
}

//set runfromarchive variable
set RUNFROMARCHIVE to true.

//switch to 0.
load_lib("test").
runOnceLib("test").