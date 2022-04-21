module DateAndTimeExtraction
  def extract_date_and_time(hash, field)
    if (date = hash.delete("#{field}_date")).present?
      time = hash.delete("#{field}_time")
      values = Date._parse("#{date} #{time}", "%d.%m.%Y %H:%M")
      Time.zone.local(*values.values_at(:year, :mon, :mday, :hour, :min).compact)
    end
  end
end
