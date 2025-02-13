import { BarcodeDetector } from "barcode-detector/ponyfill";

const barcodeTest = async function () {
  // check supported formats
  const supportedFormats = await BarcodeDetector.getSupportedFormats();
  console.log(supportedFormats);

  const barcodeDetector = new BarcodeDetector({
    // make sure the formats are supported
    formats: ["qr_code"],
  });

  const imageFile = await fetch(
    "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=Hello%20world!",
  ).then((resp) => resp.blob());

  barcodeDetector.detect(imageFile).then(console.log);
}

export default {
  mounted() {
    console.log(this.el);
  }
}
