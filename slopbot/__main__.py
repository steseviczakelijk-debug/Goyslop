"""Usage: python -m slopbot {auth,make,post,run,status}"""
from __future__ import annotations

import argparse

from . import bot
from .config import load_config
from .store import Store
from .tiktok import TikTok


def main() -> None:
    p = argparse.ArgumentParser(prog="slopbot", description="Generate short videos and post them to TikTok.")
    p.add_argument("--config", help="path to config.yaml")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("auth", help="log in to TikTok (one time)")
    a.add_argument("--manual", action="store_true", help="paste the redirect URL instead of running a local server")
    for name, text in (("make", "generate and render one video, without posting"), ("post", "generate, render and post one video")):
        s = sub.add_parser(name, help=text)
        s.add_argument("--script", help="use a script JSON file instead of calling Claude")
    sub.add_parser("run", help="keep posting on the schedule in config.yaml")
    sub.add_parser("status", help="show TikTok account info and today's count")
    args = p.parse_args()
    cfg = load_config(args.config)

    if args.cmd == "auth":
        TikTok(cfg).login(manual=args.manual)
    elif args.cmd == "make":
        bot.make_video(cfg, Store(), bot.load_script(args.script) if args.script else None)
    elif args.cmd == "post":
        bot.post_once(cfg, Store(), bot.load_script(args.script) if args.script else None)
    elif args.cmd == "run":
        bot.run_forever(cfg)
    elif args.cmd == "status":
        info = TikTok(cfg).creator_info()
        print(f"Account: @{info.get('creator_username')}")
        print(f"Privacy options: {info.get('privacy_level_options')}")
        print(f"Next slot: {bot.next_slot(cfg, Store()):%Y-%m-%d %H:%M}")


if __name__ == "__main__":
    main()
