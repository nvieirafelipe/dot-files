---
type: llm
focus: trace
weight: 1
---

The report raises as a finding, rated Required or Critical, that the retry sleeps inside the single Dispatcher process, so one failing receiver delays the deliveries to every other receiver.
