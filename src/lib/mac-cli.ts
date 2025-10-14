import { Command } from "@tauri-apps/plugin-shell";
import { type ExtractOptions, type ExtractResult, type Backend, Capability } from "./backend-common";

interface MacCliOptions extends ExtractOptions {}
interface MacCliResult extends ExtractResult {}

export const macCliBackend: Backend = {
  capabilities: Capability.OPTION_INTERVAL,

  extract: async (options: MacCliOptions): Promise<MacCliResult> => {
    const { filePath, outputPath, intervalMs } = options;
    const args: string[] = [filePath, "--output", outputPath];
    if (intervalMs) {
      // ms to seconds
      args.push("--interval", String(intervalMs / 1000));
    }
    const command = Command.sidecar("binaries/vision-subtitle-extractor-mac", args);
    const output = await command.execute();
    return {
      stdout: output.stdout,
      stderr: output.stderr,
      code: output.code,
    };
  },
};

export default macCliBackend;
