# encoding: utf-8

# Utility methods for parsing dates, Madrid.rb style...

SPANISH_MONTHS = [  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
                    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
SPANISH_MONTHS_R = SPANISH_MONTHS.join('|')

SPANISH_WDAYS = [   'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo']

SPANISH_WDAYS_R = SPANISH_WDAYS.join('|')

ENGLISH_MONTHS = [  'january', 'february', 'march', 'april', 'may', 'june', 'july',
                    'august', 'september', 'october', 'november', 'december']
ENGLISH_MONTHS_R = ENGLISH_MONTHS.join('|')

ENGLISH_WDAYS = [   'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']

ENGLISH_WDAYS_R = ENGLISH_WDAYS.join('|')

class Date
  
  def self.parse_madrid_rb_date(text)
    date = nil
    datereg = text.match(/fecha\: (#{SPANISH_WDAYS_R})\, (\d+) de (#{SPANISH_MONTHS_R}) de (\d\d\d\d)/i)
    if datereg
      month = SPANISH_MONTHS.index($3.downcase)
      if month
        date = self.new($4.to_i, month + 1, $2.to_i)
      end
    else
      datereg = text.match(/date\: (#{ENGLISH_WDAYS_R})\, (#{ENGLISH_MONTHS_R}) (\d+).*(\d\d\d\d)/i)
      if datereg
        month = ENGLISH_MONTHS.index($2.downcase)
        if month
          date = self.new($4.to_i, month + 1, $3.to_i)
        end
      end
    end
    return date
  end
  
end
