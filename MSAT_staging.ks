//MSAT library (Mission Screen And Telemetry updater) with functions related to staging

runOncePath("MSAT").

//returns a sequence step that does safe staging.
function MSATstage{
    return MSATStep("Stage", {
        parameter mission.
        if doSafeStaging(mission) mission:next().
    }).
}

//safe staging function
function doSafeStaging{
    parameter mission.
    if stage:ready {
        stage.
        mission:printMessage("Staging. Current stage: " + stage:number, 4, "beep").
        return true.
    }
}

//create step with auto staging
function MSATAutoStage{
    parameter name, func.

    local seq is MSATSequence().
    seq:append("Save Thrust", {
        parameter mission.
        mission:storeMem("stagethrust", ship:availablethrust).
        mission:next().
    }).

    seq:append(name, {
        parameter mission.
        func:call(mission).
        if (ship:availableThrust < (mission:readMem("stagethrust") - 10) or ship:availablethrust = 0 ){
            if not(stage:NUMBER){
                mission:printMessage("Autostaging stoped. Last stage reached.", 4, "error").
                mission:next().
            }
            doSafeStaging(mission).
            mission:storeMem("stagethrust", ship:availablethrust).
            mission:updateJSON().
        }
    }).

    seq:append("Clear Memory", {
        parameter mission.
        mission:eraseMem("stagethrust").
        mission:next().
    }).

    return seq:getSequence().
}