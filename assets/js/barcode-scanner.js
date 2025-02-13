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
    const video = this.el;
    const constraints = {
      audio: false,
      video: { width: 800, height: 600 },
    };

    navigator.mediaDevices
      .getUserMedia(constraints)
      .then((mediaStream) => {
        console.debug("Camera access allowed")
        this.pushEventTo(video, "camera:allowed", {});
        console.log(mediaStream);
        video.srcObject = mediaStream;
        video.onloadedmetadata = () => {
          video.play();
        };
      })
      .catch((err) => {
        console.error(`${err.name}: ${err.message}`);
        this.pushEventTo(video, "camera:denied", {});
      });
  },
  destroyed() {
    this.el.srcObject.getTracks().forEach(track => track.stop());
  }
}
