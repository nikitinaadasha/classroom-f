select division_code, d.name, extract(HOUR from sum(end_time - start_time)) as weekly_hours_load
from lessons_raw
         join divisions d on lessons_raw.division_code = d.code
group by division_code, d.name
