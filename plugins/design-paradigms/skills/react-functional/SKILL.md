---
name: react-functional
description: Modern functional React architecture — hooks-based state and side effects, component composition, colocating state, server vs. client components, memoization discipline, and data-fetching patterns. Use whenever writing, reviewing, or architecting React components, hooks, or a React app's state management, or the user mentions React, Next.js, JSX, or frontend component design.
---

# React Functional Component Architecture

Modern React is function components plus hooks; class components are legacy-maintenance-only. Treat components as pure functions of props and state wherever possible, pushing side effects to the edges (`useEffect`, event handlers, server actions).

## Core principles

1. **Components are pure functions of their props/state.** Given the same inputs, render the same output — no side effects during render.
2. **Colocate state as close to where it's used as possible.** Lift state up only when two components genuinely need to share it; default to local.
3. **Composition over configuration.** Prefer passing children/render props over a component with a dozen boolean props controlling its internals.
4. **Derive, don't duplicate.** If a value can be computed from existing state/props, compute it during render — don't store it in a second `useState`.

## Component structure

```jsx
function OrderSummary({ order }) {
  // Derived value — not its own state, so it can never go stale.
  const total = order.items.reduce((sum, item) => sum + item.price * item.quantity, 0);

  return (
    <section>
      <h2>Order #{order.id}</h2>
      <ItemList items={order.items} />
      <Total amount={total} />
    </section>
  );
}

function ItemList({ items }) {
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id}>{item.name} x{item.quantity}</li>
      ))}
    </ul>
  );
}
```

Keep components small and named for what they render, not for the feature branch or ticket that created them. A component that needs a code comment explaining "this also does X" should be split.

## Hooks discipline

- **`useState`** for local, independent pieces of state. If two pieces of state always change together, merge them into one object or use `useReducer`.
- **`useReducer`** once you have more than ~3 related state transitions or state transitions that depend on the previous state in non-trivial ways — it centralizes the transition logic and makes it testable independent of rendering.
- **`useEffect`** only for synchronizing with something outside React (subscriptions, manual DOM measurement, analytics). Fetching data that could instead be a server component, a loader, or a query library is not a `useEffect` use case in a modern codebase.
- **Custom hooks** to extract any stateful logic reused across two or more components — this is the primary reuse mechanism, replacing what HOCs and render props did in older React.

```jsx
function useDebouncedValue(value, delayMs) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(id);
  }, [value, delayMs]);
  return debounced;
}

function SearchBox({ onSearch }) {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebouncedValue(query, 300);

  useEffect(() => {
    if (debouncedQuery) onSearch(debouncedQuery);
  }, [debouncedQuery, onSearch]);

  return <input value={query} onChange={(e) => setQuery(e.target.value)} />;
}
```

## Data fetching

Prefer, in order of preference for a modern app:

1. **Server components / server-rendered loaders** (Next.js App Router, Remix loaders) — fetch on the server, ship HTML/data, no client waterfall.
2. **A query library** (TanStack Query, SWR) for client-fetched data — gives you caching, deduplication, and stale-while-revalidate for free instead of hand-rolled `useEffect` + `useState` fetch logic.
3. **Raw `useEffect` fetch** only for simple, one-off client-only fetches with no caching requirement.

```jsx
// TanStack Query — replaces manual loading/error/data useState triplets
function OrderPage({ orderId }) {
  const { data: order, isLoading, error } = useQuery({
    queryKey: ["order", orderId],
    queryFn: () => fetchOrder(orderId),
  });

  if (isLoading) return <Spinner />;
  if (error) return <ErrorBanner error={error} />;
  return <OrderSummary order={order} />;
}
```

## Memoization: use deliberately, not defensively

- `React.memo`, `useMemo`, `useCallback` exist to skip expensive re-renders/recomputations — they are not free. Each one adds a dependency-array bug surface.
- Reach for them when you have a measured re-render cost (a large list, an expensive computation, a child wrapped in `memo` that otherwise re-renders on every parent render) — not preemptively on every component.
- Prefer structural fixes first: colocating state so unrelated components don't re-render, or using `key` to reset subtree state instead of manual memoized reset logic.

```jsx
const sortedItems = useMemo(
  () => items.slice().sort((a, b) => a.price - b.price), // O(n log n) — worth memoizing for a large list
  [items]
);
```

## State management scope

| Scope | Tool |
|---|---|
| Single component | `useState`/`useReducer` |
| Shared across a subtree, infrequently changing | React Context + `useReducer` |
| Server/cache data | TanStack Query / SWR, not global client state |
| App-wide, frequently changing, many independent readers | A dedicated store (Zustand, Redux Toolkit) — only once Context re-render cost becomes a real problem |

Don't reach for a global store before you have a demonstrated cross-cutting state need — most "global state" in a new app is actually server data that belongs in a query cache.

## Common pitfalls

- Storing derived data in `useState` and syncing it with `useEffect` instead of computing it during render.
- Missing or incorrect `useEffect` dependency arrays — causes stale closures or infinite loops; never suppress the lint rule without understanding why the dependency is "supposed" to be missing.
- Prop drilling five levels deep instead of composition (`children`) or a scoped context.
- Mutating state directly (`state.items.push(x)`) instead of returning a new array/object — breaks referential-equality checks React and memoization rely on.
- Overusing `useEffect` for anything that isn't synchronizing with an external system — most bugs described as "React effect problems" are really "this shouldn't have been an effect."
