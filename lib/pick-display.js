// Display helper for contribwall.
//
//   --list [spec]   one line per screen: index, name, size, "main", "*" if chosen
//   [spec]          "x y w h name" for the chosen screen, in top-left coordinates
//
// A spec is a case-insensitive name fragment. Two monitors can carry the same
// name, so a "#2" suffix picks the second one that matches. An empty spec
// prefers a second screen and falls back to the only one there is.
function resolve(screens, spec) {
  var want = spec || "";
  var occurrence = 1;
  var suffix = want.match(/^(.*)#(\d+)$/);
  if (suffix) {
    want = suffix[1];
    occurrence = parseInt(suffix[2], 10) || 1;
  }
  want = want.toLowerCase();
  if (!want) return screens.length > 1 ? 1 : 0;

  var seen = 0;
  for (var i = 0; i < screens.length; i++) {
    if (screens[i].localizedName.js.toLowerCase().indexOf(want) >= 0) {
      seen++;
      if (seen === occurrence) return i;
    }
  }
  return -1;
}

function run(argv) {
  ObjC.import("AppKit");
  var screens = $.NSScreen.screens.js;
  if (!screens || screens.length === 0) {
    throw new Error("contribwall: no displays found -- is this a desktop session?");
  }
  var primaryHeight = screens[0].frame.size.height;

  if (argv[0] === "--list") {
    var chosen = resolve(screens, argv[1] || "");
    return screens.map(function (screen, i) {
      var f = screen.frame;
      return [
        i + 1,
        screen.localizedName.js,
        Math.round(f.size.width) + "x" + Math.round(f.size.height),
        i === 0 ? "main" : "",
        i === chosen ? "*" : ""
      ].join("\t");
    }).join("\n");
  }

  var pick = resolve(screens, argv[0] || "");
  if (pick < 0) pick = screens.length > 1 ? 1 : 0;   // named screen is unplugged
  var frame = screens[pick].frame;
  return [
    Math.round(frame.origin.x),
    Math.round(primaryHeight - (frame.origin.y + frame.size.height)),
    Math.round(frame.size.width),
    Math.round(frame.size.height),
    screens[pick].localizedName.js
  ].join(" ");
}
