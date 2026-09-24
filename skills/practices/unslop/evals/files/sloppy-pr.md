## Summary

This PR introduces a powerful new approach to handling retries in the notification
artifact pipeline — ensuring robust, seamless delivery.

I went ahead and refactored the retry logic. It's not just a retry, it's a resilience
layer. Retries now back off exponentially, which significantly improves reliability,
and they could potentially possibly help with the upstream timeouts too.

**Performance:** Performance improved.

## Why This Matters

So why does this matter? Because failed emails were dropped silently before.

## Out Of Scope

- Changing the queue provider
- Changing the email templates
- Changing the alerting thresholds
- Migrating old failed messages
- Adding metrics

## Conclusion

Overall, this change streamlines the landscape of our delivery system. Let me know if
you have any questions!

🤖 Generated with an AI assistant
