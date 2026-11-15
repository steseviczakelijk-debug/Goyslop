# Goyslop

A bot that writes short-video scripts with Claude, renders them as 9:16 caption videos with
ffmpeg, and posts them to TikTok on a schedule through TikTok's official Content Posting API.

```
script (Claude) -> optional voiceover (ElevenLabs) -> video (ffmpeg) -> TikTok direct post
```

## Setup

Needs Python 3.10+ and `ffmpeg` (built with libass).

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env        # then fill it in
```

1. **Claude**: put an API key in `ANTHROPIC_API_KEY`.
2. **TikTok**: create an app at developers.tiktok.com, add the *Login Kit* and *Content Posting
   API* products, enable *Direct Post*, request the `video.publish` scope, and register the
   redirect URI from `config.yaml` (`http://localhost:8721/callback`). Put the client key and
   secret in `.env`.
3. Log in once: `.venv/bin/python -m slopbot auth` (add `--manual` on a machine with no browser:
   you open the link elsewhere and paste back the URL you land on).

## Use

```bash
.venv/bin/python -m slopbot make --script examples/script.json   # render only, no API keys needed
.venv/bin/python -m slopbot make      # write a script with Claude and render it
.venv/bin/python -m slopbot post      # make one video and post it
.venv/bin/python -m slopbot run       # keep posting on the schedule
.venv/bin/python -m slopbot status    # account info and next slot
```

Videos, scripts, the token and the history database live in `data/`.

### Marketing a game

1. Fill in the `game:` section of `config.yaml`. Scripts are told to claim only what is written
   there, so list real features, platforms, price and the call to action you want.
2. Drop gameplay clips into `footage/`. Each video plays a random stretch of a random clip,
   cropped to vertical, with the captions on top. Clip audio is not used.
3. Leave `tiktok.promotes_own_brand: true`. It turns on TikTok's "Your brand" disclosure, which
   is required when you promote your own product.

`config.yaml` also controls the tone, posts per day, active hours, video size, voice and
post privacy. The bot keeps a history of topics and tells Claude not to repeat them.

To keep it running, use any process supervisor, for example:

```bash
nohup .venv/bin/python -m slopbot run >> data/bot.log 2>&1 &
```

## Things to know

- **Posts are private until TikTok audits your app.** Unaudited apps can only post with
  `SELF_ONLY` visibility. After the audit, set `tiktok.privacy_level` to `PUBLIC_TO_EVERYONE`.
- **Posts are labelled as AI-generated** (`is_aigc`), which TikTok requires for this content.
- The bot uses only the official API with one account's own authorization. It does not automate
  the app or website, and is not meant for running many accounts.
- The TikTok client was written without access to the live API reference and has only been tested
  against mocks. Check the endpoints and the PKCE challenge format in `slopbot/tiktok.py` against
  TikTok's docs on the first real run.

## Tests

```bash
.venv/bin/pip install pytest && .venv/bin/python -m pytest tests
```
