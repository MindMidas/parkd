import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { authenticateRateLimited } from "../_shared/rate_limit.ts";
import { adminClient, supabaseRuntimeConfig } from "../_shared/runtime.ts";
import { type GeocodeResult, geocodeSearchHandler } from "./handler.ts";

const config = supabaseRuntimeConfig();
const admin = adminClient(config);
const contact = Deno.env.get("GEOCODER_CONTACT_EMAIL")?.trim() ?? "";
if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact)) {
  throw new Error("GEOCODER_CONTACT_EMAIL must be configured");
}
const userAgent = `ParkdPortfolioDemo/1.0 (${contact})`;

const handler = geocodeSearchHandler({
  authenticate: (req) =>
    authenticateRateLimited(req, config, admin, "geocode", {
      userLimit: 20,
      ipLimit: 60,
      windowSeconds: 60,
    }),
  async searchNominatim(query, limit, signal) {
    const url = new URL("https://nominatim.openstreetmap.org/search");
    url.search = new URLSearchParams({
      q: query,
      format: "jsonv2",
      addressdetails: "1",
      limit: String(limit),
      countrycodes: "ca",
      viewbox: "-80.75,43.75,-79.95,43.35",
      bounded: "0",
    }).toString();
    const data = await fetchJson(url, signal);
    if (!Array.isArray(data)) return [];
    return data.flatMap(parseNominatim).slice(0, limit);
  },
  async searchPhoton(query, limit, signal) {
    const url = new URL("https://photon.komoot.io/api");
    url.search = new URLSearchParams({
      q: query,
      limit: String(limit),
      lang: "en",
      bbox: "-80.75,43.35,-79.95,43.75",
      lat: "43.5448",
      lon: "-80.2482",
    }).toString();
    const data = await fetchJson(url, signal);
    if (!data || typeof data !== "object" || Array.isArray(data)) return [];
    const features = (data as Record<string, unknown>).features;
    if (!Array.isArray(features)) return [];
    return features.flatMap(parsePhoton).slice(0, limit);
  },
});

Deno.serve(handler);

async function fetchJson(url: URL, signal: AbortSignal): Promise<unknown> {
  const response = await fetch(url, {
    method: "GET",
    redirect: "error",
    signal,
    headers: {
      "Accept": "application/json",
      "User-Agent": userAgent,
    },
  });
  if (!response.ok) throw new Error(`Geocoder returned ${response.status}`);
  const text = await response.text();
  if (new TextEncoder().encode(text).byteLength > 1_048_576) {
    throw new Error("Geocoder response too large");
  }
  return JSON.parse(text);
}

function parseNominatim(value: unknown): GeocodeResult[] {
  if (!value || typeof value !== "object" || Array.isArray(value)) return [];
  const row = value as Record<string, unknown>;
  const address = row.address && typeof row.address === "object" && !Array.isArray(row.address)
    ? row.address as Record<string, unknown>
    : {};
  const lat = Number(row.lat);
  const lon = Number(row.lon);
  if (typeof row.display_name !== "string" || !Number.isFinite(lat) || !Number.isFinite(lon)) {
    return [];
  }
  return [{
    displayName: row.display_name,
    lat,
    lon,
    road: stringValue(address.road),
    houseNumber: stringValue(address.house_number),
    city: stringValue(address.city) || stringValue(address.town) || stringValue(address.village),
    state: stringValue(address.state),
    postcode: stringValue(address.postcode),
  }];
}

function parsePhoton(value: unknown): GeocodeResult[] {
  if (!value || typeof value !== "object" || Array.isArray(value)) return [];
  const feature = value as Record<string, unknown>;
  const geometry = feature.geometry && typeof feature.geometry === "object"
    ? feature.geometry as Record<string, unknown>
    : {};
  const coordinates = geometry.coordinates;
  const properties = feature.properties && typeof feature.properties === "object"
    ? feature.properties as Record<string, unknown>
    : {};
  if (!Array.isArray(coordinates) || coordinates.length < 2) return [];
  const lon = Number(coordinates[0]);
  const lat = Number(coordinates[1]);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return [];
  const name = stringValue(properties.name);
  const road = stringValue(properties.street);
  const houseNumber = stringValue(properties.housenumber);
  const city = stringValue(properties.city) || stringValue(properties.town) ||
    stringValue(properties.district);
  const state = stringValue(properties.state);
  const postcode = stringValue(properties.postcode);
  const displayName = [
    name,
    [houseNumber, road].filter(Boolean).join(" "),
    city,
    state,
    postcode,
    stringValue(properties.country),
  ].filter(Boolean).join(", ");
  return displayName
    ? [{
      displayName,
      lat,
      lon,
      road,
      houseNumber,
      city,
      state,
      postcode,
    }]
    : [];
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}
