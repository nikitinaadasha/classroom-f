select classroom_type, count(*)
from classrooms
group by classroom_type
