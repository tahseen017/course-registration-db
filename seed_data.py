#!/usr/bin/env python3
"""
seed_data.py — generate realistic synthetic data for the course-registration
database (Project 4). No external dataset needed.

Creates registration.db from registration.sql and fills it with:
  10 departments, 30 instructors, 40 courses (+ prerequisites),
  3 semesters of sections, 500 students, ~5,000 graded enrollments.

Deterministic: random.seed(42) / Faker.seed(42) -> same data on every run.

Usage:  python seed_data.py        (run from this folder)
"""
import os
import random
import sqlite3
from datetime import date, timedelta

from faker import Faker

random.seed(42)
fake = Faker()
Faker.seed(42)

HERE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(HERE, "registration.db")
SCHEMA = os.path.join(HERE, "registration.sql")

# ----------------------------------------------------------------------------
# reference data
# ----------------------------------------------------------------------------
DEPARTMENTS = [  # (code, name, building)
    ("CSE", "Computer Science & Engineering", "Engineering Block A"),
    ("EEE", "Electrical & Electronic Engineering", "Engineering Block B"),
    ("BBA", "Business Administration", "Business School"),
    ("ENG", "English & Literature", "Arts Block"),
    ("MAT", "Mathematics", "Science Block"),
    ("PHY", "Physics", "Science Block"),
    ("CHE", "Chemistry", "Science Block"),
    ("ECO", "Economics", "Social Science Block"),
    ("PHA", "Pharmacy", "Medical Block"),
    ("ARC", "Architecture", "Design Block"),
]

# 4 courses per department: (level, title, credits)
COURSE_PLAN = {
    "CSE": [("101", "Programming Fundamentals", 4), ("201", "Data Structures", 3),
            ("301", "Algorithms", 3), ("401", "Database Systems", 4)],
    "EEE": [("101", "Circuit Analysis", 4), ("201", "Digital Electronics", 3),
            ("301", "Signals & Systems", 3), ("401", "Power Systems", 4)],
    "BBA": [("101", "Principles of Management", 3), ("201", "Financial Accounting", 3),
            ("301", "Marketing", 3), ("401", "Strategic Management", 3)],
    "ENG": [("101", "Academic Writing", 3), ("201", "World Literature", 3),
            ("301", "Linguistics Basics", 3), ("401", "Modern Poetry", 3)],
    "MAT": [("101", "Calculus I", 4), ("201", "Linear Algebra", 3),
            ("301", "Probability & Statistics", 3), ("401", "Real Analysis", 4)],
    "PHY": [("101", "Mechanics", 4), ("201", "Electromagnetism", 4),
            ("301", "Quantum Mechanics I", 3), ("401", "Thermodynamics", 3)],
    "CHE": [("101", "General Chemistry", 4), ("201", "Organic Chemistry", 4),
            ("301", "Physical Chemistry", 3), ("401", "Industrial Chemistry", 3)],
    "ECO": [("101", "Microeconomics", 3), ("201", "Macroeconomics", 3),
            ("301", "Econometrics", 3), ("401", "Development Economics", 3)],
    "PHA": [("101", "Human Anatomy", 4), ("201", "Pharmacology I", 4),
            ("301", "Pharmaceutics", 3), ("401", "Clinical Pharmacy", 4)],
    "ARC": [("101", "Design Studio I", 4), ("201", "History of Architecture", 3),
            ("301", "Structural Systems", 3), ("401", "Urban Design Studio", 4)],
}

SEMESTERS = [("Fall", 2025), ("Spring", 2026), ("Fall", 2026)]  # last one = current
CURRENT_SEMESTER = SEMESTERS[-1]
SEMESTER_START = {("Fall", 2025): date(2025, 8, 25),
                  ("Spring", 2026): date(2026, 1, 12),
                  ("Fall", 2026): date(2026, 8, 24)}

DAYS = ["MWF", "TTh", "MW", "T"]
START_TIMES = ["08:00", "09:30", "11:00", "13:00", "14:30", "16:00"]
DURATIONS = {"MWF": 50, "TTh": 75, "MW": 90, "T": 170}  # minutes per meeting

