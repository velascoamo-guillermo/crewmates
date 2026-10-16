#!/usr/bin/env bash
# Runs the shared extract_deps cases against the glab script.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEXT_TICKET_SCRIPT="$HERE/next-ticket.sh" exec "$HERE/../gh/test-next-ticket.sh"
