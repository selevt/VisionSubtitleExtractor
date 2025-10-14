export interface ExtractOptions {
  filePath: string;
  outputPath: string;

  intervalMs?: number;
}
export interface ExtractResult {
  stdout: string;
  stderr: string;
  code: number | null;
}

export enum Capability {
    OPTION_INTERVAL = 1,
}

export interface Backend {
    capabilities: number;
    extract(options: ExtractOptions): Promise<ExtractResult>;
}

export function hasCapability(backend: Backend, capability: Capability): boolean {
    return (backend.capabilities & capability) === capability;
}