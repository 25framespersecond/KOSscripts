//MSAT(U) - Mission, Screen And Telemetry Updater
//library for abstracting runmode functionality, screen updates and telemetry logging
//the code is based on Mission Runner by Kevin Gisi http://youtube.com/gisikw
//TODO: documentation

//name and version of the library
function MSATversion{
    return " MSAT v0.6.12".
}

//  +----------------------------------------------------------------------------+
//  |                         MISSION RUNNER CLASS                               |
//  +----------------------------------------------------------------------------+
//mission class runs mission sequence and repeatable events
function MSATMission{
    parameter p_name, p_seq is MSATSequence(), p_evn is MSATSequence(), p_screen is list(), p_tele is list().
    //Member variables
    local m_name is "".
    local m_sequence is list(). 
    local m_events is list().               //TODO: remove or rework the "events"
    local m_runmode is 0.
    local m_done is false.
    local m_input_read is false.
    local m_input is list().
    local m_start_time is time:seconds.     //time at the start of each sequence step
    local m_log_time is time:seconds.       //time at each telemetry log cycle
    local m_memory is lex().
    local m_json is "".                     //const
    local m_screen_data is list().
    local m_message_list is list().
    local m_message_time is time:seconds.   //time at a start of a last message
    local m_message_length is 0.            //the length of the last message
    local m_tele_data is list().
    local m_logfilename is "".
    local m_log_interval is 0.5.              //if m_log_interval = 0 -> logging turned off

    //----------------------------------------------------//
    //                    Data Types                      //
    //----------------------------------------------------//
    //#region datatypes
    //data table
    //#region lookup table
    local dataTypes is 
    lexicon("met",              lex("name", "MET",                  "units", "s",       "value", {return round(missionTime, 2).}),
            "mission",          lex("name", "Mission",              "units", "",        "value", {return m_name.}),
            "ship",             lex("name", "Ship",                 "units", "",        "value", {return shipName.}),
            "status",           lex("name", "Status",               "units", "",        "value", {return ship:status.}),
            "stage",            lex("name", "Stage",                "units", "",        "value", {return stage:number.}),
            "runmode",          lex("name", "Runmode",              "units", "",        "value", getRunmode@),
            "runmodename",      lex("name", "Runmode Name",         "units", "",        "value", getRunmodeName@),
            "body",             lex("name", "Body",                 "units", "",        "value", {return ship:body:name.}),
            "altitude",         lex("name", "Altitude",             "units", "m",       "value", {return round(altitude).}),
            "surfacespeed",     lex("name", "Surface Speed",        "units", "m/s",     "value", {return round(velocity:surface:mag, 1).}),
            "groundspeed",      lex("name", "Ground Speed",         "units", "m/s",     "value", {return round(ship:groundspeed, 1).}),
            "latitude",         lex("name", "Latitude",             "units", "deg",     "value", {return round(ship:latitude, 2).}),
            "longitude",        lex("name", "Longitude",            "units", "deg",     "value", {return round(ship:longitude, 2).}),
            "apoapsis",         lex("name", "Apoapsis",             "units", "m",       "value", {if obt:eccentricity < 1 return round(apoapsis). else return "-".}),
            "periapsis",        lex("name", "Periapsis",            "units", "m",       "value", {return round(periapsis).}),
            "eccentricity",     lex("name", "Eccentricity",         "units", "",        "value", {return round(obt:eccentricity, 2).}),
            "inclination",      lex("name", "Inclination",          "units", "deg",     "value", {return round(obt:inclination, 1).}),
            "lan",              lex("name", "LAN",                  "units", "deg",     "value", {return round(obt:lan, 1).}),
            "aop",              lex("name", "Argument of periapsis","units", "deg",     "value", {return round(obt:argumentofperiapsis, 1).}),
            "velocity",         lex("name", "Velocity",             "units", "m/s",     "value", {return round(velocity:orbit:mag, 1).}),
            "bearing",          lex("name", "Bearing",              "units", "deg",     "value", {return round(ship:bearing, 1).}),
            "heading",          lex("name", "Heading",              "units", "deg",     "value", {return round(ship:heading, 1).}),
            "mass",             lex("name", "Mass",                 "units", "t",       "value", {return round(ship:mass, 2).}),
            "maxthrust",        lex("name", "Max Thrust",           "units", "kN",      "value", {return round(ship:maxthrust, 2).}),
            "availablethrust",  lex("name", "Available Thrust",     "units", "kN",      "value", {return round(ship:availablethrust, 2).}),
            "availablethrust_q",lex("name", "Available Thrust(atm)","units", "kN",      "value", {return round(ship:availablethrustat(ship:q), 2).}),
            "throttle",         lex("name", "Throttle",             "units", "%",       "value", {return round(throttle, 2)*100.}),
            "pressure",         lex("name", "Pressure",             "units", "ATM",     "value", {return round(ship:q, 1).}),
            "etaapo",           lex("name", "Time to Apoapsis",     "units", "s",       "value", {if obt:eccentricity < 1 return round(ETA:apoapsis). else return "-".}),
            "etaperi",          lex("name", "Time to Periapsis",    "units", "s",       "value", {return round(ETA:periapsis).}),
            "etanode",          lex("name", "Time to Maneuver Node","units", "s",       "value", {if hasNode return round(nextnode:eta). else return "-".}),
            "electric",         lex("name", "Electric Charge",      "units", "%",       "value", {for r in ship:resources if r:name = "ELECTRICCHARGE" return round(r:amount/r:capacity, 2)*100. return "-".}),
            "liquid",           lex("name", "Liquid Fuel",          "units", "%",       "value", {for r in ship:resources if r:name = "LIQUIDFUEL" return round(r:amount/r:capacity, 2)*100. return "-".}),
            "solid",            lex("name", "Solid Fuel",           "units", "%",       "value", {for r in ship:resources if r:name = "SOLIDFUEL" return round(r:amount/r:capacity, 2)*100. return "-".}),
            "monoprop",         lex("name", "Monopropelant",        "units", "%",       "value", {for r in ship:resources if r:name = "MONOPROP" return round(r:amount/r:capacity, 2)*100. return "-".}),
            "xenon",            lex("name", "Xenon",                "units", "%",       "value", {for r in ship:resources if r:name = "XENON" return round(r:amount/r:capacity, 2)*100. return "-".}),
            "freespace",        lex("name", "Core File Space",      "units", "%",       "value", {return round(core:volume:freespace/core:volume:capacity, 3)*100.})
            ).
    //#endregion lookup table
    //#endregion datatypes

    //Constructors
    defaultConstructor().

    //Methods declaration
    //#region methods declarations
    //public:
    local public_methods is lex(
        "run",              run@,               //void run();
        "updateJSON",       updateJSON@,        //void updateJSON();
        "setSequence",      setSequence@,       //void setSequence(MSATSequence seq, bool reset);
        "setEvents",        setEvents@,         //void setEvents(MSATSequence evn);
        "reset",            reset@,             //void reset();
        "setLogInterval",   setLogInterval@,    //void setLogInterval(double time);
        "getRunmode",       getRunmode@         //int getRunmode();
    ).
    //private:
    //private methods are passed as an object to the step delegate functions of the sequence
    //used to control the sequence flow through the delegates
    local private_methods is lex(
        "next",             next@,              //void next(bool keepResult);
        "storeMem",         storeMem@,          //void storeMem(string key, Object obj);
        "readMem",          readMem@,           //Object readMem(string key);
        "eraseMem",         eraseMem@,          //void eraseMem(string key);
        "clearMem",         clearMem@,          //void clearMem();
        "startTime",        startTime@,         //froat startTime();
        "updateJSON",       updateJSON@,        //void updateJSON();
        "readInput",        readInput@,         //void readInput(string promt, string key);
        "getRunmode",       getRunmode@,        //int getRunmode();
        "setRunmode",       setRunmode@,        //void setRunmode(int runmode, bool keepResult);
        "getRunmodeName",   getRunmodeName@,    //string getRunmodeName();
        "gotoStep",         gotoStep@,          //void gotoStep(string name, bool keepResult);
        "terminate",        terminate@,         //void terminate(string message);
        "defineScreenData", defineScreenData@,  //void defineScreenData(MSATData screenData);
        "defineTeleData",   defineTeleData@,    //void defineTeleData(MSATData teleData);
        "setLogInterval",   setLogInterval@,    //void setLogInterval(double time);
        "printMessage",     printMessage@,      //void printMessage(String message, float displayTime, bool forceDisplay);
        "addScreenData",    addScreenData@,     //void addScreenData(Lexicon data);
        "addTeleData",      addTeleData@,       //void addTeleData(Lexicon data);
        "removeScreenData", removeScreenData@,  //void removeScreenData(String name);
        "removeTeleData",   removeTeleData@     //void removeTeleData(String name);
    ).
    //#endregion methods declarations
    //----------------------------------------------------//
    //              Constructor definitions               //
    //----------------------------------------------------//
    //#region constructors
    function defaultConstructor{
        set m_name to p_name.
        set m_sequence to p_seq:getSequence().
        set m_events to p_evn:getSequence().
        set m_json to "1:/mission/" + m_name + "_runmode.json".
        set m_logfilename to "mission/log_" + m_name + ".csv".

        set m_runmode to 0.
        set m_start_time to time:seconds.

        if exists(m_json){
            //on the reload runmode, as well as previous and current step results are loaded from the json
            local l is readJson(m_json).
            set m_runmode to l:runmode.
            set m_start_time to l:startTime.
            set m_memory to l:memory.
            set m_input_read to l:input.
            defineScreenData(l:screen).
            defineTeleData(l:tele).
        }
        else {
            createTelemetryFile().
            defineScreenData(p_screen).
            defineTeleData(p_tele).
            updateJSON().
        }
    }
    //#endregion constructors

    //----------------------------------------------------//
    //                Method definitions                  //
    //----------------------------------------------------//
    //#region methods definitions

    //update json with runmode, starttime and stored memory
    //Note that some data is not stored in json
    function updateJSON{
        local state is lex().
        state:add("runmode", m_runmode).
        state:add("startTime", m_start_time).
        state:add("memory", m_memory).
        state:add("screen", m_screen_data).
        state:add("tele", m_tele_data).
        state:add("input", m_input_read).
    
        writeJson(state, m_json).
    }

    //Method to update mission sequence manualy
    function setSequence{
        parameter seq, res is true.

        set m_sequence to seq:getSequence().

        if res{
            reset().
        }
    }
    
    //Method to update mission events (actions repeating every loop cycle)
    function setEvents{
        parameter evn.
        
        set m_sequence to evn:getSequence().
    }

    //resets the runmode and the results, also, deletes json file
    function reset{
        set m_runmode to 0.
        set m_done to false.
        set m_start_time to time:seconds.
        clearMem().
        deletePath(m_json).
    }
    
    //execute next step in a sequence. 
    //Note: This method should be the last in the step delegate or imidiately followed by a 'return'.
    function next{
        setRunmode(m_runmode+1).
    }

    //set mission into input reading mode
    //pauses execution of the main sequence
    function readInput{
        parameter promt, filter is "text", key is false.
        terminal:input:clear().
        set m_input to list().
        clearMessage().
        if promt:length > 50 set promt to promt:substring(0, 50).
        set m_message_length to 100.
        print(promt) at(0, m_screen_data:length+3).
        print(char(9608)) at (0, m_screen_data:length+4).
        until false{
            if terminal:input:haschar{
                local ch is terminal:input:getChar().
                if ch = terminal:input:backspace {
                    if m_input:length > 0 {
                        m_input:remove(m_input:length-1).
                        print(char(9608) + " ") at (m_input:length, m_screen_data:length+4). //prints on the line 4 + number of screen data
                    }
                }
                else if ch = terminal:input:enter{
                    clearMessage().
                    local input is m_input:join("").
                    if filter = "number" set input to input:toscalar(0).
                    if key:istype("String"){
                        storeMem(key, input).
                    }
                    //break out of the loop and return input when enter is pressed
                    return input.
                }
                else if m_input:length < 49 and 
                    (filter = "text" or 
                    (filter = "number" and 
                        ((unchar(ch) >= 48 and unchar(ch) <= 57) or 
                        (ch = "." and m_input:find(".") = -1) or 
                        (ch = "-" and m_input:length = 0)))){
                    m_input:add(ch).
                    print(ch + char(9608)) at(m_input:length-1, m_screen_data:length+4).
                }
            }
            //update screen with current screen data
            updateScreen(). 
            //update telemetry file with telemetry data
            if (m_log_interval > 0 and time:seconds-m_log_interval > m_log_time) {
                updateTelemetry().
                set m_log_time to time:seconds.
            }
        }
        
    }

    //result getters and setters should never be used after "flow" methods: next(), setRunmode(), gotoStep() etc.
    //function setResult{
    //    parameter result.
    //    set m_curr_result to result.
    //    updateJSON().
    //}

    //get a result of the current step. May be useful to store and use result of each iteration
    //function getCurrResult{
    //    return m_curr_result.
    //}

    //get a result of previous step. Use this to pass variables to the next step in a sequence
    //function getPrevResult{
    //    return m_prev_result.
    //}

    //store a value in a memory
    function storeMem{
        parameter name, value.     

        //remove all of the spaces from the name
        name:replace(" ", "_").

        //set an existing memory or add a new one
        set m_memory[name] to value.
    }

    //read a value from a memory
    function readMem{
        parameter name.

        //remove all of the spaces from the name
        name:replace(" ", "_").
        
        if m_memory:haskey(name){
            return m_memory[name].
        }
        else{
            printMessage("An attemt to read memory at '"+name+"' address was mede. No memory at '"+name+"' exists.", 4, "warning").
            return "NULL".
        }
    }

    //erases a memory address
    function eraseMem{
        parameter name.

        //remove all of the spaces from the name
        name:replace(" ", "_").
        
        if m_memory:haskey(name){
            m_memory:remove(name).
        }
        else{
            printMessage("An attemt to erase memory at '"+name+"' address was mede. No memory at '"+name+"' exists.", 4, "warning").
        }
    }

    //clear all memory
    function clearMem{
        m_memory:clear().
    }

    //get the time at the start of the step (end of previous step)
    function startTime{
        return m_start_time.
    }

    //get current runmode value
    function getRunmode{
        return m_runmode.
    }

    //set runmode value
    //Note: This method should be the last in the step delegate or imidiately followed by a 'return'.
    function setRunmode{
        parameter mode.
        if mode >= m_sequence:length {
            terminate().
            return.
        }
        set m_runmode to mode.
        set m_start_time to time:seconds.
        updateJSON().
    }

    //get string name of the current runmode
    function getRunmodeName{
        return m_sequence[m_runmode]:name.
    }

    //change runmode to a value corresponding to a specific name
    //Note: This method should be the last in the step delegate or imidiately followed by a 'return'.
    function gotoStep{
        parameter name.
        local i is indexof(name, m_sequence).
        if i < 0 printMessage("Error: gotoStep(" + name + "). No step in a sequence named '" + name + "' exists.", 4, "warning").
        else{
            setRunmode(i).
        }
    }
    
    //terminate the main loop
    function terminate{
        set m_done to true.
        deletePath(m_json).
    }
    //#endregion methods definitions

    //----------------------------------------------------//
    //                     Main Loop                      //
    //----------------------------------------------------//
    //#region main loop
    function run{
        //if sequence is empty - terminate
        if m_sequence:length <= 0 terminate().
        set m_log_time to time:seconds.

        if m_runmode printMessage("Current runmode: " + m_runmode + "; Name: " + m_sequence[m_runmode]:name, 4, "success").
        //Main loop
        until m_done{
            m_sequence[m_runmode]:execute(private_methods).
            for rep in m_events{
                rep:execute(private_methods).   
            }
            //update screen with current screen data
            updateScreen().
            updateMessage(). 
            //update telemetry file with telemetry data
            if (m_log_interval > 0 and time:seconds-m_log_interval > m_log_time) {
                updateTelemetry().
                set m_log_time to time:seconds.
            }
        }
    }
    //#endregion main loop

    //----------------------------------------------------//
    //              Screen Updater Methods                //
    //----------------------------------------------------//
    //#region screen update
    //define screen data
    function defineScreenData{
        parameter data.
        m_screen_data:clear().
        if data:isType("List"){
            for d in data{
                addScreenData(d, false).
            }
        }
        else addScreenData(data, false).
        drawScreen().
    }

    //adds a data line to a screen
    function addScreenData{
        parameter data, update is true.
        if data:isType("List"){
            set data to lex("name", data[0], "units", data[1], "value", data[2]).
        }
        //do not add strings that are not present in dataTypes
        else if data:isType("String") and not dataTypes:haskey(data) return.

        m_screen_data:add(data).
        if update drawScreen().
    }

    //removes a data line from a screen
    function removeScreenData{
        parameter name.
        local i is indexof(name, m_screen_data).
        if i{
            m_screen_data:remove(i).
            drawScreen().
        }     
    }

    //draws a screen of the current screen data value for the first time
    function drawScreen{
        set terminal:width to 50.
        set terminal:height to m_screen_data:length + 10.
        clearScreen.
        print(MSATversion()) at(0, 0).  
        print("__________________________________________________") at(0, 1).
        local i is 0.
        until i >= m_screen_data:length{
            //shorten data name to 28 symbols and add ':'
            local name is "NO NAME".
            local units is "".
            //if data is string - read from dataTypes table, if data is lex - read from lex
            if m_screen_data[i]:isType("Lexicon"){
                set name to m_screen_data[i]:name.
                set units to m_screen_data[i]:units.
            }
            else if m_screen_data[i]:istype("String"){
                set name to dataTypes[m_screen_data[i]]:name.
                set units to dataTypes[m_screen_data[i]]:units.
            }
            if name:length > 28 set name to name:substring(0, 28).
            print(name+":") at(0, i+2).
            print("|") at(29, i+2).

            //shorten units name to 5 symbols and center in a 5 wide field
            if units:length > 5 set units to units:substring(0, 5).
            set units to units:padleft(round(2.4+0.5*units:length)). //round(2.4+0.5*units:length) returns the number of spaces to properly center units in 5 letter space
            set units to units:padright(5).
            print(units+"|") at(30, i+2).
            set i to i+1.
        }
        print("__________________________________________________") at(0, m_screen_data:length+2).
    }

    //screen updater function
    function updateScreen{
        local i is 0.
        until i >= m_screen_data:length{
            local value is "-".
            //if data is string - read from dataTypes table, if data is lex - read from lex
            if m_screen_data[i]:isType("Lexicon") and m_memory:haskey(m_screen_data[i]:value){
                set value to round(m_memory[m_screen_data[i]:value], 2):toString().
            }
            else if m_screen_data[i]:istype("String"){
                set value to dataTypes[m_screen_data[i]]:value():tostring().
            }
            if value:length > 13 set value to value:substring(0, 13).
            print value:padRight(13) at(37, i+2).
            set i to i+1.
        }    
    }

    //Print message at the end of the screen update for a defined time in seconds
    function printMessage{
        parameter str, display_time is 4, sound is false, force_display is false.
        m_message_list:add(lex("message", str, "time", display_time, "sound", sound, "force", force_display)).
    }

    function updateMessage{
        local i is 0.
        until i >= m_message_list:length{
            local msg is m_message_list[i].
            if msg:force = true {
                set m_message_time to time:seconds + msg:time.
                displayMessage(msg:message, msg:sound).
                m_message_list:remove(i).
                break.
            }
            set i to i+1.
        }
        if time:seconds > m_message_time{
            if m_message_list:length > 0 {
                local msg is m_message_list[0].
                set m_message_time to time:seconds + msg:time.
                displayMessage(msg:message, msg:sound).
                m_message_list:remove(0).
            }
            else{
                displayMessage().
            }
        
        }
    }

    //Displays the message at the end of the data screen
    function displayMessage{
        parameter str is "", sound is false.
        //play sound
        local v0 is getVoice(0).
        set v0:sustain to 0.3.
        local soundList is  lex("beep",     list(Note(494, 0.3), "sine"), 
                                "bop",      list(Note(294, 0.3), "sine"),
                                "alert",    list(list(Note(932, 0.4), slideNote(932, 698, 0.1), Note(698, 0.4), slideNote(698, 932, 0.1), Note(932, 0.4), slideNote(932, 698, 0.1), Note(698, 0.4)), "sine"), 
                                "warning",  list(list(Note(392, 0.3), Note(311, 0.3)), "triangle"),
                                "success",  list(list(Note(523, 0.1), Note(0, 0.1), Note(659, 0.1), Note(0, 0.1), slideNote(698, 784, 0.1), Note(784, 0.4)), "triangle"),
                                "error",    list(list(Note(98, 0.3), Note(0, 0.1), Note(98, 0.3)), "sawtooth"),
                                "noise",    list(Note(415, 0.5), "noise"),
                                "alarm",    list(list(Note(698, 0.1), Note(0, 0.2), Note(698, 0.1), Note(0, 0.2), Note(698, 0.1), Note(0, 0.2), Note(698, 0.1), Note(0, 0.2), Note(698, 0.1)), "sawtooth"),
                                "pirate",   list(list(Note(311,0.1), Note(0,0.1), Note(370,0.1), Note(0,0.1), Note(415,0.1), Note(0,0.3), Note(415,0.1), Note(0,0.3),
                                                      Note(415,0.1), Note(0,0.1), Note(466,0.1), Note(0,0.1), Note(494,0.1), Note(0,0.3), Note(494,0.1), Note(0,0.3),
                                                      Note(494,0.1), Note(0,0.1), Note(554,0.1), Note(0,0.1), Note(466,0.1), Note(0,0.3), Note(466,0.1), Note(0,0.3),
                                                      Note(415,0.1), Note(0,0.2), Note(370,0.1), Note(0,0.2), Note(370,0.1), Note(0,0.2), Note(415,0.1)), "triangle")
                                ).
        if sound and soundList:haskey(sound){
            set v0:wave to soundList[sound][1].
            v0:play(soundList[sound][0]).
        }
        //print message
        clearMessage().
        set m_message_length to str:toString():length.
        print(str) at(0, m_screen_data:length+3).
    }

    function clearMessage{
        local clear is "".
        set clear to clear:padleft(m_message_length).
        print(clear) at(0, m_screen_data:length+3).
    }

    //#endregion screen update

    //----------------------------------------------------//
    //            Telemetry Updater Methods               //
    //----------------------------------------------------//
    //#region telemetry update

    //creates telemetry file on mission object creation
    function createTelemetryFile{
        logTelemetry("Ship: " + shipName + ", Mission: " + m_name + ", time: " + time:seconds).
    }

    //defines the telemetry data
    function defineTeleData{
        parameter data.
        m_tele_data:clear().
        if data:isType("List"){
            for d in data{
                addTeleData(d, false).
            }
        }
        else addTeleData(data, false).
        writeTelemetryHeader().
    }

    //adds a data line to a telemetry logger
    function addTeleData{
        parameter data, update is true.
        if data:isType("List"){
            set data to lex("name", data[0], "value", data[1]).
        }
        //do not add strings that are not present in dataTypes
        else if data:isType("String") and not dataTypes:haskey(data) return.

        m_tele_data:add(data).
        if update writeTelemetryHeader().
    }

    //removes a data line from a telemetry logger
    function removeTeleData{
        parameter name.
        local i is indexof(name, m_tele_data).
        if i{
            m_tele_data:remove(i).
            writeTelemetryHeader().
        }  
    }

    //writes a header for current data into log
    function writeTelemetryHeader{
        local nameList is list().
        local i is 0.
        until i >= m_tele_data:length{
            local name is "NO NAME".
            //if data is string - read from dataTypes table, if data is lex - read from lex
            if m_tele_data[i]:isType("Lexicon"){
                set name to m_tele_data[i]:name.
            }
            else if m_tele_data[i]:istype("String"){
                set name to dataTypes[m_tele_data[i]]:name.
            }
            nameList:add(name).
            set i to i+1.
        }
        logTelemetry(namelist:join(",")).
    }

    //telemetry updater
    function updateTelemetry{
        local result is list().
        for data in m_tele_data{
            local value is "-".
            //if data is string - read from dataTypes table, if data is lex - read from lex
            if data:isType("Lexicon") and m_memory:haskey(data:value){
                set value to m_memory[data:value].
            }
            else if data:istype("String"){
                set value to dataTypes[data]:value().
            }
            result:add(value).
        }
        logTelemetry(result:join(",")).
    }

    //define interval between telemetry logging. interval = 0 turns logging off
    function setLogInterval{
        parameter interval.
        set m_log_interval to interval.
    }

    //function to log string to telemetry file based on the connection to the KSC
    function logTelemetry{
        parameter str.
        if homeConnection:isconnected{
            if exists("1:/"+m_logfilename) flushLogFile().
            log str to "0:/" + m_logfilename.
        }
        else if getFileSpace() >= 0.2{
            log str to "1:/" + m_logfilename.
        }
    }

    //calculate internal disc space
    function getFileSpace{
        return core:volume:freespace/core:volume:capacity.
    }

    //flushes the data from the internal disc drive to archive and removes the file
    function flushLogFile{
        if HOMECONNECTION:isconnected{
            local data is open("1:/"+m_logfilename):readall:string.
            log data to "0:/" + m_logfilename.
            deletePath("1:/"+m_logfilename).
        }
    }
    //#endregion telemetry update

    //#region helper functions
    //helper function to find an index of an element with a specific name
    function indexof{
        parameter name, seq_list.
        from {local i is 0.}
        until i > seq_list:length
        step {set i to i + 1.}
        do{
            if (seq_list[i] = name) or (seq_list[i]:hassuffix("name") and seq_list[i]:name = name) return i. 
        }
        return -1.
    }
    //#endregion helper functions

    return public_methods.
}



