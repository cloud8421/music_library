import PullToRefresh from "pulltorefreshjs";

const SEARCH_ICON = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="ptr-icon"><path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" /></svg>`;

export default function initPullToSearch() {
  PullToRefresh.init({
    mainElement: "body",
    triggerElement: "body",
    instructionsPullToRefresh: " ",
    instructionsReleaseToRefresh: " ",
    instructionsRefreshing: " ",
    iconArrow: SEARCH_ICON,
    iconRefreshing: SEARCH_ICON,
    distThreshold: 60,
    distMax: 80,
    distReload: 50,
    shouldPullToRefresh() {
      return !window.scrollY;
    },
    onRefresh() {
      const btn = document.getElementById("universal-search-button");
      if (btn) btn.click();
    },
  });
}
