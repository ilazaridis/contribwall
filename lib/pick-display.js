// Display helper for contribwall.
//
//   --list   one line per screen: index, name, size, "main"
//   <name>   "x y w h name" for the matching screen, in top-left coordinates
//
// With no name, prefer a second screen and fall back to the only one there is.
function run(argv) {
  ObjC.import("AppKit");
  var screens = $.NSScreen.screens.js;
  var primaryHeight = screens[0].frame.size.height;

  if (argv[0] === "--list") {
    return screens.map(function (screen, i) {
      var f = screen.frame;
      return [
        i + 1,
        screen.localizedName.js,
        Math.round(f.size.width) + "x" + Math.round(f.size.height),
        i === 0 ? "main" : ""
      ].join("\t");
    }).join("\n");
  }

  var want = (argv[0] || "").toLowerCase();
  var pick = -1;
  if (want) {
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].localizedName.js.toLowerCase().indexOf(want) >= 0) { pick = i; break; }
    }
  }
  if (pick < 0) pick = screens.length > 1 ? 1 : 0;
  var frame = screens[pick].frame;
  return [
    Math.round(frame.origin.x),
    Math.round(primaryHeight - (frame.origin.y + frame.size.height)),
    Math.round(frame.size.width),
    Math.round(frame.size.height),
    screens[pick].localizedName.js
  ].join(" ");
}
