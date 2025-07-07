export default {
  mounted() {
    const universalSearchButton = document.querySelector("#universal-search-button");

    document.addEventListener("keydown", (event) => {
      switch (event.key) {
        case "k":
          if (event.metaKey || event.ctrlKey) {
            event.preventDefault();
            universalSearchButton.click();
          }
          break;
        default:
          break;
      }
    });
  },
};
