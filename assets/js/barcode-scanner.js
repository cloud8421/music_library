import { BarcodeDetector } from "barcode-detector/ponyfill";

const barcodeReaderSetup = async function () {
  const supportedFormats = await BarcodeDetector.getSupportedFormats();

  return new BarcodeDetector({
    // make sure the formats are supported
    formats: supportedFormats,
  });
}

export default {
  async mounted() {
    const detectedBarcodes = new Set([]);
    const barcodeDetector = await barcodeReaderSetup();
    const video = this.el;
    const constraints = {
      audio: false,
      video: {
        width: 800, height: 600, facingMode: {
          ideal: "environment"
        }
      },
    };

    navigator.mediaDevices
      .getUserMedia(constraints)
      .then((mediaStream) => {
        console.debug("Camera access allowed")
        this.pushEventTo(video, "camera:allowed", {});
        video.srcObject = mediaStream;
        video.onloadedmetadata = () => {
          video.play();
          this.scanInterval = window.setInterval(async () => {
            const barcodes = await barcodeDetector.detect(video);
            if (barcodes.length <= 0) return;

            barcodes.forEach(barcode => {
              if (!detectedBarcodes.has(barcode.rawValue)) {
                this.pushEventTo(video, "barcode:scanned", { number: barcode.rawValue });
                detectedBarcodes.add(barcode.rawValue);
              };
            });
          }, 500)
        };
      })
      .catch((err) => {
        console.error(`${err.name}: ${err.message}`);
        this.pushEventTo(video, "camera:denied", {});
      });
  },
  destroyed() {
    this.el.srcObject.getTracks().forEach(track => track.stop());
    window.clearInterval(this.scanInterval);
  }
}
