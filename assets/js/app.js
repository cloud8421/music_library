// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/music_library";
import topbar from "../vendor/topbar";
import { Hooks as FluxonHooks, DOM as FluxonDOM } from "fluxon";
import FormatNumberHook from "./hooks/format-number";
import UniversalSearchNavigationHook from "./hooks/universal-search-navigation";
import RecordPickerNavigationHook from "./hooks/record-picker-navigation";
import SortableListHook from "./hooks/sortable-list";
import confetti from "canvas-confetti";
import { createLiveToastHook } from "live_toast";
import banner from "./banner";

// the duration for each toast to stay on screen in ms
const duration = 4000

// how many toasts to show on screen at once
const maxItems = 3

const liveToastHook = createLiveToastHook(duration, maxItems)

let Hooks = FluxonHooks;
Hooks.FormatNumber = FormatNumberHook;
Hooks.UniversalSearchNavigation = UniversalSearchNavigationHook;
Hooks.RecordPickerNavigation = RecordPickerNavigationHook;
Hooks.SortableList = SortableListHook;
Hooks.LiveToast = liveToastHook;

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: (view) => {
    return {
      _csrf_token: csrfToken,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
    }
  },
  hooks: { ...Hooks, ...colocatedHooks },
  dom: {
    onBeforeElUpdated(from, to) {
      FluxonDOM.onBeforeElUpdated(from, to);
    },
  },
});

// Show progress bar on live navigation and form submits
topbar.config({
  barColors: { 0: "#FD4F00" },
  shadowColor: "rgba(0, 0, 0, .3)",
});
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());
window.addEventListener("music_library:clipcopy", (event) => {
  if ("clipboard" in navigator) {
    const text = event.target.textContent.trim();
    navigator.clipboard.writeText(text);
  } else {
    alert("Sorry, your browser does not support clipboard copy.");
  }
});
window.addEventListener("music_library:scroll_top", (_event) => {
  window.scrollTo(0, 0);
});
window.addEventListener("music_library:confetti", (_event) => {
  confetti({
    particleCount: 100,
    spread: 200,
  });
});
window.addEventListener("phx:music_library:download", (event) => {
  const { data, filename, content_type } = event.detail;
  const bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
  const blob = new Blob([bytes], { type: content_type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if (keyDown === "d") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

// Credit: https://andrewtimberlake.com/blog/2025/03/see-what-liveview-changes-are-being-made
window.enableLiveViewChangeObserver = () => {
  // Mutation observer to highlight changed elements
  return new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.type === "childList") {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            node.style.transition = "outline 0.3s ease-in-out";
            node.style.outline = "2px solid red";
            setTimeout(() => {
              node.style.outline = "none";
              node.style.transition = "";
            }, 1000);
          }
        });
      }
    });
  }).observe(document.body, {
    childList: true,
    subtree: true,
  });
};

banner();
