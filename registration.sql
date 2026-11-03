-- ============================================================================
-- registration.sql — College Course Registration Database (SQLite)
-- Project 4 · GitHub Portfolio Project Pack
--
-- Schema for a small university registration system:
--   departments, instructors, students, courses, prerequisites, sections,
--   enrollments (+ a trigger that enforces prerequisites on INSERT).
--
-- Run order:  sqlite3 registration.db < registration.sql
-- ============================================================================

PRAGMA foreign_keys = ON;   -- SQLite checks FOREIGN KEYs only when this is on

-- ----------------------------------------------------------------------------
-- 1. departments — one row per department (CSE, EEE, ...)
--    PRIMARY KEY (dept_id): every row is uniquely identified by this column.
--    UNIQUE (code, name): no two departments may share a code or a name.
-- ----------------------------------------------------------------------------
CREATE TABLE departments (
    dept_id   INTEGER PRIMARY KEY,          -- rowid alias: auto-incrementing id
    code      TEXT    NOT NULL UNIQUE,      -- short code, e.g. 'CSE'
    name      TEXT    NOT NULL UNIQUE,      -- full name, e.g. 'Computer Science'
    building  TEXT                          -- physical building
);

-- ----------------------------------------------------------------------------
-- 2. instructors — one row per teacher.
--    FOREIGN KEY (dept_id) -> departments(dept_id): an instructor must belong
--    to an existing department (referential integrity). One department has
--    MANY instructors  =>  one-to-many (1:N) relationship.
-- ----------------------------------------------------------------------------
CREATE TABLE instructors (
    instructor_id INTEGER PRIMARY KEY,
    dept_id       INTEGER NOT NULL REFERENCES departments(dept_id),
    first_name    TEXT    NOT NULL,
    last_name     TEXT    NOT NULL,
    email         TEXT    NOT NULL UNIQUE
);

-- ----------------------------------------------------------------------------
-- 3. students — one row per student.
--    FOREIGN KEY (dept_id) -> departments: a student declares one major dept.
--    CHECK (year_of_study BETWEEN 1 AND 5): only sane values are storable.
-- ----------------------------------------------------------------------------
CREATE TABLE students (
    student_id    INTEGER PRIMARY KEY,      -- university id, e.g. 2026001
    first_name    TEXT    NOT NULL,
    last_name     TEXT    NOT NULL,
    email         TEXT    NOT NULL UNIQUE,
    dept_id       INTEGER NOT NULL REFERENCES departments(dept_id),
    year_of_study INTEGER NOT NULL CHECK (year_of_study BETWEEN 1 AND 4),
    enrolled_date TEXT    NOT NULL          -- ISO date 'YYYY-MM-DD'
);

-- ----------------------------------------------------------------------------
-- 4. courses — the catalogue. Each course belongs to one department and has
--    one coordinating instructor (1:N from both sides).
-- ----------------------------------------------------------------------------
CREATE TABLE courses (
    course_id     INTEGER PRIMARY KEY,
    dept_id       INTEGER NOT NULL REFERENCES departments(dept_id),
    code          TEXT    NOT NULL UNIQUE,  -- e.g. 'CSE-201'
    title         TEXT    NOT NULL,
    credits       INTEGER NOT NULL CHECK (credits BETWEEN 1 AND 6),
    instructor_id INTEGER REFERENCES instructors(instructor_id)  -- coordinator
);

-- ----------------------------------------------------------------------------
-- 5. prerequisites — a course can require several other courses, and one
--    course can be the prerequisite of many courses. That is MANY-TO-MANY,
--    so it gets its own table with a composite PRIMARY KEY (course_id,
--    prereq_course_id). CHECK prevents a course from requiring itself.
-- ----------------------------------------------------------------------------
CREATE TABLE prerequisites (
    course_id        INTEGER NOT NULL REFERENCES courses(course_id),
    prereq_course_id INTEGER NOT NULL REFERENCES courses(course_id),
    PRIMARY KEY (course_id, prereq_course_id),
    CHECK (course_id <> prereq_course_id)
);

-- ----------------------------------------------------------------------------
-- 6. sections — a course is OFFERED as one or more sections in a semester
--    (the same course in Fall 2026 and Spring 2026 = two sections).
--    days/start_time/end_time let us detect overlapping time slots.
--    UNIQUE (course_id, semester, year, days, start_time): a course cannot be
--    offered twice in the same slot.
-- ----------------------------------------------------------------------------
CREATE TABLE sections (
    section_id    INTEGER PRIMARY KEY,
    course_id     INTEGER NOT NULL REFERENCES courses(course_id),
    semester      TEXT    NOT NULL CHECK (semester IN ('Fall','Spring','Summer')),
    year          INTEGER NOT NULL,
    instructor_id INTEGER NOT NULL REFERENCES instructors(instructor_id),
    room          TEXT    NOT NULL,
    days          TEXT    NOT NULL,         -- 'MWF', 'TTh', 'MW', 'T' ...
    start_time    TEXT    NOT NULL,         -- 'HH:MM' 24h
    end_time      TEXT    NOT NULL,
    capacity      INTEGER NOT NULL CHECK (capacity > 0),
    UNIQUE (course_id, semester, year, days, start_time)
);

-- ----------------------------------------------------------------------------
-- 7. enrollments — the JUNCTION TABLE between students and sections.
--    A student takes many sections; a section has many students => M:N,
--    resolved by this table. It also carries the grade (an attribute of the
--    relationship, not of either side).
--    UNIQUE (student_id, section_id): no double registration in one section.
-- ----------------------------------------------------------------------------
CREATE TABLE enrollments (
    enrollment_id INTEGER PRIMARY KEY,
    student_id    INTEGER NOT NULL REFERENCES students(student_id),
    section_id    INTEGER NOT NULL REFERENCES sections(section_id),
    enrolled_date TEXT    NOT NULL,
    grade_letter  TEXT CHECK (grade_letter IN
                  ('A+','A','A-','B+','B','B-','C+','C','C-','D','F','W')),
    grade_points  REAL CHECK (grade_points BETWEEN 0 AND 4)
    -- note: grade_points is NULL for 'W' (withdrawn)
);

-- ----------------------------------------------------------------------------
-- 8. STRETCH GOAL: enforceable rule — a student cannot register for a course
--    unless they have PASSED (grade_points >= 2.0, i.e. C or better) every
--    prerequisite in an EARLIER or the same semester.
--    SQLite enforces this with a TRIGGER: it runs BEFORE each INSERT on
--    enrollments and aborts the insert if a prerequisite is missing.
-- ----------------------------------------------------------------------------
CREATE TRIGGER enforce_prerequisites
BEFORE INSERT ON enrollments
BEGIN
    SELECT RAISE(ABORT, 'prerequisite not satisfied for this student')
    WHERE EXISTS (
        SELECT 1
        FROM prerequisites p
        JOIN sections s  ON s.section_id  = NEW.section_id   -- section being registered
        WHERE p.course_id = s.course_id                       -- its course
          AND NOT EXISTS (                                    -- student must have passed it
              SELECT 1
              FROM enrollments e
              JOIN sections s2 ON s2.section_id = e.section_id
              WHERE e.student_id    = NEW.student_id
                AND s2.course_id    = p.prereq_course_id
                AND e.grade_points >= 2.0
          )
    );
END;
