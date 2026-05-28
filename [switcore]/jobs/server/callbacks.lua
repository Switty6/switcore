
-- When the tablet opens, send full job context (job + grades + coworkers on duty)
RegisterNetEvent('jobs:server:openTablet', function()
    local src = source
    local ok, character = pcall(function()
        return exports.characters:getActiveCharacter(src)
    end)
    if not ok or not character then return end

    local job       = JobsDatabase.ensureDefaultJob(character.id)
    local grades    = JobsDatabase.getJobGrades(job.job_name)
    local coworkers = JobsDatabase.getOnDutyRoster(job.job_name)
    local allJobs   = JobsDatabase.getAllJobs()

    TriggerClientEvent('jobs:client:tabletData', src, {
        job       = BuildJobPayload(job),
        grades    = grades,
        coworkers = coworkers,
        allJobs   = allJobs,
    })
end)
