export interface ExtractOptions {
  filePath: string;
  outputPath: string;

  intervalMs?: number;
  /** region of interest. This is to limit OCR processing to a specific area */
  roi?: string;

  /**
   * Optional callback to receive progress updates (0.0 to 1.0)
   */
  onProgress?: (progressFraction: number) => void;
}
export interface ExtractResult {
  stdout: string;
  stderr: string;
  code: number | null;
}

export enum Capability {
    OPTION_INTERVAL = 1,
    /**
     * Requires implementation of `roiFormat` function as well as support for `roi` option in `extract` function
     */
    REGION_OF_INTEREST = 2,
}

export interface Backend {
    capabilities: number;
    /** Format for the region of interest */
    roiFormat?: () => string;
    extract(options: ExtractOptions): Promise<ExtractResult>;
}

export function hasCapability(backend: Backend, capability: Capability): boolean {
    return (backend.capabilities & capability) === capability;
}