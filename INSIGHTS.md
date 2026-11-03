# 📋 Insight memo — what the registrar should know

Five findings from `analysis_queries.sql` run against `registration.db`
(500 students · 40 courses · 195 sections · 5,000 enrollments · 3 semesters).
Full outputs: `query_results.md`.

1. **Enrollment is growing fast** — 1,404 → 1,645 → 1,951 per semester
   (Fall 2025 → Spring 2026 → Fall 2026, +17% then +19%) — *Q05*.
   → Plan capacity now or sections will overflow.

2. **CSE-101 is the bottleneck** — every one of its sections is at **100% fill**
   (e.g. sections 1–6, all full) — *Q15*. It is also the most popular course — *Q09*.
   → Add a third section / raise capacity, or move students to CSE-201.

3. **Failure risk is concentrated** — ARC-301 Structural Systems fails **8.8%**,
   ECO-201 Macroeconomics **8.5%**, CHE-201 Organic Chemistry **5.9%** of takers
   (overall failure rate ≈ 5%) — *Q04*.
   → Target tutoring/advising at these three courses first.

4. **13 students are double-booked into time-overlapping sections** (26 conflicting
   pairs, e.g. CSE-201 T 13:00–15:50 vs ECO-101 T 11:00–13:50) — *Q07*.
   → The registration UI needs a time-conflict check; these were admin overrides.

5. **Grades drifted between Fall 2025 and Fall 2026** — MAT fell 2.97 → 2.72 and
   ENG 2.85 → 2.65, while EEE rose 2.64 → 2.81 and PHA 2.56 → 2.80 — *Q20*;
   department average CGPAs cluster at 2.71–2.82 with ~95% pass rate
   (view `department_performance`).
   → Investigate MAT/ENG grading consistency; EEE/PHA practices are worth copying.

**Bonus guarantees:** the `enforce_prerequisites` trigger blocks any registration
whose prerequisite wasn't passed (demo in `query_results.md`), and the top student
by credit-weighted CGPA is **Amy Levine (CSE), 3.62** — *Q03*.
