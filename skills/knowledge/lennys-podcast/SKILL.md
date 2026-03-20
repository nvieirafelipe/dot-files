---
name: lennys-podcast
description: Searches Lenny's Podcast transcript archive for product management, growth, leadership, and startup insights from expert interviews. Use when seeking product advice, frameworks, or expert perspectives on topics like growth strategy, hiring, product-market fit, decision-making, or when the user mentions Lenny's Podcast.
---

STARTER_CHARACTER = 🎙️

# Lenny's Podcast Knowledge Base

269 episode transcripts from Lenny's Podcast — interviews with
product leaders, growth experts, and founders. Covers product
management, leadership, entrepreneurship, hiring, growth
strategy, experimentation, and more.

## Setup

The transcript archive must be cloned locally. Run the setup
script if not already available:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/setup.sh
```

The transcripts are stored at `~/lennys-podcast-transcripts/`.

## How to search

Transcripts are large (25,000+ tokens each). Never read a full
transcript without reason. Use targeted strategies:

### 1. Start with the topic index

Read [references/topic-index.md](references/topic-index.md) to
find which topics exist and how many episodes cover each. This
maps topics to guest episode links.

### 2. Grep for specific concepts

```bash
# Search across all transcripts
grep -r "product.market fit" ~/lennys-podcast-transcripts/episodes/

# Search with context for richer understanding
grep -r -C 5 "north star metric" ~/lennys-podcast-transcripts/episodes/
```

### 3. Read metadata before full transcripts

Each `transcript.md` starts with YAML frontmatter (lines 1-15)
containing guest name, title, date, duration, and keywords.
Read frontmatter first to decide if the episode is relevant:

```
Read file_path="~/lennys-podcast-transcripts/episodes/{guest}/transcript.md" limit=15
```

### 4. Read transcripts in chunks

When you need full context from a relevant episode:

```
Read file_path="..." offset=1 limit=500    # First chunk
Read file_path="..." offset=500 limit=500  # Next chunk
```

### 5. Use topic index files for episode lists

Each topic file (e.g., `~/lennys-podcast-transcripts/index/product-management.md`)
lists all episodes tagged with that topic, with links to
transcripts.

## Answering product questions

When the user asks a product/business question:

1. Identify the relevant topic(s) from the index
2. Grep for specific terms across episodes
3. Read frontmatter of top matches to pick best episodes
4. Read relevant sections of chosen transcripts
5. Synthesize insights, citing the guest and episode

Always attribute advice to the specific guest who said it.
Include the episode title when citing.

## Topic coverage

See [references/topic-index.md](references/topic-index.md) for
the full topic listing. Major areas include:

- **Product Management** (142 episodes) — PM skills, roadmaps,
  prioritization, metrics
- **Leadership** (73 episodes) — management, coaching,
  organizational design
- **Entrepreneurship** (52 episodes) — founding, scaling,
  fundraising
- **Product Strategy** (52 episodes) — vision, positioning,
  competitive strategy
- **Product Development** (46 episodes) — building, shipping,
  iteration
- **Career Development** (40 episodes) — growth, interviews,
  transitions
- **Growth Strategy** (33 episodes) — acquisition, retention,
  virality
- **AI** (27 episodes) — machine learning, ChatGPT, AI products
- **Startup Growth** (24 episodes) — early-stage, PMF, scaling
- **Company Culture** (22 episodes) — values, remote work, teams

## Notable guests

Brian Chesky, Drew Houston, Fei-Fei Li, Marc Benioff, Tobi
Lütke, Dylan Field, Marty Cagan, Seth Godin, Jason Fried,
Elena Verna, Julie Zhuo, Shreyas Doshi, Gibson Biddle, Kim
Scott, Matt Mochary, Casey Winters, and 240+ more.
