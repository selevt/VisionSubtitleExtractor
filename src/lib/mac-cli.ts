import { Command } from "@tauri-apps/plugin-shell";
import { type ExtractOptions, type ExtractResult, type Backend, Capability } from "./backend-common";

interface MacCliOptions extends ExtractOptions {}
interface MacCliResult extends ExtractResult {}

export const macCliBackend: Backend = {
  capabilities: Capability.OPTION_INTERVAL | Capability.REGION_OF_INTEREST,

  roiFormat: () => "{leftRel} {bottomRel} {widthRel} {heightRel}",

  extract: async (options: MacCliOptions): Promise<MacCliResult> => {
    const { filePath, outputPath, intervalMs, roi } = options;
    const args: string[] = [filePath, "--output", outputPath];
    if (intervalMs) {
      // ms to seconds
      args.push("--interval", String(intervalMs / 1000));
    }
    if (roi) {
      args.push("--roi");
      args.push(...roi.split(" "));
    }
    console.log("Executing mac-cli with args:", args.join(" "));
    const command = Command.sidecar("binaries/vision-subtitle-extractor-mac", args);
    let stdout = "";
    let stderr = "";
    command.stdout.addListener("data", (line) => {
      console.log(`[mac-cli] ${line}`);
      stdout += line + "\n";
    });
    command.stderr.addListener("data", (line) => {
      console.error(`[mac-cli] ${line}`);
      stderr += line + "\n";
    });

    return new Promise<MacCliResult>((resolve, reject) => {
      command.on("close", (data) => {
        console.log("mac-cli process closed:", data);
        resolve({
          stdout: stdout,
          stderr: stderr, 
          code: data.code,
        });
      });
      command.on("error", (err) => {
        console.error("mac-cli process error:", err);
        reject(err);
      });
      command.spawn().then((child) => {
        console.log("mac-cli process spawned:", child);
      }).catch((err) => {
        console.error("Failed to spawn mac-cli process:", err);
        reject(err);
      });
    });
  },
};

export default macCliBackend;
