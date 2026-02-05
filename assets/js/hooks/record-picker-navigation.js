export default {
  mounted() {
    this.selectedIndex = -1; // -1 means search input is focused

    this.keydownHandler = (event) => {
      const modal = document.getElementById("record-picker-modal");
      if (!modal) return;

      switch (event.key) {
        case "ArrowDown":
          event.preventDefault();
          this.navigateDown();
          break;
        case "ArrowUp":
          event.preventDefault();
          this.navigateUp();
          break;
        case "Enter":
          if (this.selectedIndex >= 0) {
            event.preventDefault();
            this.selectCurrentResult();
          }
          break;
      }
    };

    document.addEventListener("keydown", this.keydownHandler);
  },

  updated() {
    // Reset selection when results change
    this.selectedIndex = -1;
    this.updateSelection();
  },

  destroyed() {
    if (this.keydownHandler) {
      document.removeEventListener("keydown", this.keydownHandler);
    }
  },

  navigateDown() {
    const results = this.getResultElements();

    if (results.length === 0) return;

    if (this.selectedIndex < results.length - 1) {
      this.selectedIndex++;
    } else {
      this.selectedIndex = -1;
    }

    this.updateSelection();
  },

  navigateUp() {
    const results = this.getResultElements();

    if (results.length === 0) return;

    if (this.selectedIndex > -1) {
      this.selectedIndex--;
    } else {
      this.selectedIndex = results.length - 1;
    }

    this.updateSelection();
  },

  selectCurrentResult() {
    const results = this.getResultElements();

    if (this.selectedIndex >= 0 && this.selectedIndex < results.length) {
      results[this.selectedIndex].click();

      if (this.selectedIndex === 0) {
        this.navigateDown();
      } else {
        this.naigateUp();
      }
    }
  },

  updateSelection() {
    const results = this.getResultElements();

    results.forEach((result) => {
      result.removeAttribute("aria-selected");
    });

    if (this.selectedIndex === -1) {
      const searchInput = document.getElementById("record-picker-search-input");
      if (searchInput) {
        searchInput.focus();
      }
    } else if (this.selectedIndex >= 0 && this.selectedIndex < results.length) {
      const selectedResult = results[this.selectedIndex];
      selectedResult.setAttribute("aria-selected", "true");

      selectedResult.scrollIntoView({
        block: "nearest",
        behavior: "smooth"
      });
    }
  },

  getResultElements() {
    const container = this.el;
    if (!container) return [];

    return Array.from(container.querySelectorAll('[role="option"]'));
  }
};
