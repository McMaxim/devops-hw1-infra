#!/usr/bin/env bash
# monitor.sh — проверка systemd-сервиса и подсчёт ошибок в syslog за последний час.
#
#   ./monitor.sh <service>          например: ./monitor.sh docker
#
# Коды выхода: 0 — сервис active, 1 — не active, 2 — неверный аргумент,
#              3 — сервис не найден, 4 — на хосте нет systemd.
set -uo pipefail

SYSLOG_FILE="${SYSLOG_FILE:-/var/log/syslog}"
# \b — чтобы не считать ошибкой, например, `fail_on_autoremove=False` из логов Ansible
ERROR_PATTERN='\b(error|fail(ed|ure)?|critical|fatal|panic)\b'

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <service>" >&2
  exit 2
fi
SERVICE="$1"
# Имя уходит в systemctl/journalctl — пропускаем только безопасные символы
if [[ ! "$SERVICE" =~ ^[A-Za-z0-9@._:-]+$ ]]; then
  echo "ERROR: недопустимое имя сервиса: '$SERVICE'" >&2
  exit 2
fi

check_service() {
  if ! command -v systemctl >/dev/null; then
    echo "WARN: systemctl не найден — на этом хосте нет systemd (например, macOS)" >&2
    return 4
  fi
  # is-active для несуществующего юнита пишет просто "inactive", поэтому сначала LoadState
  if [[ "$(systemctl show -p LoadState --value "$SERVICE")" == "not-found" ]]; then
    echo "✗ сервис $SERVICE не найден"
    return 3
  fi

  local state logs
  state="$(systemctl is-active "$SERVICE")"
  if [[ "$state" == "active" ]]; then
    echo "✓ сервис $SERVICE: active"
    return 0
  fi

  echo "✗ сервис $SERVICE: $state"
  echo "--- последние 10 строк журнала $SERVICE ---"
  logs="$(journalctl -u "$SERVICE" -n 10 --no-pager -q 2>&1)"
  echo "${logs:-(журнал пуст или нет прав — запустите через sudo)}"
  return 1
}

count_syslog_errors() {
  if [[ ! -r "$SYSLOG_FILE" ]]; then
    echo "WARN: $SYSLOG_FILE не найден или нет прав на чтение — ошибки не посчитать" >&2
    return
  fi

  # Время в syslog Ubuntu 22.04 без года: "Oct 14 20:31:05 host prog: msg".
  # awk собирает из него ключ ГГГГММДДччммсс и сравнивает с «час назад» (mktime нет — в Ubuntu mawk).
  # Год текущий; если месяц строки больше текущего — это прошлый год (декабрь, а сейчас январь).
  local since errors
  since="$(date -d '1 hour ago' '+%Y%m%d%H%M%S')"
  errors="$(awk -v since="$since" -v year="$(date +%Y)" -v month="$(date +%m)" '
    BEGIN {
      split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
      for (i = 1; i <= 12; i++) mon[names[i]] = i
    }
    ($1 in mon) {
      y = (mon[$1] > month + 0) ? year - 1 : year
      t = $3; gsub(":", "", t)
      if (sprintf("%d%02d%02d%s", y, mon[$1], $2, t) >= since) print
    }' "$SYSLOG_FILE" | grep -ciE "$ERROR_PATTERN")"

  echo "--- ошибок в $SYSLOG_FILE за последний час: $errors"
}

echo "=== monitor: $SERVICE @ $(hostname) — $(date '+%F %T') ==="
check_service
rc=$?
count_syslog_errors
exit "$rc"
