# author: Francisco Lucas / Nikola Wissenklaus / Chico

"""
validate_sql.py

Parses every SQL statement that Dataform compiles (tables, views, incrementals,
operations, assertions, pre/post operations) with sqlglot in the BigQuery dialect.

It does NOT replace a dry run in BigQuery (it doesnt know your schemas), but it
catches the stupid stuff before the deploy: missing comma, unbalanced parenthesis,
CTE without name, broken CASE... the 80% of errors that waste a whole CI run.

usage:
    pip install sqlglot
    dataform compile --json > tools/out/compiled.json
    python tools/validate_sql.py tools/out/compiled.json
"""

import json
import logging
import re
import sys

try:
    import sqlglot
except ImportError:
    print("sqlglot not installed: pip install sqlglot")
    sys.exit(2)


class FallbackCatcher(logging.Handler):
    """sqlglot logs a warning and parses as a generic 'Command' when it doesnt
    understand a statement. that means NOTHING was checked, so we count it as a failure."""

    def __init__(self):
        super().__init__(logging.WARNING)
        self.messages = []

    def emit(self, record):
        self.messages.append(record.getMessage())


CATCHER = FallbackCatcher()
logging.getLogger("sqlglot").addHandler(CATCHER)
logging.getLogger("sqlglot").propagate = False

# OPTIONS(...) after the body of CREATE FUNCTION is valid BigQuery but sqlglot doesnt parse it
FUNCTION_OPTIONS = re.compile(r"\)\s*OPTIONS\s*\(\s*description\s*=\s*\"[^\"]*\"\s*\)\s*;?\s*$", re.IGNORECASE)

# sqlglot does not know a few BigQuery ML table functions, we swap them for a
# simple table function call before parsing (only for the syntax check)
ML_FUNCTIONS = re.compile(
    r"ML\.(EVALUATE|GLOBAL_EXPLAIN|DETECT_ANOMALIES|CENTROIDS|FEATURE_IMPORTANCE|EXPLAIN_FORECAST|ARIMA_EVALUATE|"
    r"TRAINING_INFO|CONFUSION_MATRIX|ROC_CURVE|WEIGHTS|ADVANCED_WEIGHTS|EXPLAIN_PREDICT|ARIMA_COEFFICIENTS)\s*\(\s*MODEL\s+(`[^`]+`)",
    re.IGNORECASE,
)


def load_compiled(path):
    raw = open(path, encoding="utf-8").read()
    start = raw.find("{")
    if start < 0:
        raise ValueError("no json found in " + path)
    data, _ = json.JSONDecoder().raw_decode(raw[start:])
    return data


def statements_of(action):
    out = []
    for key in ("query", "incrementalQuery"):
        if action.get(key):
            out.append((key, action[key]))
    for key in ("preOps", "postOps", "incrementalPreOps", "incrementalPostOps", "queries"):
        for i, sql in enumerate(action.get(key) or []):
            out.append((f"{key}[{i}]", sql))
    return out


def mask_literals(sql):
    """same length copy of the sql with strings, backtick names and comments blanked,
    so the keyword searches below never hit something inside them"""
    out = list(sql)
    i, n = 0, len(sql)
    while i < n:
        c = sql[i]
        if sql.startswith("--", i) or c == "#":
            j = sql.find("\n", i)
            j = n if j < 0 else j
            out[i:j] = " " * (j - i)
            i = j
        elif sql.startswith("/*", i):
            j = sql.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out[i:j] = " " * (j - i)
            i = j
        elif c in "'\"`":
            quote = sql[i:i + 3] if sql[i:i + 3] in ("'''", '"""') else c
            j = i + len(quote)
            while j < n:
                if sql[j] == "\\" and c != "`":
                    j += 2
                    continue
                if sql.startswith(quote, j):
                    j += len(quote)
                    break
                j += 1
            out[i + 1:j - 1] = "_" * max(0, j - 1 - (i + 1))
            i = j
        else:
            i += 1
    return "".join(out)


def find_closing(masked, open_pos):
    depth = 0
    for k in range(open_pos, len(masked)):
        if masked[k] == "(":
            depth += 1
        elif masked[k] == ")":
            depth -= 1
            if depth == 0:
                return k
    return -1


def find_at_depth_zero(masked, start, pattern):
    depth = 0
    regex = re.compile(pattern, re.IGNORECASE)
    for k in range(start, len(masked)):
        if masked[k] == "(":
            depth += 1
        elif masked[k] == ")":
            depth -= 1
        elif depth == 0:
            m = regex.match(masked, k)
            # keywords need a word boundary before them, punctuation does not
            if m and (not pattern[0].isalpha() or k == 0 or not (masked[k - 1].isalnum() or masked[k - 1] == "_")):
                return m
    return None


