#!/usr/bin/env python3
"""Send key presses to the emulator's X display via XTEST.

usage: emu-keys.py [--display :99] KEY[:hold_ms] ...
KEY is a 3DS button name (a b x y l r start select up down left right)
mapped to Azahar's default keyboard bindings, or 'sleep:<ms>'.
"""
import sys, time
from Xlib import X, XK, display
from Xlib.ext import xtest

AZAHAR = {"a": "a", "b": "s", "x": "z", "y": "x", "l": "q", "r": "w",
          "start": "m", "select": "n",
          "up": "t", "down": "g", "left": "f", "right": "h"}

args = sys.argv[1:]
dpy_name = ":99"
if args and args[0] == "--display":
    dpy_name, args = args[1], args[2:]
d = display.Display(dpy_name)
for a in args:
    name, _, ms = a.partition(":")
    ms = int(ms) if ms else 120
    if name == "sleep":
        time.sleep(ms / 1000)
        continue
    code = d.keysym_to_keycode(XK.string_to_keysym(AZAHAR[name]))
    xtest.fake_input(d, X.KeyPress, code); d.sync()
    time.sleep(ms / 1000)
    xtest.fake_input(d, X.KeyRelease, code); d.sync()
    time.sleep(0.4)
