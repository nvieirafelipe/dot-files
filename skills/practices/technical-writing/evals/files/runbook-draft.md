# Payment webhook runbook

## Symptoms

Webhooks from the payment provider stop arriving. Retries stop after 5 attempts and
the provider disables the endpoint after 24 hours of failures.

## Fix

Run `make replay` to resend the failed webhooks. First make sure the signing secret is
current, which is done by running `bin/rotate-secret`.

## Root cause

The load balancer drops requests larger than 1 MB.
