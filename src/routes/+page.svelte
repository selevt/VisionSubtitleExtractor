<script lang="ts">
	import Progress from './Progress.svelte';
	import {
		Capability,
		hasCapability,
		type Backend,
		type ExtractResult,
		type SupportedLanguage
	} from '$lib/backend-common';
	import macBackend from '$lib/mac-cli';
	import { tempDir } from '@tauri-apps/api/path';
	import { open, save } from '@tauri-apps/plugin-dialog';
	import { getCurrentWebview } from '@tauri-apps/api/webview';
	import { copyFile } from '@tauri-apps/plugin-fs';
	import { useLocalStorage } from '$lib/useLocalStorage.svelte';
	const backend: Backend = macBackend;

	let filePath = $state('');
	let fileName = $state('');
	const DEFAULT_INTERVAL_MS = 1000;
	const DEFAULT_ROI = '';

	const intervalMsStore = useLocalStorage<number>('intervalMs', DEFAULT_INTERVAL_MS);
	const roiStore = useLocalStorage<string>('roi', DEFAULT_ROI);
	const selectedLanguageStore = useLocalStorage<string | undefined>('selectedLanguage', undefined);
	let supportedLanguages = $state<SupportedLanguage[]>([]);

	let isDragging = $state(false);
	let inProgress = $state(false);

	// Progress state
	let progress = $state(0);
	let framesProcessed = $state(0);
	let totalFrames = $state(0);
	let elapsedMs = $state(0);
	let _progressStartTime: number | null = null;
	let _progressTimer: number | null = null;

	let res: ExtractResult | undefined = $state(undefined);
	let resFilePath = $state('');
	let resError: unknown = $state(undefined);

	async function setupDragDrop() {
		const webview = getCurrentWebview();
		await webview.onDragDropEvent((event) => {
			if (event.payload.type === 'over' || event.payload.type === 'enter') {
				isDragging = true;
			} else if (event.payload.type === 'drop') {
				isDragging = false;
				if (event.payload.paths && event.payload.paths.length > 0) {
					// Get the first dropped file path
					filePath = event.payload.paths[0];
					const parts = filePath.split('/');
					fileName = parts[parts.length - 1];
				}
			} else if (event.payload.type === 'leave') {
				isDragging = false;
			}
		});
	}

	$effect(() => {
		setupDragDrop().catch(console.error);
		if (hasCapability(backend, Capability.LANGUAGE_SELECTION) && backend.getSupportedLanguages) {
			loadSupportedLanguages();
		}
	});

	async function loadSupportedLanguages() {
		try {
			if (backend.getSupportedLanguages) {
				supportedLanguages = await backend.getSupportedLanguages();
				console.log('Loaded supported languages:', supportedLanguages);
				// If selectedLanguage is not set or not in the list, pick the first
				if (
					!selectedLanguageStore.value ||
					!supportedLanguages.some((l) => l.code === selectedLanguageStore.value)
				) {
					selectedLanguageStore.value = supportedLanguages[0]?.code;
				}
			}
		} catch (error) {
			console.error('Failed to load supported languages:', error);
		}
	}

	async function handleFileSelect() {
		// Use Tauri's dialog API to get the file path
		const selected = await open({
			multiple: false,
			filters: [
				{
					name: 'Video',
					extensions: ['mp4', 'mov', 'avi', 'm4v', 'mkv']
				}
			]
		});

		if (selected) {
			// If the user selected a file, update the file path and name
			filePath = selected as string;
			// Extract the file name from the path
			const parts = filePath.split('/');
			fileName = parts[parts.length - 1];
		}
	}

	async function runCmd() {
		if (!filePath) {
			alert('Please select a video file first');
			return;
		}

		try {
			inProgress = true;
			progress = 0;
			framesProcessed = 0;
			totalFrames = 0;
			elapsedMs = 0;
			_progressStartTime = Date.now();
			if (_progressTimer) {
				clearInterval(_progressTimer);
			}
					_progressTimer = setInterval(() => {
						if (_progressStartTime) {
							elapsedMs = Date.now() - _progressStartTime;
						}
					}, 1000);

			const outputDir = await tempDir();
			const uuid = crypto.randomUUID();
			const outputPath = `${outputDir}output-${uuid}.srt`;
			const output = await backend.extract({
				filePath,
				outputPath,
				intervalMs: hasCapability(backend, Capability.OPTION_INTERVAL)
					? intervalMsStore.value
					: undefined,
				roi:
					hasCapability(backend, Capability.REGION_OF_INTEREST) && roiStore.value
						? roiStore.value
						: undefined,
				language: hasCapability(backend, Capability.LANGUAGE_SELECTION)
					? selectedLanguageStore.value
					: undefined,
				onProgress: (progressObj) => {
					if (typeof progressObj.progressFraction === 'number')
						progress = progressObj.progressFraction;
					if (typeof progressObj.framesProcessed === 'number')
						framesProcessed = progressObj.framesProcessed;
					if (typeof progressObj.totalFrames === 'number') totalFrames = progressObj.totalFrames;
				}
			});

			console.log('done', output);
			res = output;
			resFilePath = outputPath;
			resError = undefined;
		} catch (e) {
			console.error('error', e);
			res = undefined;
			resError = e;
		} finally {
			inProgress = false;
			if (_progressTimer) {
				clearInterval(_progressTimer);
				_progressTimer = null;
			}
		}
	}

	async function saveSrt() {
		if (!resFilePath) {
			alert('No SRT file to save');
			return;
		}

		const destPath = await save({
			title: 'Select file to save SRT',
			defaultPath: filePath ? filePath.replace(/\.[^/.]+$/, '.srt') : 'output.srt',
		});

		if (destPath) {
			copyFile(resFilePath, destPath);
			alert(`SRT saved to ${destPath}`);
		}
	}
