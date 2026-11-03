-- ============================================================================
-- analysis_queries.sql — 20 registrar questions answered with SQL (SQLite)
-- Project 4 · College Course Registration Database
--
-- Each query is marked:  -- QUERY Qnn | <question> | techniques: ...
-- The 20 queries collectively use: JOIN, GROUP BY, HAVING, subqueries
-- (IN / EXISTS / correlated), CASE, and window functions (LAG, RANK, SUM OVER).
--
-- Run them all with:  python run_analysis.py     (writes query_results.md)
-- Or by hand:         sqlite3 registration.db < analysis_queries.sql
-- ============================================================================

-- QUERY Q01 | How many students does each department have?
-- techniques: JOIN, GROUP BY, aggregate COUNT
SELECT d.code AS department, d.name, COUNT(s.student_id) AS students
FROM departments d
LEFT JOIN students s ON s.dept_id = d.dept_id
GROUP BY d.dept_id
ORDER BY students DESC;

-- QUERY Q02 | What is the average grade (grade points) in each course?
-- techniques: multi-JOIN, GROUP BY, HAVING, AVG, ORDER BY
SELECT c.code, c.title,
       COUNT(e.enrollment_id)                    AS enrollments,
       ROUND(AVG(e.grade_points), 2)             AS avg_grade_points
FROM courses c
JOIN sections s    ON s.course_id  = c.course_id
JOIN enrollments e ON e.section_id = s.section_id
GROUP BY c.course_id
HAVING COUNT(e.enrollment_id) >= 20          -- only courses with enough data
ORDER BY avg_grade_points DESC;

-- QUERY Q03 | Who are the top 10 students by CGPA (grade points weighted by credit hours)?
-- techniques: multi-JOIN, GROUP BY, HAVING, weighted average, LIMIT
SELECT st.student_id,
       st.first_name || ' ' || st.last_name      AS student,
       d.code                                    AS dept,
       ROUND(SUM(e.grade_points * c.credits) / SUM(c.credits), 2) AS cgpa,
       SUM(c.credits)                            AS credits_taken
FROM students st
JOIN enrollments e ON e.student_id = st.student_id
JOIN sections s    ON s.section_id = e.section_id
JOIN courses c     ON c.course_id  = s.course_id
JOIN departments d ON d.dept_id    = st.dept_id
WHERE e.grade_points IS NOT NULL
GROUP BY st.student_id
HAVING SUM(c.credits) >= 12                   -- only students with a real course load
ORDER BY cgpa DESC
LIMIT 10;

