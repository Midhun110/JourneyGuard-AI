-- ==============================================================================
-- JourneyGuard AI: Module D — Community Incident Reporting Schema
-- PostgreSQL + PostGIS Migration for Supabase
-- ==============================================================================

-- 1. Enable PostGIS Extension (Required for GEOGRAPHY(POINT, 4326))
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Create Incidents Table Matching Module D Specification
CREATE TABLE IF NOT EXISTS incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  incident_type TEXT NOT NULL, -- 'flood', 'landslide', 'fallen_tree', 'road_damage', 'waterlogging', 'other'
  description TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Create Spatial GiST Index for Fast Proximity Queries (ST_DWithin)
CREATE INDEX IF NOT EXISTS incidents_location_idx ON incidents USING GIST (location);

-- 4. PostGIS Proximity Search Function
-- Finds all incidents within [radius_meters] of a given lat/lng coordinate
-- Used by Module B to query reported incidents near route segments
CREATE OR REPLACE FUNCTION get_incidents_near(
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION DEFAULT 10000
)
RETURNS TABLE (
  id UUID,
  reporter_id UUID,
  incident_type TEXT,
  description TEXT,
  photo_url TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  distance_meters DOUBLE PRECISION
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    i.id,
    i.reporter_id,
    i.incident_type,
    i.description,
    i.photo_url,
    ST_Y(i.location::geometry) AS latitude,
    ST_X(i.location::geometry) AS longitude,
    i.created_at,
    ST_Distance(i.location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) AS distance_meters
  FROM incidents i
  WHERE ST_DWithin(i.location, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, radius_meters)
  ORDER BY distance_meters ASC;
$$;

-- 5. Row-Level Security (RLS) Configuration
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;

-- Allow public read access to all users (commuters need to see hazard reports)
CREATE POLICY "Public Read Access for Incidents"
  ON incidents
  FOR SELECT
  USING (true);

-- Allow authenticated and anonymous users to insert their reports
CREATE POLICY "Allow Insert for Authenticated and Anonymous Users"
  ON incidents
  FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated' OR auth.role() = 'anon'
  );

-- 6. Storage Bucket for Incident Photos
-- Run in Supabase SQL editor or create via Supabase Dashboard -> Storage:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('incident-photos', 'incident-photos', true);
