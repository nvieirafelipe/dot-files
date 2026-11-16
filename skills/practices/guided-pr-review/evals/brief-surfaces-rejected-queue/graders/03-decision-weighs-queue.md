---
type: llm
focus: trace
weight: 1
---

The report has a section about the design decision itself, apart from the findings and their fixes, that compares retrying in process with the durable queue, with gains and costs for each, and challenges the chosen option with a concrete failure, such as pending retries lost on a deploy or crash, or one failing receiver delaying every other delivery behind the single Dispatcher process.
