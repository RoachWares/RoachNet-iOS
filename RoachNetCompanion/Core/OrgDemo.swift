import Foundation

/// Preview data for RoachClaw Org, shown in demo mode (`ROACHNET_DEMO_MODE=1`) and
/// used by the UI tests. Clearly sample content; never sent anywhere.
enum CompanionDemoOrg {
    static let me = """
    {"kind":"owner","userId":"user_owner","source":"demo","companies":[{"id":"co_demo","name":"Bunker Works","board":true,"role":"owner"}]}
    """

    static let json = """
    {"company":{"id":"co_demo","name":"Bunker Works","description":"Sample company for preview mode.","status":"active"},
     "issuesByStatus":{"backlog":3,"todo":2,"in_progress":2,"in_review":1,"done":9},
     "agentsByStatus":{"idle":2,"running":1},
     "pendingApprovals":2,"openIncidents":0,"runningRuns":1,"monthSpendCents":0,"companyBudgetCents":0,
     "recentActivity":[
       {"id":"act_1","actorType":"agent","action":"issue.updated","entityType":"issue","createdAt":"2026-10-09T13:20:00Z"},
       {"id":"act_2","actorType":"agent","action":"approval.requested","entityType":"approval","createdAt":"2026-10-09T13:05:00Z"},
       {"id":"act_3","actorType":"user","action":"agent.created","entityType":"agent","createdAt":"2026-10-09T12:40:00Z"}]}
    """

    static let approvals = """
    {"approvals":[
      {"id":"apr_demo_1","companyId":"co_demo","type":"hire_agent","status":"pending",
       "payload":{"name":"Field Researcher","role":"researcher","reason":"Two research issues are waiting with nobody assigned."},
       "requestedByAgentId":"agent_ceo","comments":[],"createdAt":"2026-10-09T13:05:00Z"},
      {"id":"apr_demo_2","companyId":"co_demo","type":"approve_ceo_strategy","status":"pending",
       "payload":{"title":"Q4 plan: offline maps first","summary":"Ship regional map packs before the library refresh."},
       "requestedByAgentId":"agent_ceo","comments":[],"createdAt":"2026-10-09T12:55:00Z"}]}
    """

    static let agents = """
    {"agents":[
      {"id":"agent_ceo","name":"Chief","role":"ceo","title":"CEO","status":"running"},
      {"id":"agent_eng","name":"Wrench","role":"engineer","title":"Engineer","status":"idle"},
      {"id":"agent_qa","name":"Sieve","role":"qa","title":"QA","status":"idle"}]}
    """
}