-- QUERY Q04 | Which courses have the highest failure rates?
-- techniques: JOIN, GROUP BY, HAVING, CASE (conditional counting)
SELECT c.code, c.title,
       COUNT(*)                                                        AS enrollments,
       SUM(CASE WHEN e.grade_letter = 'F' THEN 1 ELSE 0 END)            AS failures,
       ROUND(100.0 * SUM(CASE WHEN e.grade_letter = 'F' THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                             AS fail_rate_pct
FROM courses c
JOIN sections s    ON s.course_id  = c.course_id
JOIN enrollments e ON e.section_id = s.section_id
GROUP BY c.course_id
HAVING COUNT(*) >= 30
ORDER BY fail_rate_pct DESC
LIMIT 10;

-- QUERY Q05 | How do enrollments grow semester over semester?
-- techniques: GROUP BY + window function LAG
SELECT s.semester || ' ' || s.year                                   AS semester,
       COUNT(*)                                                      AS enrollments,
       COUNT(*) - LAG(COUNT(*), 1, 0) OVER (ORDER BY MIN(s.year * 10 +
           CASE s.semester WHEN 'Spring' THEN 1 WHEN 'Summer' THEN 2 ELSE 3 END))
                                                                    AS change_vs_prev
FROM sections s
JOIN enrollments e ON e.section_id = s.section_id
GROUP BY s.semester, s.year
ORDER BY MIN(s.year * 10 + CASE s.semester WHEN 'Spring' THEN 1 WHEN 'Summer' THEN 2 ELSE 3 END);

-- QUERY Q06 | What is each instructor's teaching load in the current semester (Fall 2026)?
-- techniques: JOIN, GROUP BY, COUNT DISTINCT, SUM
SELECT i.instructor_id,
       i.first_name || ' ' || i.last_name AS instructor,
       d.code                             AS dept,
       COUNT(DISTINCT s.section_id)       AS sections,
       COUNT(e.enrollment_id)             AS students,
       SUM(c.credits)                     AS credit_hours
FROM instructors i
JOIN sections s    ON s.instructor_id = i.instructor_id
                   AND s.semester = 'Fall' AND s.year = 2026
JOIN courses c     ON c.course_id  = s.course_id
LEFT JOIN enrollments e ON e.section_id = s.section_id
JOIN departments d ON d.dept_id    = i.dept_id
GROUP BY i.instructor_id
ORDER BY students DESC;

-- QUERY Q07 | Which students are registered in two sections that overlap in time?
-- techniques: self-JOIN, WHERE with day/time overlap logic
SELECT st.student_id,
       st.first_name || ' ' || st.last_name AS student,
       c1.code AS course_a, s1.days || ' ' || s1.start_time || '-' || s1.end_time AS slot_a,
       c2.code AS course_b, s2.days || ' ' || s2.start_time || '-' || s2.end_time AS slot_b
FROM enrollments e1
JOIN enrollments e2 ON e2.student_id = e1.student_id AND e2.section_id > e1.section_id
JOIN sections s1 ON s1.section_id = e1.section_id
JOIN sections s2 ON s2.section_id = e2.section_id
JOIN students st ON st.student_id = e1.student_id
JOIN courses c1 ON c1.course_id = s1.course_id
JOIN courses c2 ON c2.course_id = s2.course_id
WHERE s1.semester = s2.semester AND s1.year = s2.year          -- same semester
  AND ( (s1.days LIKE '%M%' AND s2.days LIKE '%M%')
     OR (s1.days LIKE '%T%' AND s2.days LIKE '%T%')
     OR (s1.days LIKE '%W%' AND s2.days LIKE '%W%')
     OR (s1.days LIKE '%F%' AND s2.days LIKE '%F%') )           -- share a weekday
  AND s1.start_time < s2.end_time AND s2.start_time < s1.end_time -- and overlap in time
ORDER BY st.student_id;

-- QUERY Q08 | Department performance: students, average CGPA, pass rate.
-- techniques: correlated SUBQUERIES, CTE (WITH), aggregation
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
       (SELECT COUNT(*) FROM students st WHERE st.dept_id = d.dept_id) AS students,
       ROUND((SELECT AVG(g.cgpa) FROM cgpa g
              JOIN students st ON st.student_id = g.student_id
              WHERE st.dept_id = d.dept_id), 2)                       AS avg_cgpa,
       ROUND(100.0 * (SELECT COUNT(*) FROM enrollments e
                      JOIN sections s ON s.section_id = e.section_id
                      JOIN students st ON st.student_id = e.student_id
                      WHERE st.dept_id = d.dept_id AND e.grade_letter <> 'F')
             / NULLIF((SELECT COUNT(*) FROM enrollments e
                       JOIN sections s ON s.section_id = e.section_id
                       JOIN students st ON st.student_id = e.student_id
                       WHERE st.dept_id = d.dept_id), 0), 1)         AS pass_rate_pct
FROM departments d
ORDER BY avg_cgpa DESC;

-- QUERY Q09 | Which are the 10 most popular courses (by enrollments)?
-- techniques: JOIN, GROUP BY, ORDER BY, LIMIT
SELECT c.code, c.title, COUNT(e.enrollment_id) AS enrollments
FROM courses c
JOIN sections s ON s.course_id = c.course_id
LEFT JOIN enrollments e ON e.section_id = s.section_id
GROUP BY c.course_id
ORDER BY enrollments DESC
LIMIT 10;

-- QUERY Q10 | Which students have NO enrollment in the current semester (Fall 2026)?
-- techniques: NOT EXISTS subquery
SELECT st.student_id,
       st.first_name || ' ' || st.last_name AS student,
       d.code AS dept, st.year_of_study
FROM students st
JOIN departments d ON d.dept_id = st.dept_id
WHERE NOT EXISTS (
    SELECT 1 FROM enrollments e
    JOIN sections s ON s.section_id = e.section_id
    WHERE e.student_id = st.student_id AND s.semester = 'Fall' AND s.year = 2026)
ORDER BY st.student_id;

-- QUERY Q11 | What is the overall grade distribution (count and % per letter)?
-- techniques: GROUP BY + window SUM(COUNT(*)) OVER (), CASE in ORDER BY
SELECT grade_letter,
       COUNT(*)                                        AS count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM enrollments
WHERE grade_letter IS NOT NULL
GROUP BY grade_letter
ORDER BY CASE grade_letter WHEN 'A+' THEN 1 WHEN 'A' THEN 2 WHEN 'A-' THEN 3
         WHEN 'B+' THEN 4 WHEN 'B' THEN 5 WHEN 'B-' THEN 6 WHEN 'C+' THEN 7
         WHEN 'C' THEN 8 WHEN 'C-' THEN 9 WHEN 'D' THEN 10 ELSE 11 END;

-- QUERY Q12 | Is the average grade drifting up or down across semesters?
-- techniques: JOIN, GROUP BY, AVG, ORDER BY expression
SELECT s.semester || ' ' || s.year  AS semester,
       COUNT(*)                     AS enrollments,
       ROUND(AVG(e.grade_points), 2) AS avg_grade_points
FROM sections s
JOIN enrollments e ON e.section_id = s.section_id
WHERE e.grade_points IS NOT NULL
GROUP BY s.semester, s.year
ORDER BY MIN(s.year), CASE s.semester WHEN 'Spring' THEN 1 WHEN 'Summer' THEN 2 ELSE 3 END;

-- QUERY Q13 | In each department, how many courses have prerequisites?
-- techniques: LEFT JOIN, GROUP BY, CASE (conditional aggregation)
SELECT d.code AS dept,
       COUNT(c.course_id)                                              AS courses,
       SUM(CASE WHEN p.course_id IS NOT NULL THEN 1 ELSE 0 END)        AS with_prereqs,
       ROUND(100.0 * SUM(CASE WHEN p.course_id IS NOT NULL THEN 1 ELSE 0 END)
             / COUNT(c.course_id), 1)                                   AS pct_with_prereqs
FROM departments d
JOIN courses c ON c.dept_id = d.dept_id
LEFT JOIN (SELECT DISTINCT course_id FROM prerequisites) p ON p.course_id = c.course_id
GROUP BY d.dept_id
ORDER BY pct_with_prereqs DESC;

-- QUERY Q14 | How many students per year of study in each department?
-- techniques: JOIN, GROUP BY two columns
SELECT d.code AS dept, st.year_of_study, COUNT(*) AS students
FROM students st
JOIN departments d ON d.dept_id = st.dept_id
GROUP BY d.code, st.year_of_study
ORDER BY d.code, st.year_of_study;

-- QUERY Q15 | Which sections are the most crowded (fill rate = enrolled / capacity)?
-- techniques: JOIN, GROUP BY, HAVING, computed ratio, LIMIT
SELECT s.section_id, c.code, s.semester || ' ' || s.year AS semester,
       s.room, s.capacity, COUNT(e.enrollment_id) AS enrolled,
       ROUND(100.0 * COUNT(e.enrollment_id) / s.capacity, 1) AS fill_pct
FROM sections s
JOIN courses c ON c.course_id = s.course_id
LEFT JOIN enrollments e ON e.section_id = s.section_id
GROUP BY s.section_id
HAVING COUNT(e.enrollment_id) > 0
ORDER BY fill_pct DESC
LIMIT 10;

-- QUERY Q16 | Which instructors' sections get the highest average grades?
-- techniques: multi-JOIN, GROUP BY, HAVING, AVG, ORDER BY
SELECT i.first_name || ' ' || i.last_name AS instructor,
       d.code AS dept,
       COUNT(e.enrollment_id)      AS graded_enrollments,
       ROUND(AVG(e.grade_points), 2) AS avg_grade
FROM instructors i
JOIN sections s    ON s.instructor_id = i.instructor_id
JOIN enrollments e ON e.section_id = s.section_id
JOIN departments d ON d.dept_id = i.dept_id
WHERE e.grade_points IS NOT NULL
GROUP BY i.instructor_id
HAVING COUNT(e.enrollment_id) >= 30
ORDER BY avg_grade DESC;

-- QUERY Q17 | Which students failed a course and later re-took it with a better grade?
-- techniques: self-JOIN on enrollments (via sections to get the same course), WHERE
SELECT st.student_id,
       st.first_name || ' ' || st.last_name AS student,
       c.code AS course,
       e1.grade_letter AS first_grade,
       e2.grade_letter AS retake_grade
FROM enrollments e1
JOIN enrollments e2 ON e2.student_id = e1.student_id AND e2.enrollment_id > e1.enrollment_id
JOIN sections s1 ON s1.section_id = e1.section_id
JOIN sections s2 ON s2.section_id = e2.section_id
JOIN courses c  ON c.course_id = s1.course_id AND c.course_id = s2.course_id
JOIN students st ON st.student_id = e1.student_id
WHERE e1.grade_letter = 'F' AND e2.grade_points > 0
ORDER BY st.student_id
LIMIT 20;

-- QUERY Q18 | What is the average class size per department per semester?
-- techniques: JOINs, GROUP BY two columns, ratio of aggregates
SELECT d.code AS dept, s.semester || ' ' || s.year AS semester,
       COUNT(DISTINCT s.section_id) AS sections,
       COUNT(e.enrollment_id)      AS enrollments,
       ROUND(1.0 * COUNT(e.enrollment_id) / COUNT(DISTINCT s.section_id), 1) AS avg_class_size
FROM departments d
JOIN courses c ON c.dept_id = d.dept_id
JOIN sections s ON s.course_id = c.course_id
LEFT JOIN enrollments e ON e.section_id = s.section_id
GROUP BY d.dept_id, s.semester, s.year
ORDER BY d.code, MIN(s.year), s.semester;

-- QUERY Q19 | Rank departments by total enrollments.
-- techniques: GROUP BY + window function RANK
SELECT d.code AS dept,
       COUNT(e.enrollment_id)                    AS enrollments,
       RANK() OVER (ORDER BY COUNT(e.enrollment_id) DESC) AS dept_rank
FROM departments d
JOIN courses c ON c.dept_id = d.dept_id
JOIN sections s ON s.course_id = c.course_id
LEFT JOIN enrollments e ON e.section_id = s.section_id
GROUP BY d.dept_id
ORDER BY enrollments DESC;

-- QUERY Q20 | Did average grades change between Fall 2025 and Fall 2026, per department?
-- techniques: conditional aggregation with CASE inside AVG, GROUP BY
SELECT d.code AS dept,
       ROUND(AVG(CASE WHEN s.semester = 'Fall' AND s.year = 2025 THEN e.grade_points END), 2) AS fall_2025_avg,
       ROUND(AVG(CASE WHEN s.semester = 'Fall' AND s.year = 2026 THEN e.grade_points END), 2) AS fall_2026_avg
FROM departments d
JOIN courses c ON c.dept_id = d.dept_id
JOIN sections s ON s.course_id = c.course_id
JOIN enrollments e ON e.section_id = s.section_id
WHERE e.grade_points IS NOT NULL
GROUP BY d.dept_id
ORDER BY d.code;