//Predefined MSATData lists
global MSATPredef is 
lex("Surface", list("ship", "status", "met", "groundspeed", "heading", "electric", "mass", "latitude", "longitude", "altitude", "pressure"),
    "Suborbit", list("ship", "runmode", "runmodename", "status", "met", "stage", "altitude", "apoapsis", "etaapo", "velocity", "inclination", "pressure", "mass", "throttle", "availablethrust_q", "freespace"),
    "Orbit", list("ship", "status", "met", "altitude", "body", "apoapsis", "periapsis", "inclination", "lan", "aop", "velocity", "mass", "availablethrust", "freespace")).



//  +----------------------------------------------------------------------------+
//  |                            SEQUENCE CLASS                                  |
//  +----------------------------------------------------------------------------+
//Sequence class is used to create and store mission sequence
function MSATSequence{
    parameter p_seq is false, p_deleg is {parameter mission. mission.}.
    //Member variables
    local m_sequence is list().

    //Constructors
    //#region constructors declaration
    if p_seq:isType("List"){
        listConstructor(p_seq).                 // MSATSequence(List sequence);
    }
    else if p_seq:isType("String"){
        stringConstructor(p_seq, p_deleg).
    }
    else if p_seq:isType("Lexicon"){
        if p_seq:hassuffix("type") and p_seq:type = "MSATSequence"{
            seqConstructor(p_seq).              // MSATSequence(MSATSequence seq);
        }
        else if p_seq:hassuffix("type") and p_seq:type = "MSATStep"{
            stepConstructor(p_seq).             // MSATSequence(MSATStep stp);
        }
    }
    //else default constructor                  // MSATSequence();
    //#endregion constructors declaration

    //Methods declaration
    //public:
    local public_methods is lex(
        "type",             "MSATSequence",     //type = MSATSequence
        "append",           append@,            //void append(MSATStp step); void append(List sequence);
        "getSequence",      getSequence@        //List getSequence();
    ).

    //----------------------------------------------------//
    //              Constructor definitions               //
    //----------------------------------------------------//
    //#region constructors definition
    //constructor from the list of steps
    function listConstructor{
        parameter listSeq.
        set m_sequence to listSeq.
    }

    //constructor from string and delegate function
    function stringConstructor{
        parameter name, deleg.
        stepConstructor(MSATStep(name, deleg)).
    }

    //constructor from another sequence
    function seqConstructor{
        parameter seq.
        set m_sequence to seq:getSequence().
    }

    //constructor from a single step
    function stepConstructor{
        parameter stp.
        m_sequence:add(stp).
    }
    //#endregion constructors definition

    //----------------------------------------------------//
    //                 Method definitions                 //
    //----------------------------------------------------//
    //#region method definitions
    //append list of steps or a single step to a sequence
    function append{
        parameter seq, deleg is {parameter mission. mission.}.
        if seq:isType("Lexicon"){
            //append another MSATSequence           
            if seq:hassuffix("type") and seq:type = "MSATSequence"{
                local listSeq is seq:getSequence().
                local i is 0.
                until i >= listSeq:length{
                    m_sequence:add(listSeq[i]).
                    set i to i+1.
                }
            }

            //append MSATStep
            else if seq:hassuffix("type") and seq:type = "MSATStep"{
                m_sequence:add(seq).
            }
        }
        else if seq:isType("String"){
            local stp is MSATStep(seq, deleg).
            m_sequence:add(stp).
        }
        else if seq:isType("List"){         //if argument is a list of steps - append the steps at the end of a sequence
            for elem in seq{
                m_sequence:add(elem).
            }
        }
    }

    //returns sequence
    function getSequence{
        return m_sequence.
    }
    //#endregion method definitions

    return public_methods.
}


//  +----------------------------------------------------------------------------+
//  |                              STEP STRUCT                                   |
//  +----------------------------------------------------------------------------+
//function that returns sequence step
//use it to create a step and add it to a sequence or event list
//      struct Stp{
//          string name;
//          func_pointer execute;   
//      }
function MSATStep{
    parameter p_name, p_execute.
    return lex("type", "MSATStep", "name", p_name, "execute", p_execute).
}