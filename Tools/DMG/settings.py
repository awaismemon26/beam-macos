# dmgbuild settings for Beam's disk image (used by Tools/build-release.sh).
# Pass -D app=<path to Beam.app> -D background=<background .tiff>.
# Icon positions are in points from the window's top-left and must match Tools/DMG/DrawBackground.swift.
import os.path

app = defines["app"]  # noqa: F821 (provided by dmgbuild)
format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
background = defines["background"]  # noqa: F821
icon_locations = {os.path.basename(app): (175, 125), "Applications": (485, 125)}
window_rect = ((200, 120), (660, 440))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 96
text_size = 13
include_icon_view_settings = True
