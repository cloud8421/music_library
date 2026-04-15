import createNavigationHook from "./create-navigation-hook";

export default createNavigationHook({
  getContainer: (hook) => hook.el,
  inputId: "rule-picker-search-input",
  onSelect: (hook) => {
    if (hook.selectedIndex === 0) {
      hook.navigateDown();
    } else {
      hook.navigateUp();
    }
  }
});
