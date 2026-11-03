#!/usr/bin/env python3
"""make_erd.py — draw the ER diagram (erd.png) for the registration database.

Pure matplotlib: one box per table (PK bold, FK marked, UK unique), lines
labelled 1 / N for the one-to-many relationships. Run:  python make_erd.py
"""
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

TABLES = {
    "departments": dict(x=0.03, y=0.97, w=0.17, color="#4C72B0", cols=[
        ("dept_id", "PK"), ("code", "UK"), ("name", "UK"), ("building", "")]),
    "instructors": dict(x=0.245, y=0.97, w=0.20, color="#55A868", cols=[
        ("instructor_id", "PK"), ("dept_id", "FK→departments"), ("first_name", ""),
        ("last_name", ""), ("email", "UK")]),
    "prerequisites": dict(x=0.55, y=0.97, w=0.24, color="#C44E52", cols=[
        ("course_id", "PK, FK→courses"), ("prereq_course_id", "PK, FK→courses")]),
    "students": dict(x=0.03, y=0.60, w=0.20, color="#4C72B0", cols=[
        ("student_id", "PK"), ("first_name", ""), ("last_name", ""), ("email", "UK"),
        ("dept_id", "FK→departments"), ("year_of_study", ""), ("enrolled_date", "")]),
    "courses": dict(x=0.36, y=0.74, w=0.23, color="#DD8452", cols=[
        ("course_id", "PK"), ("dept_id", "FK→departments"), ("code", "UK"),
        ("title", ""), ("credits", ""), ("instructor_id", "FK→instructors")]),
    "sections": dict(x=0.67, y=0.60, w=0.26, color="#937860", cols=[
        ("section_id", "PK"), ("course_id", "FK→courses"), ("semester", ""), ("year", ""),
        ("instructor_id", "FK→instructors"), ("room", ""), ("days", ""),
        ("start_time", ""), ("end_time", ""), ("capacity", "")]),
    "enrollments": dict(x=0.36, y=0.30, w=0.23, color="#8172B3", cols=[
        ("enrollment_id", "PK"), ("student_id", "FK→students"), ("section_id", "FK→sections"),
        ("enrolled_date", ""), ("grade_letter", ""), ("grade_points", "")]),
}

LINE_H = 0.030
HEADER_H = 0.045


def box_height(t):
    return HEADER_H + LINE_H * len(t["cols"])


def draw_table(ax, name, t):
    h = box_height(t)
    x, y, w = t["x"], t["y"], t["w"]
    ax.add_patch(FancyBboxPatch((x, y - h), w, h, boxstyle="round,pad=0.006",
                                fc="white", ec=t["color"], lw=2, mutation_aspect=0.5))
    ax.add_patch(FancyBboxPatch((x, y - HEADER_H), w, HEADER_H, boxstyle="round,pad=0.006",
                                fc=t["color"], ec=t["color"], lw=2, mutation_aspect=0.5))
    ax.text(x + w / 2, y - HEADER_H / 2, name, ha="center", va="center",
            fontsize=12, fontweight="bold", color="white")
    for i, (col, tag) in enumerate(t["cols"]):
        cy = y - HEADER_H - LINE_H * (i + 0.5)
        weight = "bold" if "PK" in tag else "normal"
        style = "italic" if "FK" in tag else "normal"
        ax.text(x + 0.012, cy, col, ha="left", va="center", fontsize=9.5,
                fontweight=weight, style=style, family="monospace")
        if tag:
            ax.text(x + w - 0.012, cy, tag, ha="right", va="center", fontsize=8,
                    color="#555555", family="monospace")
    return (x, y, w, h)


def edge(ax, p1, p2, label1, label2):
    ax.add_patch(FancyArrowPatch(p1, p2, arrowstyle="-", color="#333333", lw=1.4,
                                 shrinkA=0, shrinkB=0))
    mx, my = (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2
    ax.text(p1[0] + (0.012 if abs(p2[0] - p1[0]) > abs(p2[1] - p1[1]) else 0),
            p1[1] + (0 if abs(p2[0] - p1[0]) > abs(p2[1] - p1[1]) else 0.014),
            label1, fontsize=11, fontweight="bold", color="#333333",
            ha="left" if abs(p2[0] - p1[0]) > abs(p2[1] - p1[1]) else "center")
    ax.text(p2[0] - (0.012 if abs(p2[0] - p1[0]) > abs(p2[1] - p1[1]) else 0),
            p2[1] - (0 if abs(p2[0] - p1[0]) > abs(p2[1] - p1[1]) else 0.014),
            label2, fontsize=11, fontweight="bold", color="#333333",
            ha="right" if abs(p2[0] - p1[0]) > abs(p2[1] - p1[1]) else "center")


def main():
    fig, ax = plt.subplots(figsize=(16, 10))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")

    boxes = {name: draw_table(ax, name, t) for name, t in TABLES.items()}

    def right(b):  return (b[0] + b[2], b[1] - b[3] / 2)
    def left(b):   return (b[0], b[1] - b[3] / 2)
    def top(b):    return (b[0] + b[2] / 2, b[1])
    def bottom(b): return (b[0] + b[2] / 2, b[1] - b[3])

    d, ins, pre, stu, cou, sec, enr = (boxes[k] for k in
        ["departments", "instructors", "prerequisites", "students", "courses", "sections", "enrollments"])

    edge(ax, right(d), left(ins), "1", "N")                                  # dept -> instructors
    edge(ax, (d[0] + 0.04, d[1] - d[3]), (stu[0] + 0.04, stu[1]), "1", "N")   # dept -> students
    edge(ax, (d[0] + d[2] - 0.02, d[1] - d[3] + 0.02), left(cou), "1", "N")    # dept -> courses
    edge(ax, (ins[0] + ins[2] / 2, ins[1] - ins[3]), top(cou), "1", "N")      # instructors -> courses (coordinator)
    edge(ax, (cou[0] + 0.06, cou[1]), (pre[0] + 0.06, pre[1] - pre[3]), "1", "N")      # courses -> prereqs
    edge(ax, (cou[0] + cou[2] - 0.06, cou[1]), (pre[0] + pre[2] - 0.06, pre[1] - pre[3]), "1", "N")
    edge(ax, right(cou), (sec[0], sec[1] - 0.10), "1", "N")                   # courses -> sections
    edge(ax, (ins[0] + ins[2] - 0.03, ins[1] - ins[3]), (sec[0] + sec[2] / 2, sec[1]), "1", "N")  # instructors -> sections
    edge(ax, (stu[0] + stu[2] - 0.04, stu[1] - stu[3]), left(enr), "1", "N")  # students -> enrollments
    edge(ax, bottom(sec), (enr[0] + enr[2] - 0.04, enr[1] - enr[3] / 2), "1", "N")  # sections -> enrollments

    ax.text(0.5, 0.995, "College Course Registration Database — ERD",
            ha="center", va="top", fontsize=17, fontweight="bold")
    ax.text(0.03, 0.035,
            "PK = primary key · FK = foreign key · UK = unique ·  1──N = one-to-many   "
            "(enrollments and prerequisites are junction tables resolving many-to-many)",
            fontsize=10, color="#444444")
    fig.savefig("erd.png", dpi=200, bbox_inches="tight", facecolor="white")
    print("erd.png written")


if __name__ == "__main__":
    main()
