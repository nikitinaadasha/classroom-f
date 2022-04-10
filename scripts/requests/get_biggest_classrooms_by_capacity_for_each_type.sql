select distinct on (c.student_capacity)
    c.id, c.name, eb.address, c.student_capacity
from classrooms c
join educational_buildings eb on eb.id = c.address_id
order by c.student_capacity desc, c.id