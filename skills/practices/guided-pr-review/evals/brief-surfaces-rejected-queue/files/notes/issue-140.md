# #140: events are lost when a receiver is down

Opened 2026-09-30 by dana.

During a receiver's outage on 2026-09-29 we dropped 212 events. Its load balancer answered
503 for about 15 minutes, then refused connections for another 5. `Deliver` gives up on the
first failure, so every event in that window was lost.

## Comments

**lee, 2026-10-01:** We could write deliveries to a durable queue (a jobs table) and retry
from there. Retries would survive deploys and crashes.

**dana, 2026-10-02:** No new infrastructure this quarter. Let's retry in process: three
attempts, waiting 1 s and then 2 s. Only retry 5xx; a 4xx means the receiver rejected the
event and a retry won't change that.

**lee, 2026-10-02:** Fine for now. We revisit the queue if this isn't enough.
