---
type: llm
focus: trace
weight: 1
---

The review does not recommend opts[:notify] || true or Map.get(opts, :notify, true) as a safe rewrite of the notify default. If it suggests either, it warns that || turns an explicit notify: false into true, or that Map.get/3 returns an explicit notify: nil instead of true.
