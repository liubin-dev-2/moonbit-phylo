"""Validate the existing default plan CLI's independently known example."""
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    document = json.load(stream)
assert document["schema"] == "phylo/faith-pd-greedy-plan/v1"
assert document["expected_added_taxa"] == ["D", "B"]
# A is baseline. D covers its 5+6 path; B then adds 8. Root stem is excluded.
assert document["expected_step_gains"] == [11, 8]
assert document["expected_gain"] == 19
print("Default plan consumer: D=11, then B=8; total=19")
