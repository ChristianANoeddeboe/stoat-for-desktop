import { IpcMainInvokeEvent, app, ipcMain, net } from "electron";

import { config } from "./config";
import { loadServer } from "./window";

// the official Stoat web app
export const OFFICIAL_SERVER = "https://stoat.chat/app";

// how long to wait for a server to respond when checking it
const CHECK_TIMEOUT_MS = 10_000;

// server passed on the command line, which overrides the saved one
const FORCED_SERVER = app.commandLine.hasSwitch("force-server")
  ? app.commandLine.getSwitchValue("force-server")
  : null;

/**
 * Turn user input like `stoat.example.com` into a full URL
 * @param input Address typed by the user
 * @returns URL, or null if the input is not a valid http(s) address
 */
export function normaliseServerUrl(input: string): URL | null {
  const trimmed = input.trim();
  if (!trimmed) return null;

  try {
    const url = new URL(
      /^[a-z][a-z0-9+.-]*:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`,
    );

    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    return url;
  } catch {
    return null;
  }
}

/**
 * Server the app should load, or null if the user has not picked one yet
 */
export function getServerUrl(): URL | null {
  return normaliseServerUrl(FORCED_SERVER ?? config.serverUrl);
}

/**
 * Check that a server serves a web page we can load
 * @param url Server URL
 * @returns Error message, or null if the server looks fine
 */
async function checkServer(url: URL): Promise<string | null> {
  try {
    const response = await net.fetch(url.toString(), {
      signal: AbortSignal.timeout(CHECK_TIMEOUT_MS),
    });

    if (!response.ok) {
      return `The server answered with HTTP ${response.status}.`;
    }

    if (!response.headers.get("content-type")?.includes("text/html")) {
      return "The server did not return a web page. Check the address.";
    }

    return null;
  } catch (err) {
    return `Could not reach the server (${
      err instanceof Error ? err.message : String(err)
    }).`;
  }
}

// currently shown picker error, if any
let pickerError: string | null = null;

/**
 * Remember why the server could not be loaded, for the server picker to show
 * @param error Error message, or null to clear it
 */
export function setServerPickerError(error: string | null) {
  pickerError = error;
}

/**
 * Whether an IPC call comes from the bundled server picker page
 * @param event IPC event
 */
function fromServerPicker(event: IpcMainInvokeEvent) {
  return event.senderFrame?.url.startsWith("data:") ?? false;
}

ipcMain.handle("getServerPickerState", () => ({
  current: getServerUrl()?.toString() ?? null,
  official: OFFICIAL_SERVER,
  forced: FORCED_SERVER !== null,
  error: pickerError,
}));

ipcMain.handle("setServer", async (event, input: string) => {
  if (!fromServerPicker(event)) return "Not allowed.";

  const url = normaliseServerUrl(input);
  if (!url) return "Enter a valid server address, like stoat.example.com.";

  const error = await checkServer(url);
  if (error) return error;

  config.serverUrl = url.toString();
  pickerError = null;
  loadServer();
  return null;
});

ipcMain.handle("retryServer", (event) => {
  if (!fromServerPicker(event)) return;

  pickerError = null;
  loadServer();
});
