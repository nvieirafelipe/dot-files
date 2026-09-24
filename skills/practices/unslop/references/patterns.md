# Slop patterns

IDs are stable so review findings can cite them. A removed pattern leaves a gap in the
numbering; do not renumber.

Rewrites must use only supplied facts. When a clearer sentence requires missing
information, flag the gap instead of inventing a mechanism, number, or actor.

## Voice

**U1 First-person narration.** The tool reports what it did, not what it felt or meant
to do.
Before: "I went ahead and refactored the parser for you."
After: "Refactored the parser."

**U2 Chatbot phrases.** Openers and closers that carry no information.
Before: "Certainly! Here's the updated config. I hope this helps, let me know if you
need anything else!"
After: "Updated config:"

**U3 Sycophancy.** Praise for the question or agreement before the answer.
Before: "Great question! You're absolutely right that the cache is stale."
After: "The cache is stale."

**U4 Canned introduction.** A first sentence that announces the document instead of
starting it.
Before: "This PR introduces a new approach to handling retries."
After: "This PR changes retry handling."

## Words

**U5 Invented noun.** A coined name for an ordinary thing.
Before: "The notification artifact is persisted to the delivery layer."
After: "The email is saved to the delivery layer."
Use "email" only when context establishes what the artifact is.

**U6 Banned or inflated word.** The banned list in SKILL.md, plus `additionally`,
`enhance`, `foster`, `garner`, `interplay`, `intricate`, `showcase`, `underscore`,
`vibrant`, `numerous`.
Before: "This change enhances and underscores the robust interplay between services."
After: "UNVERIFIED: The effect on service interactions is unspecified."

**U7 Fancy way to say "is" or "has".** "serves as", "stands as", "boasts", "features".
Before: "The worker serves as the entry point and boasts three queues."
After: "The worker is the entry point and has three queues."

**U8 Marketing register.** Claims of quality instead of facts.
Before: "A powerful, streamlined way to manage secrets."
After: "Manages secrets."

**U9 Abstract metaphor noun.** Words that sound technical but have a plainer
equivalent: substrate, wedge, vector, locus, nexus, primitive (as a noun), surface (as in
"API surface"), bedrock, paradigm, modality, north star, flywheel, endgame, ratchet (as a
metaphor), evacuate (for moving code).
Before: "Wedge the check into the ingestion substrate."
After: "Add the check to the importer."

**U10 Synonym cycling.** One thing under several names in the same text.
Before: "The gate rejects the build. The ratchet then records the budget check."
After: "The budget check rejects the build and records its result."
Use one name only when context confirms these are the same component.

**U11 Filler phrase.** "due to the fact that" is "because". "in the event that" is "if".
"It is important to note that" is nothing.
Before: "It is important to note that, due to the fact that the token expires, requests
fail."
After: "Requests fail because the token expires."

## Claims

**U12 Vague attribution.** "Experts believe", "Industry reports suggest", "Some argue".
Name the source or delete the sentence.
Before: "It is widely considered best practice to pin versions."
After: "UNVERIFIED: Pinning versions is recommended; the source is unspecified."

**U13 Superficial "-ing" phrase.** A trailing clause that asserts significance without
evidence: "highlighting…", "ensuring…", "reflecting…", "showcasing…".
Before: "The job runs hourly, ensuring data freshness."
After: "The job runs hourly."

**U14 Stacked hedging.** Several qualifiers where one is accurate.
Before: "This could potentially possibly cause issues."
After: "This may cause issues."

**U15 Feeling instead of mechanism.** A sentence that names how something feels. Name
the mechanism or the number.
Before: "Types that follow your schema."
After: "UNVERIFIED: How the types correspond to the schema is unspecified."

## Structure

**U16 Padding to three.** A list forced to three items.
Before: "Fast, reliable, and maintainable."
After: "UNVERIFIED: Performance, reliability, and maintenance claims lack evidence."

**U17 "Not X, but Y" framing.** A contrast against a claim nobody made.
Before: "It's not just a cache, it's a consistency layer."
After: "UNVERIFIED: The cache's consistency behavior is unspecified."

**U18 Pre-answered objection.** "It is worth noting that…", "One might ask whether…",
"You might be wondering…". State the point.

**U19 Rhetorical question then answer.**
Before: "So why does this matter? Because deploys block on it."
After: "Deploys block on this check."

**U20 Generic conclusion.** "In summary…", "Overall, this improves…", "The future
looks bright." Delete it or state the specific next step.

**U21 False range.** "From X to Y" where X and Y are not ends of a scale.
Before: "Covers everything from logging to billing."
After: "Covers logging and billing."

## Sentences

**U22 Dense sentence.** The reader must backtrack. Split it or drop clauses.
Before: "Running with --write, which updates the committed budget to reflect the current
count, should only be done when lowering it."
After: "Run `--write` only to lower the budget. It overwrites the committed count."

**U23 Passive voice hiding the actor.** Name the actor when responsibility matters.
Before: "Queries are validated before execution."
After: "Queries are validated before execution. UNVERIFIED: The actor is unspecified."
Name the actor only when the supplied context establishes it.

**U24 Adverb propping a weak verb.** Use the stronger verb or the number.
Before: "Significantly improves startup."
After: "UNVERIFIED: Startup improvement has not been quantified."

**U25 Mannered prose.** Aphorisms, personified code, figurative verbs.
Before: "The plan holds the lock and the flag rides along."
After: "The plan keeps the lock. The flag is passed with it."

**U26 Over-compression.** Dropped articles, verbless fragments, arrows, and
abbreviations in an artifact.
Before: "Parser rejects bad date → exit 2, no write."
After: "The parser rejects a bad date, exits with code 2, and writes nothing."

**U27 Ambiguous pronoun.** "it", "this", or "they" that can point at more than one
thing. Repeat the noun.
Before: "The client calls the proxy. If it times out, retry."
After: "The client calls the proxy. UNVERIFIED: Clarify which component's timeout
triggers a retry."

## Formatting

**U28 Em dash.** Replace with a colon, comma, parenthesis, or full stop.
Before: "The job failed — the token had expired."
After: "The job failed: the token had expired."

**U29 Inline-header list.** A bold label and colon that repeat the line after them.
Before: "**Performance:** Performance improved by 40%."
After: "Performance improved by 40%."
A bold lead-in that names the item and adds new detail is fine.

**U30 Bold overuse.** Bold on every product name or term. Keep bold for navigation.

**U31 Title-case heading.** Use sentence case.
Before: "## Configuring The Retry Policy"
After: "## Configure the retry policy"

**U32 Decorative emoji.** Remove from headings and bullets. Keep functional markers such
as a skill's `STARTER_CHARACTER`.

**U33 Vague link text.**
Before: "Click [here](/link) to learn more."
After: "Read the [writing style guide](/link)."

Sources for these patterns are listed in [sources.md](sources.md).
