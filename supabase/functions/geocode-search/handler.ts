import {
  assertOnlyKeys,
  assertPostJson,
  errorResponse,
  HttpError,
  json,
  optionsResponse,
  readJsonObject,
  requestIdFor,
  requiredString,
} from "../_shared/http.ts";

export interface GeocodeResult {
  displayName: string;
  lat: number;
  lon: number;
  road?: string;
  houseNumber?: string;
  city?: string;
  state?: string;
  postcode?: string;
}

export interface GeocodeDependencies {
  authenticate(req: Request): Promise<{ id: string }>;
  searchNominatim(
    query: string,
    limit: number,
    signal: AbortSignal,
  ): Promise<readonly GeocodeResult[]>;
  searchPhoton(
    query: string,
    limit: number,
    signal: AbortSignal,
  ): Promise<readonly GeocodeResult[]>;
}

export function geocodeSearchHandler(
  dependencies: GeocodeDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method === "OPTIONS") return optionsResponse(req, requestId);

    try {
      assertPostJson(req);
      await dependencies.authenticate(req);
      const body = await readJsonObject(req);
      assertOnlyKeys(body, ["q", "limit"]);
      const query = requiredString(body, "q", { maxLength: 120 })
        .replace(/\s+/g, " ");
      if (query.length < 2 || containsControlCharacter(query)) {
        throw new HttpError(400, "invalid_query", "Search query is invalid.");
      }
      const rawLimit = body.limit ?? 5;
      if (!Number.isSafeInteger(rawLimit) || Number(rawLimit) < 1 || Number(rawLimit) > 8) {
        throw new HttpError(400, "invalid_limit", "limit must be between 1 and 8.");
      }
      const limit = Number(rawLimit);

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 10_000);
      let source = "nominatim";
      let results: readonly GeocodeResult[] = [];
      try {
        try {
          results = await dependencies.searchNominatim(
            query,
            limit,
            controller.signal,
          );
        } catch {
          if (controller.signal.aborted) throw timeoutError();
        }
        if (results.length === 0) {
          source = "photon";
          try {
            results = await dependencies.searchPhoton(
              query,
              limit,
              controller.signal,
            );
          } catch {
            if (controller.signal.aborted) throw timeoutError();
            throw new HttpError(502, "geocoder_unavailable", "Address search is unavailable.");
          }
        }
      } finally {
        clearTimeout(timeout);
      }

      return json(
        req,
        {
          results: sanitizeResults(results, limit).map((result) => ({
            display_name: result.displayName,
            lat: result.lat,
            lon: result.lon,
            road: result.road ?? "",
            house_number: result.houseNumber ?? "",
            city: result.city ?? "",
            state: result.state ?? "",
            postcode: result.postcode ?? "",
          })),
          source,
        },
        200,
        requestId,
      );
    } catch (error) {
      return errorResponse(req, error, requestId);
    }
  };
}

function sanitizeResults(
  raw: readonly GeocodeResult[],
  limit: number,
): GeocodeResult[] {
  const seen = new Set<string>();
  const results: GeocodeResult[] = [];
  for (const result of raw) {
    if (
      !Number.isFinite(result.lat) ||
      !Number.isFinite(result.lon) ||
      result.lat < -90 ||
      result.lat > 90 ||
      result.lon < -180 ||
      result.lon > 180
    ) continue;
    const displayName = clean(result.displayName, 300);
    if (!displayName) continue;
    const key = `${result.lat.toFixed(5)}:${result.lon.toFixed(5)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    results.push({
      displayName,
      lat: result.lat,
      lon: result.lon,
      road: clean(result.road, 120),
      houseNumber: clean(result.houseNumber, 32),
      city: clean(result.city, 120),
      state: clean(result.state, 120),
      postcode: clean(result.postcode, 24),
    });
    if (results.length >= limit) break;
  }
  return results;
}

function clean(value: string | undefined, maxLength: number): string {
  return [...(value ?? "")]
    .map((character) => {
      const code = character.charCodeAt(0);
      return code <= 31 || code === 127 ? " " : character;
    })
    .join("")
    .trim()
    .slice(0, maxLength);
}

function containsControlCharacter(value: string): boolean {
  return [...value].some((character) => {
    const code = character.charCodeAt(0);
    return code <= 31 || code === 127;
  });
}

function timeoutError(): HttpError {
  return new HttpError(504, "geocoder_timeout", "Address search timed out.");
}
