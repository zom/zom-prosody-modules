local mmdb = assert(require "mmdb", "mod_monthly_visitors requires mmdb");
local mv_store_name = "monthly-visitors";
local mv_store = module:open_store(mv_store_name, "map");

local geoip_db_filename = module:get_option_string("mod_monthly_visitors_geoip_mmdb_path");
local geodb = assert(mmdb.read(geoip_db_filename), "GeoIP mmdb database not valid.");

local isp_db_filename = module:get_option_string("mod_monthly_visitors_isp_mmdb_path");
local ispdb = assert(mmdb.read(isp_db_filename), "isp mmdb database not valid.");

local client_patterns = module:get_option("mod_monthly_visitors_client_patterns", {});
local unknown_client = "?";
local countries_to_record_iso = module:get_option("mod_monthly_visitors_record_countries", {});

local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function current_month()
  return os.date("%Y-%m");
end

local function ispcode(ip)
  local ispdata;
  if not pcall(function() ispdata = ispdb:search_ipv4(ip); end ) then
    return nil
  end

  asn = ispdata["autonomous_system_number"]
  if asn  ~= nil then
    return "AS" .. asn
  end
  return "?"
end

local function geocode(ip)
  local geodata;
  if not pcall(function() geodata = geodb:search_ipv4(ip); end ) then
    return nil
  end
  local city = "?";
  if geodata["city"] ~= nil then
    city = geodata.city.geoname_id;
  end
  local subdiv = "?";
  if geodata["subdivisions"] ~= nil then
    subdiv = geodata.subdivisions[1].iso_code;
  end

  local country = "?";
  if geodata["country"] ~= nil then
    country = geodata.country.iso_code
  end

  return country .. "-" .. subdiv .. "-" .. city;
end

local function should_record(ip)
  if next(countries_to_record_iso) == nil then
    return false;
  end

  local geodata;
  if not pcall(function() geodata = geodb:search_ipv4(ip); end ) then
    return false;
  end

  local country = "";
  if geodata["country"] ~= nil then
    country = geodata.country.iso_code
  end
  return has_value(countries_to_record_iso, country)
end

local function has_been_recorded(username)
  local curr_month = current_month();
  local last_recorded = mv_store:get(username, "last-recorded");
  return last_recorded == curr_month;
end

local function classify(patterns, unknown, item)
  if item == nil then
    return unknown;
  end
  for pattern,category in pairs(patterns) do
    local res = string.match(item, pattern) ;
    if res ~= nil then
      return category;
    end
  end
  return unknown;
end

local function guess_client(resource)
  return classify(client_patterns, unknown_client, resource);
end

local function incr_key(mv_data, key)
  if key == nil then
    return mv_data;
  end;
  if mv_data[key] ~= nil then
    mv_data[key] = 1 + mv_data[key];
  else
    mv_data[key] = 1;
  end
  return mv_data;
end

local function record_monthly_visitor(username, ip, resource)

  if has_been_recorded(username) then
    return;
  end

  if not should_record(ip) then
    return;
  end

  local curr_month = current_month();
  local client = guess_client(resource);
  local geo_key = geocode(ip);
  local isp = ispcode(ip);

  local mv_data = mv_store:get(nil, curr_month);
  if mv_data == nil then
    mv_data = {};
  end

  if mv_data[geo_key] == nil then
    mv_data[geo_key] = {
      ["users_seen"] = 0,
      ["clients_seen"] = {},
      ["isps_seen"] = {}
    };
  end

  geo_data = mv_data[geo_key]
  geo_data = incr_key(geo_data, "users_seen");

  client_data = geo_data["clients_seen"]
  client_data = incr_key(client_data, client);
  geo_data["clients_seen"] = client_data

  isp_data = geo_data["isps_seen"]
  isp_data = incr_key(isp_data, isp);
  geo_data["isps_seen"] = isp_data


  -- save the current month's counts
  mv_store:set(nil, curr_month, mv_data);
  -- mark the username as recorded for this month
  mv_store:set(username, "last-recorded", curr_month);
  module:log("info", "another " .. geo_key);
end

module:hook("resource-bind", function (event)
              local session = event.session;
              record_monthly_visitor(session.username, session.ip, session.resource);
end);

