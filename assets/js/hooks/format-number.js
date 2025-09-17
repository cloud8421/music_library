export default {
  mounted() {
    this.el.innerText = parseInt(this.el.innerText).toLocaleString();
  },
  updated() {
    this.el.innerText = parseInt(this.el.innerText).toLocaleString();
  }
}
