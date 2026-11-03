-- ============================================================================
-- views.sql — two reusable views (Project 4, step 7)
--
-- A VIEW is a stored query with a name: it hides JOIN complexity, always
-- shows fresh data, and can be queried like a table. Run after
-- registration.sql + seed_data.py:   sqlite3 registration.db < views.sql
-- ============================================================================

-- View 1: every student's transcript for the CURRENT semester (Fall 2026).
-- Registrar use: "print today's class lists with grades-in-progress."
CREATE VIEW current_semester_transcript AS
SELECT st.student_id,
       st.first_name || ' ' || st.last_name AS student,
       d.code                               AS dept,
       c.code                               AS course,
       c.title,
       c.credits,
       e.grade_letter,
       e.grade_points
FROM enrollments e
JOIN students st   ON st.student_id = e.student_id
JOIN departments d ON d.dept_id    = st.dept_id
JOIN sections s    ON s.section_id = e.section_id
JOIN courses c     ON c.course_id  = s.course_id
WHERE s.semester = 'Fall' AND s.year = 2026;

-- View 2: department performance dashboard — students, average CGPA
-- (credit-weighted), pass rate. Registrar use: annual department review.
CREATE VIEW department_performance AS
WITH cgpa AS (
    SELECT e.student_id,
           SUM(e.grade_points * c.credits) / SUM(c.credits) AS cgpa
    FROM enrollments e
    JOIN sections s ON s.section_id = e.section_id
    JOIN courses c  ON c.course_id  = s.course_id
    WHERE e.grade_points IS NOT NULL
    GROUP BY e.student_id
)
SELECT d.code AS dept,
       d.name,
       (SELECT COUNT(*) FROM students st WHERE st.dept_id = d.dept_id)          AS students,
       ROUND((SELECT AVG(g.cgpa) FROM cgpa g
              JOIN students st ON st.student_id = g.student_id
              WHERE st.dept_id = d.dept_id), 2)                                   AS avg_cgpa,
       ROUND(100.0 * (SELECT COUNT(*) FROM enrollments e
                      JOIN sections s ON s.section_id = e.section_id
                      JOIN students st ON st.student_id = e.student_id
                      WHERE st.dept_id = d.dept_id AND e.grade_letter <> 'F')
             / NULLIF((SELECT COUNT(*) FROM enrollments e
                       JOIN sections s ON s.section_id = e.section_id
                       JOIN students st ON st.student_id = e.student_id
                       WHERE st.dept_id = d.dept_id), 0), 1)                      AS pass_rate_pct
FROM departments d;