# grade letters -> (points, weight %)   (weighted random; F = fail)
GRADES = [("A+", 4.0, 4), ("A", 4.0, 9), ("A-", 3.7, 9), ("B+", 3.3, 14),
          ("B", 3.0, 19), ("B-", 2.7, 12), ("C+", 2.3, 10), ("C", 2.0, 9),
          ("C-", 1.7, 6), ("D", 1.0, 3), ("F", 0.0, 5)]
LETTERS = [g[0] for g in GRADES]
POINTS = [g[1] for g in GRADES]
WEIGHTS = [g[2] for g in GRADES]

N_STUDENTS = 500


def hhmm_add(hhmm, minutes):
    h, m = map(int, hhmm.split(":"))
    total = h * 60 + m + minutes
    return f"{total // 60:02d}:{total % 60:02d}"


def times_overlap(d1, s1, e1, d2, s2, e2):
    """Do two meetings on possibly-shared weekdays overlap in time?"""
    if not (set(d1) & set(d2)):
        return False
    return s1 < e2 and s2 < e1


def main():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA foreign_keys = ON")
    with open(SCHEMA, encoding="utf-8") as f:
        con.executescript(f.read())
    cur = con.cursor()

    # ---- departments & instructors ------------------------------------------
    dept_ids = {}
    for code, name, building in DEPARTMENTS:
        cur.execute("INSERT INTO departments(code, name, building) VALUES (?,?,?)",
                    (code, name, building))
        dept_ids[code] = cur.lastrowid

    instructor_ids = {}          # dept_code -> [ids]
    for code, _, _ in DEPARTMENTS:
        instructor_ids[code] = []
        for _ in range(3):
            first, last = fake.first_name(), fake.last_name()
            email = f"{first}.{last}{random.randint(1,999)}@univ.edu".lower()
            cur.execute(
                "INSERT INTO instructors(dept_id, first_name, last_name, email) VALUES (?,?,?,?)",
                (dept_ids[code], first, last, email))
            instructor_ids[code].append(cur.lastrowid)

    # ---- courses & prerequisites ---------------------------------------------
    # course_id -> (dept_code, code, title, credits, level)
    courses = {}
    for code, _, _ in DEPARTMENTS:
        plan = COURSE_PLAN[code]
        for i, (num, title, credits) in enumerate(plan):
            full_code = f"{code}-{num}"
            cur.execute(
                "INSERT INTO courses(dept_id, code, title, credits, instructor_id) VALUES (?,?,?,?,?)",
                (dept_ids[code], full_code, title, credits,
                 random.choice(instructor_ids[code])))
            cid = cur.lastrowid
            courses[cid] = (code, full_code, title, credits, int(num))
            # level chains: 2xx needs 1xx, 3xx needs 2xx, 4xx needs 3xx (same dept)
            if int(num) >= 200:
                prereq_num = str(int(num) - 100)
                prereq_code = f"{code}-{prereq_num}"
                cur.execute("SELECT course_id FROM courses WHERE code=?", (prereq_code,))
                row = cur.fetchone()
                if row:
                    cur.execute("INSERT INTO prerequisites(course_id, prereq_course_id) VALUES (?,?)",
                                (cid, row[0]))
    # one cross-department prerequisite for flavour: CSE-301 also needs MAT-201
    cur.execute("SELECT course_id FROM courses WHERE code='CSE-301'")
    cse301 = cur.fetchone()[0]
    cur.execute("SELECT course_id FROM courses WHERE code='MAT-201'")
    mat201 = cur.fetchone()[0]
    cur.execute("INSERT OR IGNORE INTO prerequisites(course_id, prereq_course_id) VALUES (?,?)",
                (cse301, mat201))

    course_list = list(courses.items())  # (cid, info)

    # ---- sections --------------------------------------------------------------
    section_id = 0
    sections = []  # (section_id, course_id, semester, year, instructor_id, days, start, end, capacity)
    for cid, (dcode, code, title, credits, level) in course_list:
        for sem, yr in SEMESTERS:
            # core 1xx courses run every semester (2 sections); others 1 section, 85%
            n_sections = 2 if (level < 300 or random.random() < 0.3) else 1
            used_slots = set()
            for _ in range(n_sections):
                for _try in range(20):
                    days = random.choice(DAYS)
                    start = random.choice(START_TIMES)
                    if (days, start) in used_slots:
                        continue
                    used_slots.add((days, start))
                    end = hhmm_add(start, DURATIONS[days])
                    capacity = random.choice([40, 50, 60, 70])
                    room = f"{dcode}-{random.randint(101, 405)}"
                    section_id += 1
                    cur.execute(
                        """INSERT INTO sections(course_id, semester, year, instructor_id,
                                                  room, days, start_time, end_time, capacity)
                           VALUES (?,?,?,?,?,?,?,?,?)""",
                        (cid, sem, yr, random.choice(instructor_ids[dcode]),
                         room, days, start, end, capacity))
                    sections.append((section_id, cid, sem, yr, days, start, end, capacity))
                    break

    # sections grouped for quick lookup
    by_course_sem = {}
    for s in sections:
        by_course_sem.setdefault((s[1], s[2], s[3]), []).append(s)

    # ---- students ---------------------------------------------------------------
    students = []
    for i in range(N_STUDENTS):
        sid = 2026000 + i + 1
        first, last = fake.first_name(), fake.last_name()
        email = f"{first}.{last}{i}@student.univ.edu".lower()
        dept_code = random.choices([d[0] for d in DEPARTMENTS],
                                   weights=[22, 14, 16, 8, 10, 8, 7, 6, 5, 4])[0]
        enroll_year = random.choice([2023, 2024, 2025, 2026])
        year_of_study = min(4, 2026 - enroll_year + 1)
        enrolled_date = f"{enroll_year}-09-01"
        cur.execute(
            """INSERT INTO students(student_id, first_name, last_name, email,
                                     dept_id, year_of_study, enrolled_date)
               VALUES (?,?,?,?,?,?,?)""",
            (sid, first, last, email, dept_ids[dept_code], year_of_study, enrolled_date))
        students.append((sid, dept_code))

    # ---- enrollments (semester by semester so prerequisites can be checked) ----
    # passed_courses[student_id] = {course_id: best grade_points}
    passed = {sid: {} for sid, _ in students}
    failed_courses = {sid: set() for sid, _ in students}
    enrolled_count = {}
    taken = {sid: {} for sid, _ in students}        # sid -> {(sem,yr): [(days,start,end)]}
    enrolled_keys = {sid: set() for sid, _ in students}  # sid -> {(course_id, sem, yr)}

    def prereqs_ok(sid, cid):
        """all prerequisites of course cid passed by student sid?"""
        cur.execute("SELECT prereq_course_id FROM prerequisites WHERE course_id=?", (cid,))
        for (pcid,) in cur.fetchall():
            if passed[sid].get(pcid, 0) < 2.0:
                return False
        return True

    def assign_grade(sid, cid):
        letter = random.choices(LETTERS, weights=WEIGHTS)[0]
        pts = dict(zip(LETTERS, POINTS))[letter]
        if pts < 2.0:
            failed_courses[sid].add(cid)
        else:
            passed[sid][cid] = max(passed[sid].get(cid, 0), pts)
        return letter, pts

    n_enroll = 0
    for sem, yr in SEMESTERS:
        sem_start = SEMESTER_START[(sem, yr)]
        for sid, dept_code in students:
            # 3-4 courses per semester (~5,000 enrollments in total)
            k = 4 if random.random() < 0.55 else 3
            # candidate courses offered this semester
            candidates = []
            for cid, (dcode, code, title, credits, level) in course_list:
                if (cid, sem, yr) in by_course_sem:
                    candidates.append((cid, dcode == dept_code))
            # own-department courses first, then one elective from another dept
            own = [c for c, is_own in candidates if is_own and prereqs_ok(sid, c)]
            electives = [c for c, is_own in candidates if not is_own and prereqs_ok(sid, c)]
            retakes = [c for c in failed_courses[sid]
                       if (c, sem, yr) in by_course_sem and prereqs_ok(sid, c)]
            random.shuffle(own); random.shuffle(electives)
            chosen = (own[:k] + retakes[:1] + electives[:1])[:k]
            if not chosen:
                continue
            my_sections = taken[sid].setdefault((sem, yr), [])  # avoid time clashes
            for cid in chosen:
                secs = by_course_sem[(cid, sem, yr)]
                random.shuffle(secs)
                placed = False
                for s in secs:
                    s_id, _, _, _, days, start, end, cap = s
                    if enrolled_count.get(s_id, 0) >= cap:
                        continue
                    clash = any(times_overlap(days, start, end, d2, s2, e2)
                                for d2, s2, e2 in my_sections)
                    # 1% of the time we allow a clash (admin override) -> Q7 finds these
                    if clash and random.random() > 0.02:
                        continue
                    letter, pts = assign_grade(sid, cid)
                    cur.execute(
                        """INSERT INTO enrollments(student_id, section_id, enrolled_date,
                                                    grade_letter, grade_points)
                           VALUES (?,?,?,?,?)""",
                        (sid, s_id, sem_start.isoformat(), letter, pts))
                    enrolled_count[s_id] = enrolled_count.get(s_id, 0) + 1
                    my_sections.append((days, start, end))
                    enrolled_keys[sid].add((cid, sem, yr))
                    n_enroll += 1
                    placed = True
                    break
                if not placed:
                    continue

    # ---- top-up: add enrollments until we reach ~5,000 (rules still enforced) ----
    target = 5000
    guard = 0
    while n_enroll < target and guard < 60000:
        guard += 1
        sid, dept_code = random.choice(students)
        sem, yr = random.choice(SEMESTERS)
        cand = [cid for cid, info in course_list
                if (cid, sem, yr) in by_course_sem
                and (cid, sem, yr) not in enrolled_keys[sid]
                and prereqs_ok(sid, cid)]
        if not cand:
            continue
        cid = random.choice(cand)
        secs = list(by_course_sem[(cid, sem, yr)])
        random.shuffle(secs)
        for s in secs:
            s_id, _, _, _, days, start, end, cap = s
            if enrolled_count.get(s_id, 0) >= cap:
                continue
            clash = any(times_overlap(days, start, end, d2, s2, e2)
                        for d2, s2, e2 in taken[sid].get((sem, yr), []))
            if clash and random.random() > 0.02:
                continue
            letter, pts = assign_grade(sid, cid)
            cur.execute(
                """INSERT INTO enrollments(student_id, section_id, enrolled_date,
                                            grade_letter, grade_points)
                   VALUES (?,?,?,?,?)""",
                (sid, s_id, SEMESTER_START[(sem, yr)].isoformat(), letter, pts))
            enrolled_count[s_id] = enrolled_count.get(s_id, 0) + 1
            taken[sid].setdefault((sem, yr), []).append((days, start, end))
            enrolled_keys[sid].add((cid, sem, yr))
            n_enroll += 1
            break

    con.commit()

    # ---- summary ----------------------------------------------------------------
    def count(table):
        return cur.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

    print("Seed complete ->", DB_PATH)
    print(f"  departments : {count('departments')}")
    print(f"  instructors : {count('instructors')}")
    print(f"  students    : {count('students')}")
    print(f"  courses     : {count('courses')}")
    print(f"  prerequisites: {count('prerequisites')}")
    print(f"  sections    : {count('sections')}")
    print(f"  enrollments : {count('enrollments')} (target ~5,000)")
    print(f"  current semester: {CURRENT_SEMESTER[0]} {CURRENT_SEMESTER[1]}")
    con.close()


if __name__ == "__main__":
    main()
