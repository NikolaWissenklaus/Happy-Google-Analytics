# author: Francisco Lucas / Nikola Wissenklaus / Chico

"""
send_alerts.py

Reads the alerts of the pipeline in BigQuery and posts them to Slack, Google Chat,
Microsoft Teams and / or e-mail. Run it after the daily Dataform run (Cloud Run job,
Cloud Scheduler, Airflow, a cron in some VM... whatever you have).

sources (--sources, comma separated):
    anomalies  ga4_anomaly.anom_alert_feed          metric anomalies with root cause
    changes    ga4_watch.watch_tracking_changelog   critical tracking / export changes
    lgpd       ga4_privacy.priv_lgpd_scorecard      LGPD checks in fail
    dq         ga4_data_quality.dq_scorecard_daily  data quality checks in fail (today)

destinations come from env vars, set only the ones you use:
    SLACK_WEBHOOK_URL, GOOGLE_CHAT_WEBHOOK_URL, TEAMS_WEBHOOK_URL
    SMTP_HOST, SMTP_PORT (587), SMTP_USER, SMTP_PASSWORD, ALERT_EMAIL_FROM, ALERT_EMAIL_TO (comma separated)

Every alert sent is written in <prefix>_ops.ops_alerts_sent, so the same alert is never sent
twice (the anomaly feed keeps 3 days, without this you get the same message 3 mornings in a row).

usage:
    pip install google-cloud-bigquery
    python send_alerts.py --project my-project --dry-run
    python send_alerts.py --project my-project --sources anomalies,lgpd --min-severity high
"""

import argparse
import hashlib
import json
import os
import smtplib
import sys
import urllib.request
from email.message import EmailMessage

SEVERITY_ORDER = {"info": 0, "low": 1, "medium": 2, "warning": 2, "warn": 2, "high": 3, "fail": 3, "critical": 4}

QUERIES = {
    "anomalies": """
        SELECT CONCAT('anomaly|', CAST(metric_date AS STRING), '|', metric, '|', breakdown, '|', COALESCE(breakdown_value, '')) AS alert_key,
               severity, message
        FROM `{project}.{prefix}_anomaly.anom_alert_feed`
    """,
    "changes": """
        SELECT CONCAT('change|', CAST(change_date AS STRING), '|', change_type, '|', subject) AS alert_key,
               severity, CONCAT('[', severity, '] ', change_type, ': ', subject, ' (', details, ')') AS message
        FROM `{project}.{prefix}_watch.watch_tracking_changelog`
        WHERE severity = 'critical'
          AND change_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
    """,
    "lgpd": """
        SELECT CONCAT('lgpd|', CAST(check_date AS STRING), '|', check_name) AS alert_key,
               'critical' AS severity,
               CONCAT('[LGPD] ', check_name, ' = ', FORMAT('%.4g', value), ' (fail at ', FORMAT('%.4g', fail_at), '). ', how_to_fix) AS message
        FROM `{project}.{prefix}_privacy.priv_lgpd_scorecard`
        WHERE status = 'fail'
    """,
    "dq": """
        SELECT CONCAT('dq|', CAST(check_date AS STRING), '|', check_group, '|', check_name) AS alert_key,
               IF(weight >= 3, 'high', 'medium') AS severity,
               CONCAT('[data quality] ', check_group, ' / ', check_name, ' = ', FORMAT('%.4g', value), ' (fail at ', FORMAT('%.4g', fail_at), ')') AS message
        FROM `{project}.{prefix}_data_quality.dq_scorecard_daily`
        WHERE status = 'fail'
          AND check_date = CURRENT_DATE()
    """,
}


def parse_args():
    parser = argparse.ArgumentParser(description="post the pipeline alerts")
    parser.add_argument("--project", required=True, help="GCP project of the Dataform datasets")
    parser.add_argument("--prefix", default="ga4", help="schema_prefix of workflow_settings.yaml")
    parser.add_argument("--sources", default="anomalies,changes,lgpd", help="anomalies,changes,lgpd,dq")
    parser.add_argument("--min-severity", default="medium", choices=["info", "medium", "high", "critical"])
    parser.add_argument("--dry-run", action="store_true", help="only print, send nothing, write nothing")
    return parser.parse_args()


def fetch_alerts(client, args):
    alerts = []
    for source in [s.strip() for s in args.sources.split(",") if s.strip()]:
        if source not in QUERIES:
            print(f"unknown source '{source}', skipping")
            continue
        sql = QUERIES[source].format(project=args.project, prefix=args.prefix)
        try:
            rows = list(client.query(sql).result())
        except Exception as exc:  # noqa: BLE001 - one broken source should not kill the others
            print(f"could not read {source}: {str(exc).splitlines()[0]}")
            continue
        for row in rows:
            if SEVERITY_ORDER.get(row["severity"], 0) >= SEVERITY_ORDER[args.min_severity]:
                key = hashlib.sha256(row["alert_key"].encode("utf-8")).hexdigest()
                alerts.append({"key": key, "source": source, "severity": row["severity"], "message": row["message"]})
    return alerts


