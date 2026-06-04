
-- When the tablet opens, send full job context (job + grades + coworkers on duty)
Sw.SecureEvent('jobs:server:openTablet', {
    character = true,
    silent = true,
    rateLimit = { max = 10, window = 3000 },
}, function(ctx)
    local src       = ctx.source
    local character = ctx.character

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
