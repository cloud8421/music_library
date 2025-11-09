export default {
  mounted() {
    this.selectedIndex = -1; // -1 means search input is focused
    
    this.keydownHandler = (event) => {
      // Only handle keyboard navigation when the modal is open
      const modal = document.getElementById("universal-search-root");
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
        case "Escape":
          // Let the modal's built-in escape handling work
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

    // Move to next result or wrap to search input
    if (this.selectedIndex < results.length - 1) {
      this.selectedIndex++;
    } else {
      // Wrap back to search input
      this.selectedIndex = -1;
    }
    
    this.updateSelection();
  },

  navigateUp() {
    const results = this.getResultElements();
    
    if (results.length === 0) return;

    // Move to previous result or wrap to last result
    if (this.selectedIndex > -1) {
      this.selectedIndex--;
    } else {
      // Wrap to last result
      this.selectedIndex = results.length - 1;
    }
    
    this.updateSelection();
  },

  selectCurrentResult() {
    const results = this.getResultElements();
    
    if (this.selectedIndex >= 0 && this.selectedIndex < results.length) {
      const selectedResult = results[this.selectedIndex];
      // Trigger the click event on the result
      selectedResult.click();
    }
  },

  updateSelection() {
    const results = this.getResultElements();
    
    // Remove all aria-selected attributes
    results.forEach((result) => {
      result.removeAttribute("aria-selected");
    });

    if (this.selectedIndex === -1) {
      // Focus search input
      const searchInput = document.getElementById("universal-search-input");
      if (searchInput) {
        searchInput.focus();
      }
    } else if (this.selectedIndex >= 0 && this.selectedIndex < results.length) {
      // Mark selected result
      const selectedResult = results[this.selectedIndex];
      selectedResult.setAttribute("aria-selected", "true");
      
      // Scroll into view if needed
      selectedResult.scrollIntoView({
        block: "nearest",
        behavior: "smooth"
      });
    }
  },

  getResultElements() {
    // Get all result items with role="option"
    const modal = document.getElementById("universal-search-root");
    if (!modal) return [];
    
    return Array.from(modal.querySelectorAll('[role="option"]'));
  }
};
