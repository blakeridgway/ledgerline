# Shared drawing helpers for the Prawn documents in this directory.
#
# Prawn's built-in fonts use WinAnsiEncoding, so anything outside that set
# (emoji, arrows, CJK) is transliterated or replaced before being drawn.
module PdfHelpers
  MARGIN = 48

  INK = "1F2933".freeze
  MUTED = "6B7A88".freeze
  ACCENT = "1D4ED8".freeze
  RULE = "D8DEE4".freeze
  HAIRLINE = "E4E9ED".freeze

  TYPOGRAPHIC_MAP = {
    "\u2018" => "'", "\u2019" => "'",
    "\u201C" => '"', "\u201D" => '"',
    "\u2013" => "-", "\u2014" => "-",
    "\u2026" => "...", "\u00A0" => " "
  }.freeze

  def safe(value)
    TYPOGRAPHIC_MAP.reduce(value.to_s) { |text, (from, to)| text.gsub(from, to) }
      .encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
      .encode("UTF-8")
  end

  def pdf_date(date)
    date&.strftime("%b %-d, %Y").to_s
  end

  # Hours without trailing zeros: 8 -> "8", 7.5 -> "7.5"
  def hours_label(value)
    ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2, strip_insignificant_zeros: true)
  end

  def money(value, currency_symbol)
    ActiveSupport::NumberHelper.number_to_currency(value, unit: currency_symbol)
  end
end
