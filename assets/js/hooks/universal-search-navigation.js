import createNavigationHook from "./create-navigation-hook";

export default createNavigationHook({
  getContainer: () => document.getElementById("universal-search-root"),
  inputId: "universal-search-input"
});
