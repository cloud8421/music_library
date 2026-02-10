import Sortable from "sortablejs";

export default {
  mounted() {
    this.initSortable();
  },

  updated() {
    if (this.sortable) {
      this.sortable.destroy();
    }
    this.initSortable();
  },

  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  },

  initSortable() {
    this.sortable = Sortable.create(this.el, {
      animation: 150,
      handle: "[data-sortable-handle]",
      draggable: "[data-sortable-item]",
      ghostClass: "opacity-30",
      dragClass: "shadow-lg",
      onEnd: () => {
        const items = this.el.querySelectorAll("[data-sortable-item]");
        const recordIds = Array.from(items).map(
          (item) => item.dataset.recordId
        );

        const payload = { record_ids: recordIds };
        const setId = this.el.dataset.setId;
        if (setId) {
          payload.set_id = setId;
        }

        this.pushEvent("reorder", payload);
      },
    });
  },
};
