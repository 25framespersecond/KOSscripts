//library for loading files to ship memory

//global variable to define if should load into memory or run from archive
global RUNFROMARCHIVE is false.

//load itself to ship memory upon first run
compile("0:/mylib_libs.ks") to "1:/mylib_libs".

//libraries loading
//availability of the library on the archive volume is not checked
//deliberately to throw an exception if it does not exist
function load_lib{
    parameter name, reload is false.
    if not fileExists(name) or reload{
        local content is open("0:/"+name):readAll.
        local tempfile to create("0:/temp_"+name).
        print "Reading "+name+ "...".
        for line in content{
            //load any other libs that are required for current lib
            if line:contains("//"){
                local start is line:find("//").
                set line to line:substring(0, start).
            }
            if line:contains("runOncePath"){
                //find instances of " symbol indicating start and end of lib name
                local start is line:find(char(34)).
                local end is line:findLast(Char(34)).
                
                if end > start{
                    //load any dependancies
                    local lib is line:substring(start+1, end-start-1).
                    load_lib(lib).
                    
                }
                //change all instances of runOncePath to runOnceLib function
                set line to line:replace("runOncePath", "runOnceLib").
            }
            set line to line:trim().
            if line{
                //store edited file content to a temporary file and compile it
                tempfile:writeln(line).
            }   
        }
        print "Compiling "+name + "...".
        compile("0:/temp_"+name) to "0:/temp_compiled_"+name.
        local compiledfile is open("0:/temp_compiled_"+name).
        local filesize to min(compiledfile:size, tempfile:size).
        local vol is 1.
        list processors in all_processors.
        local saved is 0.
        until vol > all_processors:length{
            local spacelimit is 0.
            if vol = 1 set spacelimit to 4000.
            if volume(vol):freespace-filesize >= spacelimit{
                if tempfile:size < compiledfile:size{
                    print "Saving "+vol+":/libs/"+name+"...".
                    copyPath("0:/temp_"+name, vol+":/libs/"+name).
                    set saved to 1.
                    break.
                }
                else{
                    print "Saving "+vol+":/libs/"+name+"...".
                    copyPath("0:/temp_compiled_"+name, vol+":/libs/"+name).
                    set saved to 1.
                    break.
                }
            }
            else set vol to vol+1.
        }
        if not saved{
            print "!!! Not enough space to save "+name+" !!!".
        }
        
        deletePath("0:/temp_"+name).
        deletePath("0:/temp_compiled_"+name).
    } 
}

//substitute function to runOncePath
//TODE: handle other volumes with multiple cores
function runOnceLib{
    parameter name.
    local vol is fileExists(name).
    runOncePath(vol+":/libs/"+name).
}

//remove library from the ship memory
function unload_lib{
    parameter name.
    local vol is fileExists(name).
    if vol{
        deletePath(vol+":/libs/"+name).
    }
}

//checks if file exists on the internal volumes
function fileExists{
    parameter name.
    local vol is 1.
    list processors in all_processors.
    until vol > all_processors:length{
        if exists(vol+":/libs/"+name){
            return vol.
        }
        set vol to vol+1.
    }
    return false.
}