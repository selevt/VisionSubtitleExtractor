/**
 * localStorage state hook for use in .svelte/.svelte.ts files (uses $state rune).
 * Returns an object with .value and .reset().
 * Usage: const store = useLocalStorage('key', initialValue); store.value = ...; store.reset();
 */
export function useLocalStorage<T>(key: string, initial: T) {
    let value = $state(initial);
    // Load from localStorage if available
    const stored = localStorage.getItem(key);
    if (stored !== null) {
        try {
            value = typeof initial === 'number' ? (parseFloat(stored) as T) : (stored as T);
        } catch {}
    }
    $effect(() => {
        localStorage.setItem(key, value?.toString?.() ?? '');
    });
    return {
        get value() {
            return value;
        },
        set value(v: T) {
            value = v;
        },
        reset() {
            value = initial;
        }
    };
}
