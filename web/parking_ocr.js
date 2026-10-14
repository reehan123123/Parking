(function () {
  'use strict';

  const ocrAssetRoot = 'ocr-v1';
  const operations = new Map();
  let nextOperationId = 0;
  let runtimePromise = null;

  function assetUrl(path) {
    return new URL(path, document.baseURI).toString();
  }

  function ocrAssetUrl(path) {
    return assetUrl(`${ocrAssetRoot}/${path}`);
  }

  function loadRuntime() {
    if (window.Tesseract) {
      return Promise.resolve(window.Tesseract);
    }

    if (runtimePromise) {
      return runtimePromise;
    }

    runtimePromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.async = true;
      script.src = ocrAssetUrl('tesseract.min.js');
      script.onload = () => {
        if (window.Tesseract) {
          resolve(window.Tesseract);
          return;
        }

        reject(new Error('The local OCR runtime did not initialize.'));
      };
      script.onerror = () => {
        reject(new Error('The local OCR runtime could not be loaded.'));
      };
      document.head.appendChild(script);
    }).catch((error) => {
      runtimePromise = null;
      throw error;
    });

    return runtimePromise;
  }

  function abortError() {
    return new DOMException('OCR was cancelled.', 'AbortError');
  }

  function base64ToBytes(value) {
    const binary = atob(value);
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) {
      bytes[index] = binary.charCodeAt(index);
    }
    return bytes;
  }

  function reportProgress(callback, message) {
    if (typeof callback !== 'function') {
      return;
    }

    const progress = Number.isFinite(message.progress) ? message.progress : 0;
    try {
      callback(
        JSON.stringify({
          status: message.status || '',
          progress,
        }),
      );
    } catch (_) {
      // Progress reporting must not interrupt OCR.
    }
  }

  async function terminateWorker(operation) {
    const worker = operation.worker;
    operation.worker = null;
    if (worker) {
      await worker.terminate();
    }
  }

  async function runOperation(operation, base64, mimeType, progressCallback) {
    const tesseract = await loadRuntime();
    if (operation.cancelled) {
      throw abortError();
    }

    const worker = await tesseract.createWorker('eng', 1, {
      workerPath: ocrAssetUrl('worker.min.js'),
      corePath: ocrAssetUrl('core'),
      langPath: ocrAssetUrl('lang'),
      logger: (message) => reportProgress(progressCallback, message),
    });
    operation.worker = worker;

    try {
      if (operation.cancelled) {
        throw abortError();
      }

      const blob = new Blob([base64ToBytes(base64)], {
        type: mimeType || 'image/jpeg',
      });
      const result = await worker.recognize(blob);
      if (operation.cancelled) {
        throw abortError();
      }

      return result.data.text || '';
    } finally {
      await terminateWorker(operation);
    }
  }

  function start(base64, mimeType, progressCallback) {
    const operation = {
      id: `ocr-${Date.now()}-${nextOperationId}`,
      worker: null,
      cancelled: false,
    };
    nextOperationId += 1;
    operations.set(operation.id, operation);

    operation.promise = runOperation(
      operation,
      base64,
      mimeType,
      progressCallback,
    ).finally(() => {
      operations.delete(operation.id);
    });

    return {
      id: operation.id,
      promise: operation.promise,
    };
  }

  function cancel(operationId) {
    const operation = operations.get(operationId);
    if (!operation) {
      return;
    }

    operation.cancelled = true;
    void terminateWorker(operation).catch(() => {});
  }

  window.ParkingOcr = {
    start,
    cancel,
  };
})();
