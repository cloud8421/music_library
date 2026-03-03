defmodule MusicLibrary.Country do
  @moduledoc """
  Converts country codes to flag emojis.

  Supports alpha-2 (`"US"`), alpha-3 (`"USA"`), subdivision (`"GB-SCT"`),
  and IETF language tag (`"en-US"`) formats.
  """

  @regional_indicator_offset 0x1F1E6 - ?a
  @tag_offset 0xE0000
  @black_flag <<0x1F3F4::utf8>>
  @cancel_tag <<0xE007F::utf8>>

  # ISO 3166-1 alpha-3 to alpha-2 mapping
  @alpha3_to_alpha2 %{
    "ABW" => "AW",
    "AFG" => "AF",
    "AGO" => "AO",
    "AIA" => "AI",
    "ALA" => "AX",
    "ALB" => "AL",
    "AND" => "AD",
    "ARE" => "AE",
    "ARG" => "AR",
    "ARM" => "AM",
    "ASM" => "AS",
    "ATA" => "AQ",
    "ATF" => "TF",
    "ATG" => "AG",
    "AUS" => "AU",
    "AUT" => "AT",
    "AZE" => "AZ",
    "BDI" => "BI",
    "BEL" => "BE",
    "BEN" => "BJ",
    "BES" => "BQ",
    "BFA" => "BF",
    "BGD" => "BD",
    "BGR" => "BG",
    "BHR" => "BH",
    "BHS" => "BS",
    "BIH" => "BA",
    "BLM" => "BL",
    "BLR" => "BY",
    "BLZ" => "BZ",
    "BMU" => "BM",
    "BOL" => "BO",
    "BRA" => "BR",
    "BRB" => "BB",
    "BRN" => "BN",
    "BTN" => "BT",
    "BVT" => "BV",
    "BWA" => "BW",
    "CAF" => "CF",
    "CAN" => "CA",
    "CCK" => "CC",
    "CHE" => "CH",
    "CHL" => "CL",
    "CHN" => "CN",
    "CIV" => "CI",
    "CMR" => "CM",
    "COD" => "CD",
    "COG" => "CG",
    "COK" => "CK",
    "COL" => "CO",
    "COM" => "KM",
    "CPV" => "CV",
    "CRI" => "CR",
    "CUB" => "CU",
    "CUW" => "CW",
    "CXR" => "CX",
    "CYM" => "KY",
    "CYP" => "CY",
    "CZE" => "CZ",
    "DEU" => "DE",
    "DJI" => "DJ",
    "DMA" => "DM",
    "DNK" => "DK",
    "DOM" => "DO",
    "DZA" => "DZ",
    "ECU" => "EC",
    "EGY" => "EG",
    "ERI" => "ER",
    "ESH" => "EH",
    "ESP" => "ES",
    "EST" => "EE",
    "ETH" => "ET",
    "FIN" => "FI",
    "FJI" => "FJ",
    "FLK" => "FK",
    "FRA" => "FR",
    "FRO" => "FO",
    "FSM" => "FM",
    "GAB" => "GA",
    "GBR" => "GB",
    "GEO" => "GE",
    "GGY" => "GG",
    "GHA" => "GH",
    "GIB" => "GI",
    "GIN" => "GN",
    "GLP" => "GP",
    "GMB" => "GM",
    "GNB" => "GW",
    "GNQ" => "GQ",
    "GRC" => "GR",
    "GRD" => "GD",
    "GRL" => "GL",
    "GTM" => "GT",
    "GUF" => "GF",
    "GUM" => "GU",
    "GUY" => "GY",
    "HKG" => "HK",
    "HMD" => "HM",
    "HND" => "HN",
    "HRV" => "HR",
    "HTI" => "HT",
    "HUN" => "HU",
    "IDN" => "ID",
    "IMN" => "IM",
    "IND" => "IN",
    "IOT" => "IO",
    "IRL" => "IE",
    "IRN" => "IR",
    "IRQ" => "IQ",
    "ISL" => "IS",
    "ISR" => "IL",
    "ITA" => "IT",
    "JAM" => "JM",
    "JEY" => "JE",
    "JOR" => "JO",
    "JPN" => "JP",
    "KAZ" => "KZ",
    "KEN" => "KE",
    "KGZ" => "KG",
    "KHM" => "KH",
    "KIR" => "KI",
    "KNA" => "KN",
    "KOR" => "KR",
    "KWT" => "KW",
    "LAO" => "LA",
    "LBN" => "LB",
    "LBR" => "LR",
    "LBY" => "LY",
    "LCA" => "LC",
    "LIE" => "LI",
    "LKA" => "LK",
    "LSO" => "LS",
    "LTU" => "LT",
    "LUX" => "LU",
    "LVA" => "LV",
    "MAC" => "MO",
    "MAF" => "MF",
    "MAR" => "MA",
    "MCO" => "MC",
    "MDA" => "MD",
    "MDG" => "MG",
    "MDV" => "MV",
    "MEX" => "MX",
    "MHL" => "MH",
    "MKD" => "MK",
    "MLI" => "ML",
    "MLT" => "MT",
    "MMR" => "MM",
    "MNE" => "ME",
    "MNG" => "MN",
    "MNP" => "MP",
    "MOZ" => "MZ",
    "MRT" => "MR",
    "MSR" => "MS",
    "MTQ" => "MQ",
    "MUS" => "MU",
    "MWI" => "MW",
    "MYS" => "MY",
    "MYT" => "YT",
    "NAM" => "NA",
    "NCL" => "NC",
    "NER" => "NE",
    "NFK" => "NF",
    "NGA" => "NG",
    "NIC" => "NI",
    "NIU" => "NU",
    "NLD" => "NL",
    "NOR" => "NO",
    "NPL" => "NP",
    "NRU" => "NR",
    "NZL" => "NZ",
    "OMN" => "OM",
    "PAK" => "PK",
    "PAN" => "PA",
    "PCN" => "PN",
    "PER" => "PE",
    "PHL" => "PH",
    "PLW" => "PW",
    "PNG" => "PG",
    "POL" => "PL",
    "PRI" => "PR",
    "PRK" => "KP",
    "PRT" => "PT",
    "PRY" => "PY",
    "PSE" => "PS",
    "PYF" => "PF",
    "QAT" => "QA",
    "REU" => "RE",
    "ROU" => "RO",
    "RUS" => "RU",
    "RWA" => "RW",
    "SAU" => "SA",
    "SDN" => "SD",
    "SEN" => "SN",
    "SGP" => "SG",
    "SGS" => "GS",
    "SHN" => "SH",
    "SJM" => "SJ",
    "SLB" => "SB",
    "SLE" => "SL",
    "SLV" => "SV",
    "SMR" => "SM",
    "SOM" => "SO",
    "SPM" => "PM",
    "SRB" => "RS",
    "SSD" => "SS",
    "STP" => "ST",
    "SUR" => "SR",
    "SVK" => "SK",
    "SVN" => "SI",
    "SWE" => "SE",
    "SWZ" => "SZ",
    "SXM" => "SX",
    "SYC" => "SC",
    "SYR" => "SY",
    "TCA" => "TC",
    "TCD" => "TD",
    "TGO" => "TG",
    "THA" => "TH",
    "TJK" => "TJ",
    "TKL" => "TK",
    "TKM" => "TM",
    "TLS" => "TL",
    "TON" => "TO",
    "TTO" => "TT",
    "TUN" => "TN",
    "TUR" => "TR",
    "TUV" => "TV",
    "TWN" => "TW",
    "TZA" => "TZ",
    "UGA" => "UG",
    "UKR" => "UA",
    "UMI" => "UM",
    "URY" => "UY",
    "USA" => "US",
    "UZB" => "UZ",
    "VAT" => "VA",
    "VCT" => "VC",
    "VEN" => "VE",
    "VGB" => "VG",
    "VIR" => "VI",
    "VNM" => "VN",
    "VUT" => "VU",
    "WLF" => "WF",
    "WSM" => "WS",
    "XKX" => "XK",
    "YEM" => "YE",
    "ZAF" => "ZA",
    "ZMB" => "ZM",
    "ZWE" => "ZW"
  }

  @doc """
  Converts a country code to a flag emoji.

  Accepts alpha-2 (`"US"`), alpha-3 (`"USA"`), subdivision (`"GB-SCT"`),
  and IETF language tag (`"en-US"`) formats. Case insensitive.

  ## Examples

      iex> MusicLibrary.Country.to_emoji("US")
      "🇺🇸"

      iex> MusicLibrary.Country.to_emoji("PL")
      "🇵🇱"

      iex> MusicLibrary.Country.to_emoji("GB")
      "🇬🇧"

      iex> MusicLibrary.Country.to_emoji("us")
      "🇺🇸"

      iex> MusicLibrary.Country.to_emoji("pl")
      "🇵🇱"

      iex> MusicLibrary.Country.to_emoji("GB-SCT")
      "🏴󠁧󠁢󠁳󠁣󠁴󠁿"

      iex> MusicLibrary.Country.to_emoji("GB-WLS")
      "🏴󠁧󠁢󠁷󠁬󠁳󠁿"

      iex> MusicLibrary.Country.to_emoji("GB-ENG")
      "🏴󠁧󠁢󠁥󠁮󠁧󠁿"

      iex> MusicLibrary.Country.to_emoji("GB-CYM") == MusicLibrary.Country.to_emoji("GB-WLS")
      true

      iex> MusicLibrary.Country.to_emoji("USA")
      "🇺🇸"

      iex> MusicLibrary.Country.to_emoji("GBR")
      "🇬🇧"

      iex> MusicLibrary.Country.to_emoji("POL")
      "🇵🇱"

      iex> MusicLibrary.Country.to_emoji("en-US")
      "🇺🇸"

      iex> MusicLibrary.Country.to_emoji("pl-PL")
      "🇵🇱"

  """
  @spec to_emoji(String.t()) :: String.t()
  def to_emoji(code) when is_binary(code) do
    code
    |> normalize()
    |> convert()
  end

  defp normalize(code) do
    code = String.upcase(code)

    cond do
      String.contains?(code, "-") -> normalize_with_separator(code)
      String.length(code) == 3 -> Map.get(@alpha3_to_alpha2, code, code)
      true -> code
    end
  end

  defp normalize_with_separator(code) do
    case String.split(code, "-") do
      [country, subdivision] when byte_size(country) == 2 and byte_size(subdivision) > 2 ->
        subdivision = if subdivision == "CYM", do: "WLS", else: subdivision
        {:subdivision, country <> subdivision}

      parts ->
        List.last(parts)
    end
  end

  defp convert({:subdivision, code}) do
    tags =
      code
      |> String.downcase()
      |> String.to_charlist()
      |> Enum.map_join(fn char -> <<char + @tag_offset::utf8>> end)

    @black_flag <> tags <> @cancel_tag
  end

  defp convert(code) when is_binary(code) do
    code
    |> String.downcase()
    |> String.to_charlist()
    |> Enum.map_join(fn char -> <<char + @regional_indicator_offset::utf8>> end)
  end
end
