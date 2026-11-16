---
type: llm
focus: trace
weight: 1
---

The report states that transport errors such as a refused connection are returned without a retry, although issue 140 says the receiver refused connections during the outage, and either recommends retrying them or marks the issue's requirement Partial or Missing because of them. A report that only asks whether they should be retried, or accepts the behavior, does not meet this expectation.
