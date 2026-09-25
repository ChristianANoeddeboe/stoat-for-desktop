import { contextBridge, ipcRenderer } from "electron";

// only the bundled server picker page gets to change the server
if (location.protocol === "data:") {
  contextBridge.exposeInMainWorld("serverPicker", {
    getState() {
      return ipcRenderer.invoke("getServerPickerState") as Promise<{
        current: string | null;
        official: string;
        forced: boolean;
        error: string | null;
      }>;
    },
    setServer(address: string) {
      return ipcRenderer.invoke("setServer", address) as Promise<string | null>;
    },
    retry() {
      return ipcRenderer.invoke("retryServer") as Promise<void>;
    },
  });
}
