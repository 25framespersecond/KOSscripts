//library for some utility functions that don't fall in any category

//wraper for function to get the execution time of the function
//ideally should be used without any recurring trigers,
//since triggers like vecDraw() updaters and WHEN/THEN statements update 
//every physics tick halting the execution of the main script
function func_exec_time{
    parameter func.
    local deltat is time:seconds.
    func().
    return time:seconds - deltat.
}