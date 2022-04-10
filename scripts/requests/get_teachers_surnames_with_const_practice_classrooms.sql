with counts as (
    select
        t.id teacher_id, count(distinct(c.id)) count
    from teachers_raw t
             inner join lessons l on t.id = l.teacher_id
             inner join classrooms c on c.id = l.classroom_id
    where l.lesson_type = 'practice'::lesson_type
    group by t.id
)
select t.surname
from teachers_raw t
join counts on counts.teacher_id = t.id and counts.count = 1