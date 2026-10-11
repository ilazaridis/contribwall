// Print "x y w h name" for the wanted display, in top-left screen coordinates.
// With no name, prefer a second screen and fall back to the only one there is.
function run(argv) {
  ObjC.import("AppKit");
  var want = (argv[0] || "").toLowerCase();
  var screens = $.NSScreen.screens.js;
  var primaryHeight = screens[0].frame.size.height;
  var pick = -1;
  if (want) {
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].localizedName.js.toLowerCase().indexOf(want) >= 0) { pick = i; break; }
    }
  }
  if (pick < 0) pick = screens.length > 1 ? 1 : 0;
  var f = screens[pick].frame;
  return [
    Math.round(f.origin.x),
    Math.round(primaryHeight - (f.origin.y + f.size.height)),
    Math.round(f.size.width),
    Math.round(f.size.height),
    screens[pick].localizedName.js
  ].join(" ");
}
