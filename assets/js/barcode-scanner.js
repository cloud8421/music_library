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
    this.cameraPreview = this.el.querySelector("#camera-preview");
    const constraints = {
      audio: false,
      video: {
        width: 800, height: 600, facingMode: {
          ideal: "environment"
        }
      },
    };
    this.el.addEventListener("camera_request", () => {
      navigator.mediaDevices
        .getUserMedia(constraints)
        .then((mediaStream) => {
          console.debug("Camera access allowed")
          this.pushEventTo(this.el, "camera_allowed", {});
          this.cameraPreview.srcObject = mediaStream;
          this.cameraPreview.onloadedmetadata = () => {
            this.cameraPreview.play();
            this.scanInterval = window.setInterval(async () => {
              const barcodes = await barcodeDetector.detect(this.cameraPreview);
              if (barcodes.length <= 0) return;

              barcodes.forEach(barcode => {
                if (!detectedBarcodes.has(barcode.rawValue)) {
                  this.pushEventTo(this.el, "barcode_scanned", { number: barcode.rawValue });
                  detectedBarcodes.add(barcode.rawValue);
                };
              });
            }, 500)
          };
        })
        .catch((err) => {
          console.error(`${err.name}: ${err.message}`);
          this.pushEventTo(this.el, "camera_denied", {});
        });
    })

  },
  destroyed() {
    if (this.cameraPreview.srcObject) {
      this.cameraPreview.srcObject.getTracks().forEach(track => track.stop());
      window.clearInterval(this.scanInterval);
    }
  }
}
