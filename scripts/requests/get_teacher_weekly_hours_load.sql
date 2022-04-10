select teacher_id, tr.full_name, extract(HOUR from sum(end_time - start_time)) as weekly_hours_load
from lessons_raw
join teachers tr on lessons_raw.teacher_id = tr.id
group by teacher_id, tr.full_name