def flatten_script(sql):
    """BigQuery scripting (IF / FOR ... IN / EXECUTE IMMEDIATE) becomes plain statements that
    sqlglot can parse. The queries and conditions inside are still checked, the text of the
    dynamic SQL (the FORMAT string of EXECUTE IMMEDIATE) is not"""
    masked = mask_literals(sql)
    pieces = []

    for m in re.finditer(r"\bFOR\s+(\w+)\s+IN\s*\(", masked, re.IGNORECASE):
        open_pos = m.end() - 1
        close = find_closing(masked, open_pos)
        do = re.match(r"\s*DO\b", masked[close + 1:], re.IGNORECASE) if close > 0 else None
        if do:
            pieces.append((m.start(), close + 1 + do.end(), f"SELECT * FROM ({sql[open_pos + 1:close]}) AS {m.group(1)};"))

    for m in re.finditer(r"\bEND\s+(FOR|IF|WHILE|LOOP)\s*;", masked, re.IGNORECASE):
        pieces.append((m.start(), m.end(), ""))

    for m in re.finditer(r"(?:\A|;)\s*(ELSE)\s", masked, re.IGNORECASE):
        if not re.match(r"ELSE\s+IF\b", masked[m.start(1):], re.IGNORECASE):
            pieces.append((m.start(1), m.end(1), ""))

    # a statement starts after ; or after the DO / THEN / ELSE of a block
    boundary = r"(?:\A|;|\bDO\b|\bTHEN\b|\bELSE\b)\s*"

    for m in re.finditer(boundary + r"(ELSEIF|IF)\s+(?![(])", masked, re.IGNORECASE):
        then = find_at_depth_zero(masked, m.end(), r"THEN\b")
        if then:
            pieces.append((m.start(1), then.end(), f"SELECT {sql[m.end():then.start()]};"))

    for m in re.finditer(boundary + r"(EXECUTE\s+IMMEDIATE)\b", masked, re.IGNORECASE):
        end = find_at_depth_zero(masked, m.end(), r";")
        if not end:
            continue
        using = find_at_depth_zero(masked[:end.start()], m.end(), r"USING\b")
        expr_end = using.start() if using else end.start()
        pieces.append((m.start(1), end.end(), f"SELECT {sql[m.end(1):expr_end]};"))

    if not pieces:
        return sql
    out, last = [], 0
    for start, end, replacement in sorted(pieces):
        if start < last:
            continue
        out.append(sql[last:start])
        out.append(replacement)
        last = end
    out.append(sql[last:])
    return "".join(out)


def prepare(sql):
    sql = flatten_script(sql)
    sql = ML_FUNCTIONS.sub(lambda m: f"ml_{m.group(1).lower()}({m.group(2)}", sql)
    if re.search(r"CREATE\s+(OR\s+REPLACE\s+)?FUNCTION", sql, re.IGNORECASE):
        sql = FUNCTION_OPTIONS.sub(")", sql.rstrip())
        # JS UDF: the body is a JS string, sqlglot only needs to see a string literal there
        sql = re.sub(r'LANGUAGE\s+js\s+AS\s+r"""[\s\S]*?"""', "LANGUAGE js AS 'js body'", sql, flags=re.IGNORECASE)
    return sql


def lint(parsed_statements):
    """small semantic checks that BigQuery fails on but a parser accepts"""
    from sqlglot import exp

    problems = []
    for statement in parsed_statements:
        if statement is None:
            continue
        for select in statement.find_all(exp.Select):
            group = select.args.get("group")
            if not group:
                continue
            for item in group.expressions:
                target = item
                if isinstance(item, exp.Literal) and item.is_int:
                    position = int(item.this)
                    if 1 <= position <= len(select.expressions):
                        target = select.expressions[position - 1]
                        target = target.this if isinstance(target, exp.Alias) else target
                if isinstance(target, (exp.Literal, exp.Null)) or (isinstance(target, exp.Cast) and isinstance(target.this, exp.Null)):
                    problems.append("GROUP BY a literal value (BigQuery: 'Cannot GROUP BY literal values')")
    return problems


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    data = load_compiled(sys.argv[1])
    groups = [("table", data.get("tables", [])), ("operation", data.get("operations", [])), ("assertion", data.get("assertions", []))]

    checked, failed = 0, []
    for kind, actions in groups:
        for action in actions:
            if action.get("disabled"):
                continue
            target = action["target"]
            name = f'{target.get("schema")}.{target.get("name")}'
            for key, sql in statements_of(action):
                if not sql or not sql.strip():
                    continue
                checked += 1
                CATCHER.messages.clear()
                try:
                    parsed = sqlglot.parse(prepare(sql), read="bigquery")
                    if CATCHER.messages:
                        failed.append((kind, name, key, "not really parsed (fallback to Command): " + CATCHER.messages[0][:200]))
                    for problem in lint(parsed):
                        failed.append((kind, name, key, problem))
                except Exception as exc:  # noqa: BLE001 - we want every parser error here
                    msg = str(exc).splitlines()[0][:300]
                    failed.append((kind, name, key, msg))

    for kind, name, key, msg in failed:
        print(f"FAIL [{kind}] {name} ({key}): {msg}")
    print(f"\n{checked} statements checked, {len(failed)} with syntax problems")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