def already_sent(client, args, alerts):
    table = f"{args.project}.{args.prefix}_ops.ops_alerts_sent"
    client.query(f"""
        CREATE TABLE IF NOT EXISTS `{table}` (alert_key STRING, source STRING, sent_at TIMESTAMP)
        PARTITION BY DATE(sent_at)
        OPTIONS (partition_expiration_days = 90, description = 'Alerts already sent by tools/alerts/send_alerts.py')
    """).result()
    if not alerts:
        return set()
    from google.cloud import bigquery

    job = client.query(
        f"SELECT DISTINCT alert_key FROM `{table}` WHERE alert_key IN UNNEST(@keys)",
        job_config=bigquery.QueryJobConfig(query_parameters=[bigquery.ArrayQueryParameter("keys", "STRING", [a["key"] for a in alerts])]),
    )
    return {row["alert_key"] for row in job.result()}


def remember(client, args, alerts):
    if not alerts:
        return
    table = f"{args.project}.{args.prefix}_ops.ops_alerts_sent"
    from google.cloud import bigquery

    client.query(
        f"INSERT INTO `{table}` (alert_key, source, sent_at) "
        "SELECT k, @sources[OFFSET(i)], CURRENT_TIMESTAMP() FROM UNNEST(@keys) AS k WITH OFFSET AS i",
        job_config=bigquery.QueryJobConfig(query_parameters=[
            bigquery.ArrayQueryParameter("keys", "STRING", [a["key"] for a in alerts]),
            bigquery.ArrayQueryParameter("sources", "STRING", [a["source"] for a in alerts]),
        ]),
    ).result()


def post_json(url, payload):
    request = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.status


def send(alerts):
    text = "\n".join(f"- {a['message']}" for a in alerts)
    title = f"happy_google_analytics: {len(alerts)} alert(s)"
    sent_somewhere = False

    if os.getenv("SLACK_WEBHOOK_URL"):
        post_json(os.environ["SLACK_WEBHOOK_URL"], {"text": f"*{title}*\n{text}"})
        sent_somewhere = True
    if os.getenv("GOOGLE_CHAT_WEBHOOK_URL"):
        post_json(os.environ["GOOGLE_CHAT_WEBHOOK_URL"], {"text": f"*{title}*\n{text}"})
        sent_somewhere = True
    if os.getenv("TEAMS_WEBHOOK_URL"):
        post_json(os.environ["TEAMS_WEBHOOK_URL"], {"text": f"**{title}**\n\n{text}"})
        sent_somewhere = True
    if os.getenv("SMTP_HOST") and os.getenv("ALERT_EMAIL_TO"):
        message = EmailMessage()
        message["Subject"] = title
        message["From"] = os.getenv("ALERT_EMAIL_FROM", os.getenv("SMTP_USER", "alerts@localhost"))
        message["To"] = os.environ["ALERT_EMAIL_TO"]
        message.set_content(text)
        with smtplib.SMTP(os.environ["SMTP_HOST"], int(os.getenv("SMTP_PORT", "587"))) as smtp:
            smtp.starttls()
            if os.getenv("SMTP_USER"):
                smtp.login(os.environ["SMTP_USER"], os.getenv("SMTP_PASSWORD", ""))
            smtp.send_message(message)
        sent_somewhere = True
    return sent_somewhere


def main():
    args = parse_args()
    try:
        from google.cloud import bigquery
    except ImportError:
        print("google-cloud-bigquery not installed: pip install google-cloud-bigquery")
        sys.exit(2)

    client = bigquery.Client(project=args.project)
    alerts = fetch_alerts(client, args)
    alerts.sort(key=lambda a: -SEVERITY_ORDER.get(a["severity"], 0))

    if args.dry_run:
        for a in alerts:
            print(f"[{a['source']}] {a['message']}")
        print(f"\n{len(alerts)} alert(s), dry run: nothing sent")
        return

    sent_before = already_sent(client, args, alerts)
    new_alerts = [a for a in alerts if a["key"] not in sent_before]
    if not new_alerts:
        print("nothing new to send")
        return
    if not send(new_alerts):
        print("no destination configured (see the env vars at the top of this file)")
        sys.exit(1)
    remember(client, args, new_alerts)
    print(f"{len(new_alerts)} alert(s) sent")


if __name__ == "__main__":
    main()
