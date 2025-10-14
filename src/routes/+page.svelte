<script lang="ts">
	import { Capability, hasCapability, type Backend, type ExtractResult } from '$lib/backend-common';
	import macBackend from '$lib/mac-cli';
	import { tempDir } from '@tauri-apps/api/path';
	const backend: Backend = macBackend;

	let filePath = $state('');
	let intervalMs = $state(1000);

	let inProgress = $state(false);
	let res: ExtractResult | undefined = $state(undefined);
	let resError: unknown = $state(undefined);

	async function runCmd() {
		try {
      inProgress = true;
			const outputDir = await tempDir();
			const outputPath = `${outputDir}output.srt`;
			const output = await backend.extract({
				filePath,
				outputPath,
				intervalMs: hasCapability(backend, Capability.OPTION_INTERVAL) ? intervalMs : undefined
			});

			console.log('done', output);
			res = output;
      resError = undefined;
		} catch (e) {
			console.error('error', e);
   res = undefined
			resError = e;
		} finally {
      inProgress = false;
    }
	}
</script>

<main class="container">
	<h1>Vision Subtitle Extractor</h1>

	<form>
		<div class="row">
			<input id="greet-input" placeholder="Enter file path" bind:value={filePath} />
		</div>
	</form>
	<div class="row">
		{#if hasCapability(backend, Capability.OPTION_INTERVAL)}
			<label for="interval-input">Interval (ms):</label>
			<input id="interval-input" inputmode="numeric" bind:value={intervalMs} />
		{/if}
	</div>

	<button onclick={() => runCmd()}>Start extraction</button>
	{#if inProgress}
    <p>In progress...</p>
  {:else if res && res.code === 0}
		<p>Result: success</p>
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
		padding-top: 10vh;
		display: flex;
		flex-direction: column;
		justify-content: center;
		text-align: center;
	}

	.row {
		display: flex;
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

	input,
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

	button {
		cursor: pointer;
	}

	button:hover {
		border-color: #396cd8;
	}
	button:active {
		border-color: #396cd8;
		background-color: #e8e8e8;
	}

	input,
	button {
		outline: none;
	}

	#greet-input {
		margin-right: 5px;
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
		button {
			color: #ffffff;
			background-color: #0f0f0f98;
		}
		button:active {
			background-color: #0f0f0f69;
		}
	}
</style>
