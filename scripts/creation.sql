create sequence teacher_id_seq
    as integer;



create sequence lessons_data_id_seq
    as integer;



create sequence classrooms_data_id_seq
    as integer;



create type lesson_type as enum ('lecture', 'seminar', 'practice');



create type classroom_type as enum ('computer class', 'field', 'gym', 'lecture room', 'normal class');



create type day_of_week as enum ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun');



create table teachers_raw
(
    id integer default nextval('teacher_id_seq'::regclass) not null
        constraint teacher_pk
            primary key,
    name varchar not null,
    surname varchar not null,
    patronymic varchar,
    position varchar not null
);



alter sequence teacher_id_seq owned by teachers_raw.id;

create unique index teacher_id_uindex
    on teachers_raw (id);

create table directions
(
    code integer not null
        constraint courses_pk
            primary key,
    name varchar not null
);



create table disciplines
(
    code integer not null,
    name varchar not null,
    academic_year integer not null,
    direction_code integer not null
        constraint discipline_direction___fk
            references directions
            on delete restrict
);



create unique index academic_subject_code_uindex
    on disciplines (code);

create table divisions
(
    code integer not null
        constraint course_subgroup_pk
            primary key,
    name varchar not null,
    direction_code integer not null
        constraint course_subgroups_courses___fk
            references directions
            on delete restrict,
    students_count integer not null
);



create unique index course_subgroup_code_uindex
    on divisions (code);

create unique index courses_code_uindex
    on directions (code);

create table educational_buildings
(
    id serial
        constraint educational_buildings_pk
            primary key,
    address varchar not null
);



create table classrooms
(
    id integer default nextval('classrooms_data_id_seq'::regclass) not null
        constraint classrooms_data_pk
            primary key,
    number varchar not null,
    student_capacity integer not null,
    name varchar not null,
    classroom_type classroom_type not null,
    address_id integer not null
        constraint classroom_building___fk
            references educational_buildings
            on delete restrict
);



alter sequence classrooms_data_id_seq owned by classrooms.id;

create table lessons_raw
(
    id integer default nextval('lessons_data_id_seq'::regclass) not null
        constraint lessons_data_pk
            primary key,
    lesson_type lesson_type not null,
    start_time time not null,
    end_time time not null,
    student_capacity integer not null,
    day_of_week day_of_week not null,
    teacher_id integer not null
        constraint lesson_teacher___fk
            references teachers_raw
            on delete restrict,
    classroom_id integer not null
        constraint lesson_room___fk
            references classrooms
            on delete restrict,
    discipline_code integer not null
        constraint lesson_discipline___fk
            references disciplines (code)
            on delete restrict,
    division_code integer not null
        constraint lesson_division___fk
            references divisions
            on delete restrict
);



alter sequence lessons_data_id_seq owned by lessons_raw.id;

create unique index lessons_data_id_uindex
    on lessons_raw (id);

create unique index classrooms_data_id_uindex
    on classrooms (id);

create unique index educational_buildings_id_uindex
    on educational_buildings (id);

create view teachers(id, full_name, position) as
SELECT teachers_raw.id,
       ((teachers_raw.name::text || ' '::text) || teachers_raw.surname::text) ||
       COALESCE(' '::text || NULLIF(teachers_raw.patronymic::text, ''::text), ''::text) AS full_name,
       teachers_raw."position"
FROM teachers_raw;



create view lessons(id, lesson_type, day_of_week, start_time, end_time, student_capacity, teacher_id, teacher_full_name, classroom_id, classroom_name, classroom_number, classroom_address, discipline_code, discipline_name, division_code, division_name, next_date) as
SELECT lessons_raw.id,
       lessons_raw.lesson_type,
       lessons_raw.day_of_week,
       lessons_raw.start_time,
       lessons_raw.end_time,
       LEAST(lessons_raw.student_capacity, c.student_capacity)             AS student_capacity,
       lessons_raw.teacher_id,
       t.full_name                                                         AS teacher_full_name,
       lessons_raw.classroom_id,
       c.name                                                              AS classroom_name,
       c.number                                                            AS classroom_number,
       eb.address                                                          AS classroom_address,
       lessons_raw.discipline_code,
       d.name                                                              AS discipline_name,
       lessons_raw.division_code,
       d2.name                                                             AS division_name,
       CURRENT_DATE + (abs(EXTRACT(dow FROM CURRENT_DATE) - 7::numeric) + 1::numeric +
                       lessons_raw.day_of_week::integer::numeric)::integer AS next_date
FROM lessons_raw
         JOIN disciplines d ON lessons_raw.discipline_code = d.code
         JOIN divisions d2 ON lessons_raw.division_code = d2.code
         JOIN teachers t ON lessons_raw.teacher_id = t.id
         JOIN classrooms c ON c.id = lessons_raw.classroom_id
         JOIN educational_buildings eb ON c.address_id = eb.id;



create view lessons_schedule(day_of_week, lesson_type, discipline_name, start_time, end_time, teacher_full_name, classroom_number, classroom_name, classroom_address, division_name) as
SELECT lessons.day_of_week,
       lessons.lesson_type,
       lessons.discipline_name,
       lessons.start_time,
       lessons.end_time,
       lessons.teacher_full_name,
       lessons.classroom_number,
       lessons.classroom_name,
       lessons.classroom_address,
       lessons.division_name
FROM lessons;



create view average_weekly_load(load, name) as
SELECT sum(lessons_raw.end_time - lessons_raw.start_time) AS load,
       d.name
FROM lessons_raw
         JOIN divisions d ON d.code = lessons_raw.division_code
GROUP BY d.name;



create view practice_classroom_types(classroom_type) as
SELECT 'computer class'::classroom_type AS classroom_type
UNION
SELECT 'field'::classroom_type AS classroom_type
UNION
SELECT 'gym'::classroom_type AS classroom_type;



create function get_dow_position(dow day_of_week) returns integer
    stable
	strict
	language sql
as $$
select case
           when dow='mon' then 0
           when dow='tue' then 1
           when dow='wed' then 2
           when dow='thu' then 3
           when dow='fri' then 4
           when dow='sat' then 5
           when dow='sun' then 6
           end
           $$;



create function get_available_practice_classroom(t time without time zone) returns TABLE(name character varying, number character varying, address character varying)
    language sql
    as $$
select c.name, c.number, eb.address
from classrooms c
         join lessons_raw l on c.id = l.classroom_id
         join educational_buildings eb on c.address_id = eb.id
         inner join practice_classroom_types pct on c.classroom_type = pct.classroom_type
where t not between l.start_time and l.end_time;
$$;



create function get_schedule_for_teacher(t_id integer) returns TABLE(day_of_week day_of_week, lesson_type lesson_type, discipline_name character varying, start_time time without time zone, end_time time without time zone, classroom_number character varying, classroom_name character varying, classroom_address character varying, division_name character varying)
    language sql
    as $$
SELECT lessons.day_of_week,
       lessons.lesson_type,
       lessons.discipline_name,
       lessons.start_time,
       lessons.end_time,
       lessons.classroom_number,
       lessons.classroom_name,
       lessons.classroom_address,
       lessons.division_name
FROM lessons
where lessons.teacher_id = t_id;
$$;



create function get_available_classrooms_for_division(d_c integer) returns classrooms
    language sql
    as $$
select c.*
from divisions d
         join classrooms c on d_c = d.code and d.students_count <= c.student_capacity
    $$;



