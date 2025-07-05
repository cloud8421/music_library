// Search hook for universal search functionality
const SearchHook = {
  mounted() {
    this.setupGlobalKeyboardShortcuts();
    this.setupSearchInputFocus();
  },

  updated() {
    this.setupSearchInputFocus();
  },

  setupGlobalKeyboardShortcuts() {
    // Add global keyboard event listener for Ctrl/Cmd + K
    document.addEventListener('keydown', (e) => {
      // Check for Ctrl+K (Windows/Linux) or Cmd+K (Mac)
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        // Send event to the universal search LiveView
        const searchContainer = document.getElementById('universal-search');
        if (searchContainer) {
          searchContainer.dispatchEvent(new CustomEvent('phx:open_modal', { 
            bubbles: true,
            detail: {}
          }));
        }
      }
    });
  },

  setupSearchInputFocus() {
    // Auto-focus search input when modal opens
    const searchInput = document.getElementById('universal-search-input');
    if (searchInput) {
      // Small delay to ensure modal is fully rendered
      setTimeout(() => {
        searchInput.focus();
      }, 100);
    }
  }
};

// Hook for search input with auto-focus
const SearchInputHook = {
  mounted() {
    this.el.focus();
  },

  updated() {
    // Maintain focus during updates
    if (document.activeElement !== this.el) {
      this.el.focus();
    }
  }
};

export { SearchHook, SearchInputHook };