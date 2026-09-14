#!/usr/bin/env bash
# The glyphs, colours and limits the tab label and its notification are drawn
# with. Sourced by scripts/agent-status.sh and scripts/agent-spinner.sh; kept
# apart from them so the things anyone actually wants to change are not buried
# in the code that draws them.
#
# Plain shell variables rather than tmux options, for the reason the whole
# script is written the way it is: every option read is a round trip to the
# server, and this runs on a hook the harness allows five seconds. The few
# settings that are genuinely per-machine -- the notification sounds, which
# apps count as a terminal, @agent-notify off -- stay tmux options, because
# they are meant to be set from .tmux.conf.
#
# Every name below is read by the scripts that source this file, so to a linter
# reading it alone they all look unused.
# shellcheck disable=SC2034

# Per-agent marker, drawn before the state glyph so two harnesses running side
# by side are tellable apart at a glance. The marker keeps its own colour
# whatever the state is. One shade suffices because the active tab has a dark
# background too -- when it was light purple every glyph on it had to be
# darkened, and dark orange reads as maroon whatever its hue.
#
# Both harnesses draw the same robot: it is what an agent is, and the glyph was
# doing the same job as the colour twice over. The colour alone says which one,
# so it has to carry it -- codex in OpenAI's own green, claude in orange.
agent_glyph_codex='󰚩'
agent_colour_codex='#10a37f'
agent_glyph_default='󰚩'
agent_colour_default='#ff9e64'

# One glyph and one colour per state. 'idle' is an agent that is present but
# between turns: the harness marker alone, dimmed.
glyph_working=''; colour_working='#e0af68'
glyph_waiting=''; colour_waiting='#7dcfff'
glyph_done='';    colour_done='#9ece6a'
glyph_idle='';             colour_idle='#a9b1d6'

# Read off the theme at runtime; this is only what to fall back to when the
# option is unset -- Tokyo Night Storm's background.
active_fg_default='#24283b'

# How much of each string survives into the label and the banner. A banner
# shows four lines -- title, subtitle and two body lines -- and a wrapped body
# pushes the tail out of the collapsed form, which is where the git delta sits.
limit_prompt=90        # stored on the window when the turn starts
limit_prompt_notify=50 # the subtitle line
limit_reply=44         # the reply, which shares its line with an emoji
limit_ask=46           # what a 'waiting' agent is asking for

# Claude Code hands over a transcript rather than the reply, and only the last
# assistant block is wanted. Reading the whole file for it would be silly.
transcript_tail=400

# Detached runs for one window take turns under an mkdir lock: at most
# lock_tries * lock_wait seconds of waiting, and a lock held longer than
# lock_stale seconds is assumed abandoned rather than waited out.
lock_tries=60
lock_wait=0.05
lock_stale=10

# The spinner frames, and how long each one is shown.
#
# The dense braille set, not the common sparse one (0x280b 0x2819 ...). Braille
# occupies a 2x4 dot grid spanning the whole cell, so a frame that only lights
# the top dots renders high above the text baseline. Measured against 'M' in
# SauceCodePro at 64pt: sparse frames centre on y=29 against the text's y=50,
# while these centre on y=49. Every frame here also shares one bounding box, so
# the glyph does not jitter horizontally as it turns.
spinner_frames=(⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷)
spinner_interval=0.3

# Apps that count as "you can see the terminal", so a banner would be noise.
# Override with: tmux set -g @agent-notify-terminals 'iTerm2,Ghostty'
notify_terminals_default='iTerm2,iTerm,Ghostty,kitty,Terminal,Alacritty,WezTerm'

# Sounds, so 'finished' and 'needs you' are tellable apart without looking.
# Names come from /System/Library/Sounds or ~/Library/Sounds; 'none' silences
# one. Overridden with @agent-notify-sound-done / -waiting.
notify_sound_done_default=Glass
notify_sound_waiting_default=Ping
