# Webhooks

Delivers events to the URLs our customers register. `Webhooks.Dispatcher` takes events
in the order they arrive and hands each to `Webhooks.Deliver`, one at a time.
