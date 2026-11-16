---
type: llm
focus: trace
weight: 1
---

The report has a section about the design decision itself, apart from the findings and their fixes, that compares retrying in process with the durable queue, with gains and costs for each, and challenges the chosen option with at least one of two concrete failures: pending retries lost on a deploy or crash, or one failing receiver delaying every other delivery behind the single Dispatcher process. A challenge that rests only on the retry window being shorter than the outage does not meet this expectation.