</script>

<main class="container">
	<h1>Vision Subtitle Extractor</h1>

	<form>
		<div class="file-drop-area {isDragging ? 'dragging' : ''}">
			<button
				type="button"
				class="file-input-container"
				onclick={handleFileSelect}
				onkeydown={(e) => e.key === 'Enter' && handleFileSelect()}
			>
				<span class="file-input-label">
					{fileName ? fileName : 'Click to choose a video file or drag and drop'}
				</span>
			</button>
		</div>
	</form>

	{#if hasCapability(backend, Capability.OPTION_INTERVAL)}
		<div class="row">
			<label for="interval-input">Interval (ms):</label>
			<input id="interval-input" inputmode="numeric" bind:value={intervalMsStore.value} />
			<button type="button" style="margin-left: 8px;" onclick={() => intervalMsStore.reset()}
				>Reset</button
			>
		</div>
	{/if}

	{#if hasCapability(backend, Capability.REGION_OF_INTEREST) && backend.roiFormat}
		<div class="row">
			<!-- TODO: integrate directly -->
			<label for="roi-input"
				>Region of interest (<a
					target="_blank"
					href={`https://selevt.github.io/video-area-selection/?template=${encodeURIComponent(backend.roiFormat())}`}
				>
					Get from here
				</a>):</label
			>
			<input id="roi-input" bind:value={roiStore.value} />
			<button type="button" style="margin-left: 8px;" onclick={() => roiStore.reset()}>Reset</button
			>
		</div>
	{/if}

	{#if hasCapability(backend, Capability.LANGUAGE_SELECTION) && supportedLanguages.length > 0}
		<div class="row">
			<label for="language-select">Recognition language:</label>
			<select id="language-select" bind:value={selectedLanguageStore.value}>
				{#each supportedLanguages as language}
					<option value={language.code}>
						{language.name || language.code}
					</option>
				{/each}
			</select>
			<button
				type="button"
				style="margin-left: 8px;"
				onclick={() => (selectedLanguageStore.value = supportedLanguages[0]?.code)}>Reset</button
			>
		</div>
	{/if}

	<button onclick={runCmd} disabled={inProgress}
		>Start extraction {filePath ? `(${filePath})` : ''}</button
	>
		{#if inProgress}
				<Progress
					{progress}
					{framesProcessed}
					{totalFrames}
					elapsedMs={elapsedMs}
				/>
	{:else if res && res.code === 0}
		<p>Result: success</p>
		<button onclick={saveSrt}>Save SRT</button>
	{:else if resError || res?.code}
		<p>Result: error</p>
		{#if resError}
			<pre>{JSON.stringify(resError, null, 2)}</pre>
		{/if}
		{#if res}
			<pre>{JSON.stringify(res, null, 2)}</pre>
		{/if}
	{/if}
</main>


<style>
	:root {
		font-family: Inter, Avenir, Helvetica, Arial, sans-serif;
		font-size: 16px;
		line-height: 24px;
		font-weight: 400;

		color: #0f0f0f;
		background-color: #f6f6f6;

		font-synthesis: none;
		text-rendering: optimizeLegibility;
		-webkit-font-smoothing: antialiased;
		-moz-osx-font-smoothing: grayscale;
		-webkit-text-size-adjust: 100%;
	}

	.container {
		margin: 0;
		padding-top: 5vh;
		display: flex;
		flex-direction: column;
		justify-content: center;
		text-align: center;
		gap: 8px;
	}

	.row {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	a {
		font-weight: 500;
		color: #646cff;
		text-decoration: inherit;
	}

	a:hover {
		color: #535bf2;
	}

	h1 {
		text-align: center;
	}

	input[type='text'],
	input[type='number'],
	select,
	button {
		border-radius: 8px;
		border: 1px solid transparent;
		padding: 0.6em 1.2em;
		font-size: 1em;
		font-weight: 500;
		font-family: inherit;
		color: #0f0f0f;
		background-color: #ffffff;
		transition: border-color 0.25s;
		box-shadow: 0 2px 2px rgba(0, 0, 0, 0.2);
	}
	button:disabled {
		opacity: 0.5;
	}

	button:not(:disabled) {
		cursor: pointer;
	}

	button:hover:not(:disabled) {
		border-color: #396cd8;
	}
	button:active:not(:disabled) {
		border-color: #396cd8;
		background-color: #e8e8e8;
	}

	.file-drop-area {
		width: 100%;
		max-width: 400px;
		margin: 0 auto;
		padding: 2rem;
		border-radius: 8px;
		border: 2px dashed #ccc;
		transition: all 0.3s ease;
		background-color: #ffffff;
		box-shadow: 0 2px 2px rgba(0, 0, 0, 0.1);
	}

	.file-drop-area.dragging {
		border-color: #396cd8;
		background-color: rgba(57, 108, 216, 0.05);
	}

	.file-input-container {
		position: relative;
		text-align: center;
		cursor: pointer;
		padding: 1rem;
		border-radius: 8px;
		background-color: rgba(0, 0, 0, 0.03);
		transition: all 0.2s ease;
	}

	.file-input-container:hover {
		background-color: rgba(57, 108, 216, 0.1);
	}

	.file-input-label {
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1em;
		color: #666;
		cursor: pointer;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		min-height: 1.5rem;
	}

	.file-input-label::before {
		content: '📁 ';
		margin-right: 0.5rem;
	}

	#interval-input,
	#roi-input,
	#language-select {
		margin-left: 8px;
	}

	@media (prefers-color-scheme: dark) {
		:root {
			color: #f6f6f6;
			background-color: #2f2f2f;
		}

		a:hover {
			color: #24c8db;
		}

		input,
		select,
		button {
			color: #ffffff;
			background-color: #0f0f0f98;
		}
		button:active {
			background-color: #0f0f0f69;
		}

		.file-drop-area {
			background-color: #1a1a1a;
			border-color: #444;
		}

		.file-drop-area.dragging {
			border-color: #24c8db;
			background-color: rgba(36, 200, 219, 0.1);
		}

		.file-input-container {
			background-color: rgba(255, 255, 255, 0.05);
		}

		.file-input-container:hover {
			background-color: rgba(36, 200, 219, 0.15);
		}

		.file-input-label {
			color: #aaa;
		}
	}
</style>
