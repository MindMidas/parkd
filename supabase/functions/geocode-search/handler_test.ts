import { type GeocodeDependencies, geocodeSearchHandler } from "./handler.ts";

function request(body: Record<string, unknown>): Request {
  return new Request("https://functions.example/geocode-search", {
    method: "POST",
    headers: { authorization: "Bearer token", "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function dependencies(
  overrides: Partial<GeocodeDependencies> = {},
): GeocodeDependencies {
  return {
    authenticate: async () => ({ id: "44444444-4444-4444-8444-444444444444" }),
    searchNominatim: async () => [],
    searchPhoton: async () => [],
    ...overrides,
  };
}

Deno.test("geocode validates query and bounded result count", async () => {
  let upstreamCalled = false;
  const handler = geocodeSearchHandler(
    dependencies({
      searchNominatim: async () => {
        upstreamCalled = true;
        return [];
      },
    }),
  );
  const response = await handler(request({ q: "x", limit: 9 }));
  assertEquals(response.status, 400);
  assertEquals(upstreamCalled, false);
});

Deno.test("geocode falls back to Photon and sanitizes/deduplicates results", async () => {
  const handler = geocodeSearchHandler(
    dependencies({
      searchNominatim: async () => [],
      searchPhoton: async () => [
        { displayName: "1 Main St\u0000", lat: 43.5, lon: -80.2 },
        { displayName: "duplicate", lat: 43.500001, lon: -80.200001 },
        { displayName: "invalid", lat: 200, lon: -80.2 },
      ],
    }),
  );
  const response = await handler(request({ q: "1 Main Street", limit: 5 }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.source, "photon");
  assertEquals(body.results.length, 1);
  assertEquals(body.results[0].display_name, "1 Main St");
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
