with input as (
    select '10:00'::time, 'fri'::day_of_week as dow
)
select c.id, c.name, eb.address
from classrooms c
        join input on true
        join lessons_raw l on c.id = l.classroom_id
        join educational_buildings eb on c.address_id = eb.id
where l.day_of_week != input.dow or
      input.time not between l.start_time and l.end_time and
      c.classroom_type = 'lecture room'::classroom_type;
