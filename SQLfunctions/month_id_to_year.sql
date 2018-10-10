CREATE OR REPLACE FUNCTION month_id_to_year(integer) RETURNS INTEGER
  LANGUAGE SQL
  AS $$
  SELECT year_id FROM staging.month WHERE id::int=$1
  $$
  IMMUTABLE
  RETURNS NULL ON NULL INPUT;